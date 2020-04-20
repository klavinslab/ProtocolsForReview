# needs "Standard Libs/SortHelper"
needs "Standard Libs/UploadHelper"
needs "Standard Libs/Units"
needs "Standard Libs/CommonInputOutputNames"
needs "Standard Libs/Feedback"
needs "Standard Libs/Debug"
needs "Standard Libs/OperationErrors"
# needs "Standard Libs/HiddenInputHelper"

needs "PCR Libs/PCRComposition"
needs "PCR Libs/PCRProgram"
needs "PCR Libs/MasterMixHelper"

needs "Preparative qPCR/FragmentLibrary"
# needs "Preparative qPCR/PreparativeqPCRDebug"

module IlluminaAdapters

    INDEX_LENGTH = 6 # bp, length of illumina index

    # Gets illumina barcode from a primer sample
    #
    # @param primer [Sample] the primer
    # @return [String] the barcode
    def get_barcode(primer)
        # TODO: Refactor to deal with primers that don't have an overhang sequence
        barcode = ""
        ohang = primer.properties.fetch("Overhang Sequence")
        if ohang
            if ohang.length >= INDEX_LENGTH
                tmp = ohang[(ohang.length-INDEX_LENGTH)..(ohang.length-1)].downcase.reverse!
                barcode = tmp.gsub('a','T').gsub('t','A').gsub('c','G').gsub('g','C')
            end
        end
        barcode
    end

    # Adds barcodes to a matrix associated with the output collection
    #
    # @param ops [OperationList]
    # @param input_name [String]
    # @param output_name [String]
    def associate_barcodes(ops:, input_name:, output_name:)
        ops.each do |op|
            # to avoid errors with Primer Mix items
            if op.input(input_name).sample_type.name == "Primer"
                barcode = get_barcode(op.input(input_name).sample)
                if barcode
                    part = op.output(output_name).part
                    part.associate(:barcode, barcode)
                end
            end
        end
    end

end

# Handles bin numbers for multi-bin sorting
#
module MultiBinSorting

    # Adds bin numbers to a matrix associated with the output collection
    #
    # @param ops [OperationList]
    # @param input_name [String]
    # @param output_name [String]
    def associate_bins(ops:, input_name:, output_name:)
        ops.each do |op|
            bin = get_bin(op: op, input_name: input_name)
            if bin
                part = op.output(output_name).part
                part.associate(:bin, bin)
            end
        end
    end

    # Provides a String for display of the bin number in tables
    #
    # @param ops [OperationList]
    # @param input_name [String]
    def bin_display(op:, input_name:)
        bd = get_bin(op: op, input_name: input_name) || "N/A"
        bd.to_s
    end

    # Accessor method for the bin number associated with the input
    #
    # @param ops [OperationList]
    # @param input_name [String]
    def get_bin(op:, input_name:)
        op.input(input_name).item.get(:bin)
    end
end

# Contains constants and functions related to preparative qPCR
# Largely follows Baker Lab protocols.
#
# There are four main types of amplification:
# 1) lib_qPCR1 - for ssDNA -> dsDNA, verifying that amplification works,
#      verifying that length is as designed, and (optionally) extracting a
#      specific sublibrary from the other variants in the oligo pool.
# 2) lib_qPCR2 - for amplifying the chosen sublibrary with the correct length for
#      the subsequent transformation step, which typically requires a
#      large quantity of dsDNA.
# 3) qPCR1 - for initial amplification of plasmid or genomic DNA, prior to
#      NGS amplicon sequencing.
# 4) qPCR2 - for further amplification after qPCR1 and adding adaptors and
#      indices for NGS
#
# Each qPCR step has a TEST run to get the correct qPCR stopping cycle (before
#   amplification becomes non-exponential), and and a REAL run for generating
#   the amplicon of interest.
#
# @author Sarah Goldberg
# @author Devin Strickland <strcklnd@uw.edu>
module PreparativeqPCRHelper

    require 'matrix'

    # include SortHelper
    include UploadHelper, Units
    #include HiddenInputHelper
    include CommonInputOutputNames
    include Feedback, Debug, OperationErrors
    # include PreparativeqPCRDebug
    include MasterMixHelper
    include MultiBinSorting, IlluminaAdapters

    MAKE_EXTRA = 1.2
    DEFAULT_STAMP_COLUMNS = 8
    SOFTWARE = "Biorad CFX Manager"
    BASE_DIR = "Libraries/Documents/Public Documents/Bio-Rad/CFX/Users/admin"
    PROG_DIR = "#{BASE_DIR}/NGSprep"
    EXPORT_DIR = "Desktop/Biofab qPCR Exports/"
    PCRD_SUFFIX = ".pcrd"
    CSV_SUFFIX = " -  Quantification Amplification Results_SYBR.csv"
    SUB_ITEM = "96 shallow plate (M20) part"
    M20_STR = 'M20PF '
    SPIN_TIME = { qty: "1", units: MINUTES }
    SPIN_RPM = { qty: "300", units: "RPM" }
    MAX_OPS = 96
    MIN_VOL = { qty: 10, units: MICROLITERS } # min volume for retaining primer aliquots. please check with lab manager before changing.
    ANSWERS = ["Y","N"]

    NGS_BOX_NAME = "B1234E2 M20 box"

    TEST = "TEST"
    REAL = "REAL"
    BACKGROUND_COLORS = [
        "#ff4133","#ff5733","#ffc033","#8eff33",
        "#33d6ff","#3357ff","#8e33ff","#ff33ea",
        "#ff4133","#ff5733","#ffc033","#8eff33"
    ]

    NUM_REACTIONS = {
        "qPCR1" => 2,
        "qPCR2" => 2,
        "lib_qPCR1" => 2,
        "lib_qPCR2" => 10,
    }

    # The top-level method that runs an entire preparative qPCR protocol
    # A protocol shouldn't have to do anything other than call this method
    #
    def run_protocol
        program_name = validate_operations
        composition = PCRComposition.new(program_name: program_name)
        program = PCRProgram.new(program_name: program_name, volume: composition.volume)

        # TODO: make this method smart enough to deal
        if program.program_name =~ /$lib_/
            initialize_fragment_libraries
        end

        report_errors
        return {} unless operations.running.present?

        sorted_ops = sort_ops
        prepare_materials(sorted_ops, composition)
        sorted_ops.make

        # TODO: create a MasterMix class that handles variables like this
        #   should also handle MAKE_EXTRA calculations
        stamp_columns = program.program_name == 'lib_qPCR2' ? 8 : nil
        set_up_reactions(sorted_ops, composition, stamp_columns)

        run_test_and_real(sorted_ops, program, stamp_columns)

        if program.program_name == "qPCR2"
            associate_barcodes(ops: sorted_ops, input_name: REVERSE_PRIMER, output_name: FRAGMENT)
        elsif program.program_name =~ /$lib_/
            associate_library_data(sorted_ops)
        end

        associate_bins(ops: sorted_ops, input_name: TEMPLATE, output_name: FRAGMENT)
        associate_volumes(ops: sorted_ops, output_name: FRAGMENT, volume: composition.volume)

        sorted_ops.each { |op| op.output(FRAGMENT).item.move(NGS_BOX_NAME) }

        pcr_cleanup
        operations.store

        # remaining_primers = check_primer_volumes(FORWARD_PRIMER, REVERSE_PRIMER)
        check_primer_volumes(sorted_ops, FORWARD_PRIMER, REVERSE_PRIMER)

        display_output_table(sorted_ops)

        get_protocol_feedback

        display_mapping(TEMPLATE, FRAGMENT, sorted_ops) if debug

        return {}
    end

    # Validates operations
    # Checks to see that there is only one qPCR program
    # Checks to see that there are not more than MAX_OPS operations
    # If either of these is true, then errors ALL the operations
    #
    # @return [String] the program name shared by all the operations
    def validate_operations
        ops_by_program = group_ops_by_parameter(PROGRAM, operations)

        msg = nil

        if ops_by_program.length != 1
            programs = ops_by_program.keys.join(", ")
            msg = "Job contains Operations with more than one program (#{programs})."
            msg += " Please replan."
        elsif operations.length > MAX_OPS
            msg = "Max number of ops is #{MAX_OPS} for a single Job."
            msg += " You have #{operations.length} ops. Please replan."
        elsif ops_by_program.keys.first == "lib_qPCR2" && operations.length > 12
            msg = "lib_qPCR2 program is limited to 12 reactions."
            msg += " You have #{operations.length} ops. Please replan."
        end

        if msg.present?
            operations.each do |op|
                op.error :job_failed_validation, msg
            end
        end

        ops_by_program.keys.first
    end

    # Finds data for setting up FragmentLibrary objects and initializes them
    # Attaches a FragmentLibrary to each Operation through its `temporary` variable
    #
    def initialize_fragment_libraries
        operations.each do |op|
            fragment_library = FragmentLibrary.new(
                known_item: op.input(TEMPLATE).item,
                sample: op.output(FRAGMENT).sample
            )
            fragment_library.detect_provenance
            fragment_library.detect_oligo_pools

            fragment_library.set_primers(
                forward_primer: op.input(FORWARD_PRIMER).sample,
                reverse_primer: op.input(REVERSE_PRIMER).sample
            )

            if fragment_library.errors.present?
                fragment_library.errors.each { |k,v| op.error(k,v) }
            else
                op.temporary[:fragment_library] = fragment_library
            end
        end
    end

    # Groups operations by parameter value
    #
    # @param handle [String] handle of the parameter
    # @param ops [OperationList] operations to be grouped
    # @return [Hash]
    def group_ops_by_parameter(handle, ops)
        ops.group_by { |op| op.input(handle).val }
    end

    # Sorts running operations by REVERSE_PRIMER and TEMPLATE
    #
    # @return [OperationList]
    def sort_ops
        operations.running.sort_by { |op| sort_array(op) }.extend(OperationList)
    end

    # Provides attributes for and Operation in the form of an Array
    #
    # @param op [Operation]
    # @return [Array]
    def sort_array(op)
        [op.input(REVERSE_PRIMER).sample.name, op.input(TEMPLATE).item.id]
    end

    # Provisions all materials required for the protocol, and instructs the technician
    #   to retrieve them
    #
    # @param ops [OperationList]
    # @param composition [PCRComposition]
    # @todo Make this deal better with primers that are in collections
    #   e.g., "take" and "release" are used in place of .retrieve and .store so
    #   that sub-plate items are not retrieved or stored individually
    def prepare_materials(ops, composition)
        # ops.each do |op|
        #     add_hidden_input(op, DYE_SAMPLE, dye)
        #     add_hidden_input(op, POLYMERASE_SAMPLE, polymerase)
        # end

        templates = ops.map { |op| op.input(TEMPLATE).item }

        fwd_primers = get_primer_set(ops, FORWARD_PRIMER)
        rev_primers = get_primer_set(ops, REVERSE_PRIMER)

        items_to_take = [templates, fwd_primers, rev_primers]

        if composition.polymerase.item
            items_to_take << composition.polymerase.item
        end

        if composition.dye.item
            items_to_take << composition.dye.item
        end

        take(items_to_take.flatten, interactive: true, method: 'boxes')

        vortex_samples([fwd_primers, rev_primers, templates])
    end

    # Finds and returns a list of all Primers used across all Operations
    #
    # @param ops [OperationList]
    # @param handle [String]
    # @return [Array<Item>]
    def get_primer_set(ops, handle)
        # primers - need to find the collection if the Primer is a sub-item
        primers = ops.map do |op|
            if op.input(handle).object_type.name == SUB_ITEM
                Item.find(op.input(handle).item.get("collection"))
            else
                op.input(handle).item
            end
        end

        primers.uniq
    end

    # Vortexes and spins down samples before use
    #
    # @param all_items [Array<Item>] array of items to vortex and spin down
    def vortex_samples(all_items)
        all_items = all_items.flatten.uniq
        collections, non_collections = all_items.partition { |it| it.collection? }

        show do
            title "Vortex and Spin Down"

            note "Briefly vortex and spin down all items in 1.5 ml tubes"
            if collections.any?
                note "Centrifuge the following plates for #{qty_display(SPIN_TIME)} at #{qty_display(SPIN_RPM)}: #{collections.to_sentence}"
                warning "Please balance the centrifuge"
            end
        end
    end

    # Sets up and dispenses master mixes, primers, templates
    # Splits into TEST and REAL reactions
    #
    # @param ops [OperationList]
    # @param composition [PCRComposition]
    # @param stamp_columns [Numeric, Boolean] can be either a number of replicates of
    #   each reaction (stamps) or a Boolean. If merely true, then defaults to
    #   the `DEFAULT_STAMP_COLUMNS` number of replicates
    def set_up_reactions(ops, composition, stamp_columns=nil)
        mult = MAKE_EXTRA

        if stamp_columns
            stamp_columns = DEFAULT_STAMP_COLUMNS unless stamp_columns.is_a?(Numeric)
            stamp_columns = stamp_columns.to_i
            mult *= (1 + stamp_columns)
        else
            mult *= 2
        end

        prepare_stripwells(FRAGMENT, ops, stamp_columns)

        input_names = [FORWARD_PRIMER, REVERSE_PRIMER, TEMPLATE]
        group_input_names, grouped_ops = group_ops_by_inputs(input_names: input_names, ops: ops)
        inputs_not_added = input_names - group_input_names

        ops_by_master_mix = make_master_mixes(
            grouped_ops: grouped_ops,
            input_names: group_input_names,
            composition: composition,
            mult: mult
        )

        dispense_master_mix(
            output_name: FRAGMENT,
            ops_by_master_mix: ops_by_master_mix,
            composition: composition,
            mult: stamp_columns ? mult : 2
        )

        ops_by_master_mix.values.each do |ops|
            inputs_not_added.each do |input_name|
                dispense_component(
                    input_name: input_name,
                    output_name: FRAGMENT,
                    ops: ops,
                    composition: composition,
                    mult: stamp_columns ? mult : 2
                )
            end
        end

        split_reactions(FRAGMENT, ops, composition, stamp_columns)
    end

    # Prepares stripwells for qPCR
    #
    # @param outname [String] output name
    # @param ops [OperationList] operations
    # @param stamp_columns [FixNum, Boolean] can be either a number of replicates of
    #   each reaction (stamps) or a Boolean.
    def prepare_stripwells(outname, ops, stamp_columns)
        coll = ops.first.output(outname).collection # get collection item
        tab = display_plate(outname, ops, stamp_columns)
        show do
            title "Prepare Stripwells"
            check "Get two holders for 96 stripwells"
            check "Label the holders <b>#{coll}-#{TEST}</b> and <b>#{coll}-#{REAL}</b>"
            note "These are for <b>#{TEST}</b> and <b>#{REAL}</b> qPCR runs"

            if stamp_columns.is_a?(Numeric) && stamp_columns > 1
                warning "Each column is #{stamp_columns} identical reactions"
            end

            check "Get white stripwells with connected transparent caps"
            note "Arrange a set of stripwells in each holder and label their <b>sides</b> as follows:"
            table tab
        end
    end

    # Splits reactions into REAL and TEST tubes
    #
    # @param outname [String] output name
    # @param ops [OperationList] operations
    # @param program [String] the qPCR program
    def split_reactions(outname, ops, composition, stamp_columns)
        coll = ops.first.output(outname).collection

        step_1 = "Place <b>#{coll}-#{TEST}</b> and <b>#{coll}-#{REAL}</b>"
        step_1 += " in the same orientation on the bench"

        if stamp_columns.is_a?(Numeric) && stamp_columns > 1
            step_2 = "Transfer <b>#{composition.qty_display}</b> of"
            step_2 += " reaction mix from each microfuge tube"
            step_2 += " to the corresponding tube in"
            step_2 += " <b>#{coll}-#{TEST}</b>"

            step_3 = "Transfer <b>#{stamp_columns} #{composition.qty_display} aliquots</b> of"
            step_3 += " reaction mix from each microfuge tube"
            step_3 += " to the corresponding <b>column</b> in"
            step_3 += " <b>#{coll}-#{REAL}</b>"
        else
            step_2 = "Transfer <b>#{composition.qty_display}</b> of"
            step_2 += " reaction mix from each tube in"
            step_2 += " <b>#{coll}-#{TEST}</b> to the corresponding tube in"
            step_2 += " <b>#{coll}-#{REAL}</b>"

            step_3 = ""
        end

        show do
            title "Split Reactions"
            check step_1
            check step_2
            check step_3 if step_3.present?
        end
    end

    # Runs both qPCRs, uploads and parses run data
    #
    # @param ops [OperationList]
    # @param program [String]
    def run_test_and_real(ops, program, stamp_columns=nil)
        run_qpcr(FRAGMENT, ops, program, TEST, stamp_columns)
        csv_upload = upload_data(FRAGMENT, ops, program, TEST)
        find_stop_cycles(FRAGMENT, ops, csv_upload)
        separate_tubes(FRAGMENT, ops, REAL, stamp_columns)
        run_qpcr(FRAGMENT, ops, program, REAL, stamp_columns)
        upload_data(FRAGMENT, ops, program, REAL)
    end

    # Runs qPCR program for operations using program
    #
    # @param outname [String] output name
    # @param ops [OperationList] operations
    # @param program [String] the qPCR program
    # @param test_str [String] typically 'TEST' or 'REAL', info related to qPCR run
    def run_qpcr(outname, ops, program, test_str, stamp_columns)
        coll = ops.first.output(outname).collection

        display_plate = display_plate(outname, ops, stamp_columns)
        stub = upload_stub(program, test_str)

        show do
            title "Place #{test_str} stripwells in qPCR machine"
            check "Open #{SOFTWARE} on qPCR computer and make sure the qPCR is not running"
            note "Open lid"
            note "Place the <b>#{coll}-#{test_str}</b> stripwells in the block in the following order"
            table display_plate
            note "Close lid"
        end

        show do
            title "Program Setup: #{stub}"
            check "Open #{SOFTWARE} if not already open"
            check "Choose <b>File->Open->Protocol</b>"
            if stub == "qPCR1_REAL"
                check "Navigate to <b>#{PROG_DIR}</b> and select <b>NGS_qPCR1_2.prcl</b>"
            else 
                check "Navigate to <b>#{PROG_DIR}</b> and select <b>#{program.name}</b>"
            end
            note "Your program should have the following steps. If not, notify a lab manager."
            table program.table
            check "Set the <b>Sample Volume</b> to <b>#{program.volume}</b>"
            check "Press <b>OK</b> (in the #{SOFTWARE})"
        end

        show do
            title "Plate Setup: #{stub}"
            check "Press <b>Next</b>. You are now on the <b>Plate</b> tab. Press <b>Select Existing</b>."
            check "Navigate to <b>#{PROG_DIR}</b>. Choose <b>#{program.plate}</b> and press <b>Open</b>."
            check "Press <b>Edit Selected</b>. Make sure the occupied wells match the table below:"
            table display_plate
            check "Make sure <b>SYBR</b> is checked for all wells in the table"
            check "Press <b>OK</b> (n the #{SOFTWARE})"
        end

        data = show do
            title "Run: #{stub}"
            check "Press <b>Next</b>. You are now on the <b>Start Run</b> tab."
            check "Press <b>Start Run</b>"
            note "Copy the auto-generated filename for the run and paste it below:"
            get "text", var: :name, label: "file name", default: "filename#{PCRD_SUFFIX}"
            if(test_str == TEST)
                check "Proceed immediately to the next step while you are waiting for the qPCR <b>#{test_str}</b> run to finish"
            end
        end

        ops.first.plan.associate "#{upload_stub(program, test_str)}_name", data[:name]

        if(test_str == REAL) # display stop cycle
            stop_cycle = ops.first.output(outname).collection.get("stop_cycle")

            if stop_cycle.present?
                msg = "The qPCR samples each require a different number of cycles."
                msg += " To acheive this without disrupting the run, you will press"
                msg += " on the <b>Pause</b> software button at the <b>end</b> of the"
                msg += " elongation step at each of the cycles:"
                msg += " <b>#{stop_cycle.flatten.uniq.select!{|i| i>0}.sort.to_sentence}</b>"
                msg += " and remove the relevant sample(s), as indicated in the following table:"

                show do
                    title "Stop at Cycle"
                    note msg
                    table display_stop_cycles(outname, ops, stamp_columns)
                end
            else # this should not happen!
                raise "No stop cycle info found."
            end
        end

    end

    # Uploads .pcrd and .csv file and returns .csv upload (both are associated to plan)
    #
    # @param outname [String] output name
    # @param ops [OperationList] operations
    # @param program [String] the qPCR program
    # @param test_str - typically 'TEST' or 'REAL', info related to qPCR run (enables differentiation between multiple associations in the same plan)
    # @return csv_upload - upload hash of .csv file (y/n .csv is not verified by function)
    def upload_data(outname, ops, program, test_str)
        plan = ops.first.plan
        coll = Item.find(ops.first.output(outname).collection)
        stub = upload_stub(program, test_str)

        show do
            title "Save data: #{stub}"
            note "When qPCR reaches #{program.final_step}, stop run"
            note "Export the current run in csv format to <b>#{EXPORT_DIR}</b>, as follows:"
            check "Delete any existing files in <b>#{EXPORT_DIR}</b>"
            check "In the #{SOFTWARE}, press <b>Export->Export all data sheets->csv</b>, and save to <b>#{EXPORT_DIR}</b>"
            note "You will now be asked to upload specific files"
        end

        # upload .csv of fluorescence per cycle (used for stop-cycle detection)
        csv_name = plan.get("#{stub}_name").gsub(PCRD_SUFFIX,CSV_SUFFIX)
        csvs = uploadData("#{EXPORT_DIR}/#{csv_name}", 1, 3)
        csv_upload = nil
        if csvs.present?
            plan.associate "#{stub}_csv", "#{stub}", csvs[0] # upload
            coll.associate "#{stub}_csv", csvs[0] # regular association
            csv_upload = csvs[0]
        end

        # upload .pcrd
        ups = uploadData("#{BASE_DIR}/#{plan.get("#{stub}_name")}", 1, 3)
        if(!ups.nil?)
            plan.associate "#{stub}_data", "#{stub}", ups[0] # upload
            coll.associate "#{stub}_data", ups[0] # regular association
        end

        return csv_upload
    end

    def upload_stub(program, test_str)
        "#{program.program_name}_#{test_str}"
    end

    # Finds stop cycle for REAL run from TEST run and associates to collection
    # Assumes all operations in ops are in the same collection
    # Algorithm - max in diff of data (right edge)
    # If algorithm fails, protocol asks that stop cycles be entered manually.
    #
    # @param outname [String] name of output collection
    # @param ops [OperationList] operations
    # @param program [String] program
    # @param up - upload hash of data file that contains the TEST run data used for calculation of the stop cycle (XXX - Quantification Amplification Results_SYBR.csv)
    def find_stop_cycles(outname, ops, up)
        stop_cycle = Array.new(8){Array.new(12, 0)} # stop_cycle(i,j) is stop cycle for collection item (i,j)
        outcol = ops.first.output(outname).collection # same collection for all ops

        mismatch = false # mismatch between collection, stop_cycle data

        # attempt to find stop cycle
        if(!up.nil?)
            data = read_url(up) # get data
            if(!data.empty?)
                # knock of first row and first 2 columns, leaving transposed so each col is now a row. (see format of XXX - Quantification Amplification Results_SYBR.csv)
                row_offset = 1
                col_offset = 2
                dataArray = data[row_offset..-1].transpose[col_offset..-1]
                dataArray.each_with_index { |col, ind|  # column of ORIGINAL data
                    diff = col.each_cons(2).map { |a,b| b.to_f - a.to_f } # difference of each consecutive 2 elements
                    maxind = diff.each_with_index.max[1] + 2 # returns index of max value in diff, + 1 for right edge, + 1 for a little extra
                    col_str = data[0][ind+col_offset] # well label, e.g. "A1"
                    mymatch = /(?<myrow>[A-H]{1,1})(?<mycol>[0-9]{1,2})/.match(col_str)
                    if(!mymatch.nil?)
                        rr = (mymatch[:myrow].ord-"A".ord).to_i    # subtract ascii value of "A" from A-H to get row integer, 0-7
                        cc = mymatch[:mycol].to_i-1                # col integer, 0-11
                        if(outcol.matrix[rr][cc] > 0) # collection item exists for this (rr,cc)
                            stop_cycle[rr][cc] = maxind
                        else
                            show { note "stop_cycle indices (#{rr},#{cc}) do not match collection!" } if debug
                            mismatch = true
                        end
                    end
                }

                num_stop_samples = outcol.matrix.flatten.map{|x| x>0 ? 1:0}.sum
                num_collection_samples = stop_cycle.flatten.map{|x| x>0 ? 1:0}.sum
                show { note "HAVE DATA from test run. match = #{mismatch}, num_stop_samples = #{num_stop_samples}, num_collection_samples = #{num_collection_samples}" } if debug

                # associate stop cycles to collection item
                if( !mismatch || (num_stop_samples == num_collection_samples) ) # 1:1 correlation between collection, stop_cycle indices
                    Item.find(outcol.id).associate "stop_cycle", stop_cycle
                end

            else
                show { note "problem: data.empty? = #{data.empty?}" } if debug
            end

        else
            show { note "problem: up.nil? = #{up.nil?}" } if debug
        end

        # something went wrong, need manual entry of stop_cycles
        if(Item.find(outcol.id).get("stop_cycle").nil?)
            show {
                title "Enter Stop Cycles for #{REAL} run manually"
                table ops.start_table
                  .output_collection(outname, heading: outname)
                  .custom_column(heading: "Plate position", checkable: true) { |op| "#{(op.output(outname).row + "A".ord).chr}#{op.output(outname).column + 1}" }
                  .get(:stop, type: 'number', heading: 'Stop qPCR at this cycle', default: 0)
                  .end_table
            }
            # associate manually-entered stop cycles to collection item
            ops.each { |op|
                stop_cycle[op.output(outname).row][op.output(outname).column] = op.temporary[:stop].round
            }
            Item.find(outcol.id).associate "stop_cycle", stop_cycle
        end

        if(debug)
            ops.each { |op|
                stop_cycle[op.output(outname).row][op.output(outname).column] = 5+rand(5).round
            }
            Item.find(outcol.id).associate "stop_cycle", stop_cycle
        end

    end

    # Separates single wells for individual extraction while qPCR is running
    #
    # @param outname [String] output name
    # @param ops [OperationList] operations
    # @param test_str [String] typically 'TEST' or 'REAL', info related to qPCR run
    def separate_tubes(outname, ops, test_str, stamp_columns)
        stop_cycles_tab = display_stop_cycles(outname, ops, stamp_columns)
        wells_tab = display_plate(outname, ops, stamp_columns)
        coll = ops.first.output(outname).collection # get collection item

        show do
            title "Separate #{test_str} stripwell tubes"
            note "During the <b>#{REAL}</b> qPCR run, you will need to remove single wells when different cycles are reached, according to the following:"
            table stop_cycles_tab
            check "Get a scissors and carefully separate the wells of <b>#{coll}-#{test_str}</b>"
            check "Verify that the separated wells are in the correct order:"
            table wells_tab
        end
    end

    def associate_library_data(ops)
        ops.each do |op|
            program = op.input(PROGRAM).val
            fragment_library = op.temporary[:fragment_library]
            output_item = op.output(FRAGMENT).part

            output_item.associate(:template_id, op.input(TEMPLATE).sample.id)
            output_item.associate(:forward_primer_id, op.input(FORWARD_PRIMER).sample.id)
            output_item.associate(:reverse_primer_id, op.input(REVERSE_PRIMER).sample.id)
            output_item.associate(:variants, fragment_library.variants)
        end
    end

    # Cleanup
    def pcr_cleanup
        show do
            title "Cleanup"
            check "Remove samples from the qPCR and stop the #{SOFTWARE}"
            check "Trash all <b>MM</b> tubes"
            check "Trash all <b>#{TEST}</b> stripwell tubes"
            warning "Keep <b>#{REAL}</b> tubes on bench for next protocol!"
        end
    end

    # Checks volumes of primer aliquots after use, before store
    # Deletes empty aliquots
    # OF for primers in plates
    #
    # @param ops [OperationList]
    # @param fwdname [String]
    # @param revname [String]
    def check_primer_volumes(ops, fwdname, revname)
        items_to_check = ops.map { |op| op.input(fwdname).item }.uniq
        items_to_check += ops.map { |op| op.input(revname).item }.uniq

        show do
            title "Check the remaining volume of the primers"

            check "Check the remaining volume in primer items #{items_to_check.to_sentence}"
            warning "Notify a lab manager if there is less than #{qty_display(MIN_VOL)} left for any of the primers"
        end
    end

    # Checks volumes of primer aliquots after use, before store
    # Deletes empty aliquots
    # OF for primers in plates
    #
    # @param fwdname [String]
    # @param revname [String]
    # @return [Array] items for primers with non-zero volume
    # def check_primer_volumes(fwdname, revname)
    #     remaining_primers = nil

    #     show do
    #         title "Check the remaining volume of the primers"

    #         table operations.uniq { |op| op.input(fwdname).item }.extend(OperationList).start_table
    #             .custom_column(heading: "Location") { |op| coll_id_display(op, fwdname) }
    #             .get(:have_fwd_volume, heading: "Is there more than #{MIN_VOL[:qty]} #{MIN_VOL[:units]} left?", type: "text", default: "Y")
    #             .end_table

    #         table operations.uniq { |op| op.input(revname).item }.extend(OperationList).start_table
    #             .custom_column(heading: "Location") { |op| coll_id_display(op, revname) }
    #             .get(:have_rev_volume, heading: "Is there more than #{MIN_VOL[:qty]} #{MIN_VOL[:units]} left?", type: "text", default: "Y")
    #             .end_table
    #     end

    #     # for debug - assign responses
    #     # if(debug)
    #     #     operations.each { |op|
    #     #         op.temporary[:have_fwd_volume] = ANSWERS.rotate!.first # "Y" or "N"
    #     #         op.temporary[:have_rev_volume] = ANSWERS.rotate!.first # "Y" or "N"
    #     #     }
    #     # end

    #     # find empty Primer Aliquot, Collection items
    #     fwd_empty = operations.select{|o| (o.temporary[:have_fwd_volume] == "N") }.map { |op| op.input(fwdname).item }
    #     rev_empty = operations.select{|o| (o.temporary[:have_rev_volume] == "N") }.map { |op| op.input(revname).item }
    #     trash_items = [fwd_empty,rev_empty].flatten.uniq
    #     trash_colls = []  # collection items to be trashed

    #     if(!trash_items.empty?)
    #         trash_items.each { |it|
    #             if(it.object_type.name == SUB_ITEM) # need to remove deleted item and check collection for remaining items
    #                 coll = Collection.find(it.get("collection"))
    #                 locs = Matrix[*(coll.matrix)].index(it.id)  # find position of item in collection matrix, returns array with [row,col]
    #                 if(!locs.nil?)
    #                     coll.matrix[locs[0]][locs[1]] = -1
    #                     coll.save
    #                     if( (coll.matrix.flatten.select { |well| well>0 }.count) == 0 ) # no items left in collection matrix
    #                         trash_colls.push(coll) # collection items to be trashed
    #                         coll.mark_as_deleted   # delete collection
    #                     end
    #                 else # should not happen!!! will show up in test mode because the assignment of collections is fake
    #                     show { warning "Please notify a lab manager that you could not find the location of #{it} in #{coll}!" }
    #                 end

    #             end
    #             it.mark_as_deleted # delete item
    #         }
    #         show {
    #             title "Trash empty Primer items"
    #             note "Trash primer aliquots #{trash_items.select{ |it| !(it.object_type.name == SUB_ITEM) }.to_sentence}" # can't trash parts of a plate
    #             if(!trash_colls.empty?)
    #                 note "Trash primer plates #{trash_colls.to_sentence}"
    #             end
    #         }
    #     end

    #     # remaining primers (to be stored)
    #     fwd_primers = operations.select{|o| !(o.temporary[:have_fwd_volume] == "N") }.map { |op|
    #         (op.input(fwdname).object_type.name == SUB_ITEM) ? Item.find(op.input(fwdname).item.get("collection")) : op.input(fwdname).item }

    #     rev_primers = operations.select{|o| !(o.temporary[:have_rev_volume] == "N") }.map { |op|
    #         (op.input(revname).object_type.name == SUB_ITEM) ? Item.find(op.input(revname).item.get("collection")) : op.input(revname).item }

    #     remaining_primers = [fwd_primers, rev_primers].flatten.uniq

    #     return remaining_primers

    # end

    # Adds volumes to parts associated with the output collections
    #
    # @param ops [OperationList]
    # @param output_name [String]
    # @param volume [FixNum, Float, String]
    def associate_volumes(ops:, output_name:, volume:)
        ops.each do |op|
            op.output(output_name).part.associate(:volume, volume)
        end
    end

    def display_output_table(ops)
        # display table for lab manager (to cut and paste for NGS record)
        show do
            title "List of qPCR fragments"
            table ops.start_table
                .input_item(TEMPLATE)
                .custom_column(heading: "name") { |op| op.input(TEMPLATE).sample.name }
                .custom_column(heading: "bin") { |op| bin_display(op: op, input_name: TEMPLATE) }
                .custom_column(heading: "qPCR program") { |op| op.input(PROGRAM).val }
                .custom_column(heading: "Illumina index") { |op| "<pre>#{op.output(FRAGMENT).part.get(:barcode)}</pre>" }
                .end_table
        end
    end

    # Displays mapping between input and output items
    #
    # @param inname [String] input name
    # @param outname [String] output name
    # @param ops [OperationList] operations
    def display_mapping(inname, outname, ops)
        show do
            title "mapping"
            table ops.start_table
                .output_item(outname)
                .input_item(inname)
                .custom_column(heading: "Volume") { |op| op.output(FRAGMENT).part.get(:volume) }
                .end_table
        end
    end

    # Creates table with the stop cycles defined for samples in output collection
    #
    # @param outname [String] output name
    # @param ops [OperationList] operations
    # @param program [String] the qPCR program
    # @return tab - table containing stop cylces (to be used in show block)
    def display_stop_cycles(outname, ops, stamp_columns)
        tab = Array.new(8) { Array.new(12, "-") }
        stop_cycle = ops.first.output(outname).collection.get("stop_cycle")

        if stop_cycle.present?
            stop_cycle[0].length.times do |cc|
                col = cc+1
                if stamp_columns
                    if(stop_cycle[0][cc]>0)
                        tab[0][cc] = {content: "A#{col} cycle #{stop_cycle[0][cc]}", check: "true"}
                        (1..stamp_columns - 1).each do |rr|
                            row = (rr+"A".ord).chr
                            tab[rr][cc] = {content: "cycle #{stop_cycle[0][cc]}", check: "false"} # wells are connected
                        end
                    end
                else
                    stop_cycle.length.times { |rr|
                        if(stop_cycle[rr][cc]>0)
                            row = (rr+"A".ord).chr
                            tab[rr][cc] = {content: "#{row}#{col} cycle #{stop_cycle[rr][cc]}", check: "true"}
                        end
                    }
                end
            end
        end

        return tab
    end

    # Displays id / position for items that may be sub-items in collections
    #
    # @param op [Operation]
    # @param handle [String] input or output name
    # @param role [String] "input" or "output"
    # @param hide_id [Boolean] whether to include the Collection ID
    # @return [String] Item ID followed by location if a collection
    def coll_id_display(op, handle, role='input', hide_id=false)
        if role == 'input'
            fv = op.input(handle)
        elsif role == 'output'
            fv = op.output(handle)
        else
            raise "Unrecognized role: #{role}"
        end

        display = hide_id ? "" : fv.item.to_s

        if fv.item.collection?
            row, col = fv.row, fv.column

            unless row && col
                row, col = fv.collection.find(fv.sample).first
            end

            display += " #{well_pos_display(row, col)}"
        end

        display.strip
    end

    def well_pos_display(row, col)
        alpha_r = ('A'..'H').to_a
        "#{alpha_r[row]}#{col + 1}"
    end

    # Creates table of output locations in 96-well format
    #
    # @param outname [String] output name
    # @param ops [OperationList] operations
    # @param stamp_columns [String] make all 8 reactions in a column the same
    # @return [Array] 2D Array containing locations to be used in show block
    def display_plate(outname, ops, stamp_columns=false)
        plate = Array.new(8) { Array.new(12, "-") }
        if stamp_columns
            ops.each do |op|
                col = op.output(outname).column
                background = BACKGROUND_COLORS[col]
                content = "#{("A".ord.to_i).chr}#{col+1}"
                plate[0][col] = {content: content, style: {background: background} }
                (1..stamp_columns - 1).each do |row|
                    plate[row][col] = { content: " ", style: { background: background } }
                end
            end
        else
            ops.each do |op|
                row = op.output(outname).row
                col = op.output(outname).column
                plate[row][col] = {content: "#{(row + "A".ord.to_i).chr}#{col+1}", style: {background: BACKGROUND_COLORS[0] }  }
            end
        end

        return plate
    end

end