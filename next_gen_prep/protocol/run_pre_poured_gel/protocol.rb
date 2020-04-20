# SG
# this version for pre-poured gel
#
# gel type and percentage are associated with gel (collection)
# empty lanes depend on percentage:
#   0.8% - 2 empty lanes in each row (1kb and 100bp ladders)
#   2.0% - 1 empty lane  (100bp ladder)
#
needs "Standard Libs/Feedback"
needs "Standard Libs/Debug"
needs "Standard Libs/Units"
needs "Collection Models/DNAGel"
needs "Next Gen Prep/NextGenPrepHelper"
needs "Tissue Culture Libs/CollectionDisplay"

class Protocol

    include Feedback, Debug, Units, NextGenPrepHelper, CollectionDisplay

    # I/O
    FRAGMENT = "Fragment" # input and output
    TYPE = "Gel Type"
    PERCENTAGE = "Percentage"

    # other
    LADDER_100BP = "100 bp Ladder"
    LADDER_1KB = "1 kb Ladder"
    LOADING_DYE = "6X Loading Dye"

    DYE_CONCENTRATION = 6

    LADDER =    {qty: 10, units: MICROLITERS}
    TOTAL =     {qty: 60, units: MICROLITERS}
    TIME =      {qty: 40, units: MINUTES}
    VOLTAGE =   {qty: 100, units: VOLTS}

    def main

        if debug
            associate_test_volumes(operations)
            associate_random_barcodes(operations: operations, in_handle: FRAGMENT)
        end

        provisioned_gels = provision_gels(operations, true)

        ladders_and_dyes = take_ladders_dyes_and_gels(provisioned_gels: provisioned_gels)

        operations_running_strict.retrieve(only: FRAGMENT)

        set_up_gel_boxes

        add_dye_to_samples(operations: operations_running_strict, input_handle: FRAGMENT)

        add_samples(provisioned_gels: provisioned_gels)

        start_electrophoresis

        clean_up(operations: operations_running_strict, ladders_and_dyes: ladders_and_dyes)

        operations_running_strict.each do |op|
            txfr_barcode(op, FRAGMENT, FRAGMENT)
            txfr_bin(op, FRAGMENT, FRAGMENT)
        end

        get_protocol_feedback

        if debug
            display_barcode_associations(operations: operations_running_strict, in_handle: FRAGMENT)
            inspect provisioned_gels.values.flatten.map { |gel| gel.deleted? }.to_s
            inspect operations_running_strict.map { |op| op.output(FRAGMENT).collection.deleted? }.to_s
        end

        return {}

    end

    def provision_gels(operations, show_debug=false)

        ladder_100 = Sample.find_by_name(LADDER_100BP)
        ladder_1k = Sample.find_by_name(LADDER_1KB)

        if debug && show_debug
            operations.shuffle!
            debug_table(operations)
            # return
        end

        ops_by_gel = group_ops_by_gel(operations)

        if debug && show_debug
            ops_by_gel.each do |gel_params, ops|
                debug_table(ops, gel_params)
            end
            # return
        end

        provisioned_gels = {}
        gel_table = [["Gel Percentage", "Gel Type", "Gel Items"]]

        ops_by_gel.each do |gel_params, ops|
            percentage, agarose_type = gel_params

            ladders = [ladder_100]
            ladders.insert(0, ladder_1k) if percentage == '0.8'

            matching_gels = DNAGel.matching_gels(agarose_type: agarose_type, percentage: percentage)
            gel_layouts = []

            while ops.any? && matching_gels.any? do
                gel = matching_gels.shift
                gel_layout = DNAGel.new(gel: gel)
                gel_layout.add_ladders(samples: ladders)
                ops = gel_layout.add_operations(operations: ops, output_handle: FRAGMENT)
                gel_layout.mark_as_deleted
                gel_layouts << gel_layout
            end

            orphans = ops

            row = [
                percentage,
                agarose_type,
                gel_layouts.map { |g| g.gel.id }.sort.to_sentence,
            ]

            gel_table << row

            if orphans.any?
                orphans.each { |op| op.change_status('pending') }

                show do
                    title "Rejected Operations"
                    note "The following Operations will be set back to pending because there are not enough gels"
                    warning "Please notify a lab manager"
                    note orphans.map { |op| op.id }.sort.to_sentence
                end
            end

            provisioned_gels[gel_params] = gel_layouts
        end

        show do
            title "Get Gels"

            note "You will need the following #{DNAGel::GENERIC_GEL} Items"
            table gel_table
        end

        provisioned_gels
    end

    def take_ladders_dyes_and_gels(provisioned_gels:)
        ladder_and_dye_items = []
        gel_items = []
        ladder_samples = []

        provisioned_gels.values.each do |gel_layouts|
            gel_layouts.each do |gel_layout|
                ladder_samples += gel_layout.ladders
                gel_items << gel_layout.gel
            end
        end

        ladder_and_dye_items += ladder_samples.uniq.map { |ls| ls.in("Ladder Aliquot").first }
        ladder_and_dye_items << dye = Sample.find_by_name(LOADING_DYE).in("Screw Cap Tube").first

        take(ladder_and_dye_items, interactive: true)
        take(gel_items, interactive: true)

        ladder_and_dye_items
    end

    def set_up_gel_boxes
        show do
            title "Set up the power supply"
            note  "In the gel room, obtain a power supply and set it to #{qty_display(VOLTAGE)} and with a #{qty_display(TIME)} timer."
            note  "Attach the electrodes of the gel box lid(s) to the power supply."
            image "Items/gel_power_settings.JPG"
        end

        show do
            title "Set up the gel box(es)"

            check "Remove the comb(s) and put them away."
            check "Check the orientation of the gels in the gel boxes."
            warning "With the gel box(s) electrodes facing away from you, the top lane(s) should be on your left."

            check "Using a graduated cylinder, fill the gel box(s) with 250 #{MILLILITERS} of 1X TAE."
            warning "The TAE should just cover the center of the gel(s) and fill the wells."

            check "Put the graduated cylinder away."
            image "Items/gel_fill_TAE_to_line.JPG"
        end
    end

    def add_dye_to_samples(operations:, input_handle:)
        ops_by_collection = operations.group_by { |op| op.input(input_handle).collection }

        show do
            title "Add dye to samples"

            ops_by_collection.each_with_index do |(coll, ops), i|
                if i > 0
                    note " "; separator; note " "
                end

                note "Add the indicated volumes (in #{MICROLITERS}) of #{LOADING_DYE} to the highlighted wells in " \
                        "#{coll.object_type.name} <b>#{coll.id}</b>"

                rcx_list = ops.map do |op|
                    fv = op.input(input_handle)
                    dye_volume = fv.part.get(:volume) || 50
                    dye_volume = dye_volume.to_i / (DYE_CONCENTRATION - 1)
                    [fv.row, fv.column, dye_volume]
                end

                table highlight_alpha_rcx(coll, rcx_list)
            end
        end
    end

    def add_samples(provisioned_gels:)
        %w(ladder sample).each do |stub|
            provisioned_gels.each do |gel_params, gel_layouts|
                show do
                    title "Add #{stub}s"
                    gel_layouts.each_with_index do |gel_layout, i|
                        if i > 0
                            note " "; separator; note " "
                        end

                        if stub == 'ladder'
                            note "Add #{qty_display(LADDER)} ladders to gel " \
                                    "<b>#{gel_layout.gel.id}</b> as indicated:"
                            table gel_layout.ladder_display
                        else
                            note "Transfer the entire #{qty_display(TOTAL)} of each sample to gel " \
                                    "<b>#{gel_layout.gel.id}</b> as indicated:"
                            table gel_layout.sample_display(input_handle: FRAGMENT)
                        end
                    end
                end
            end
        end
    end

    def start_electrophoresis
        show do
            title "Start Electrophoresis"
            note "Carefully attach the gel box lid(s) to the gel box(es)."
            warning "Be careful not to bump the samples out of the wells."
            note "Attach the red electrode to the red terminal of the power supply, and the black electrode to the black terminal."
            note "Press the start button on the power supply."
            note "Make sure the power supply is not erroring (no E* messages) and that there are bubbles emerging from the wires in the bottom corners of the gel box."
            image "gel_check_for_bubbles"
        end

        show do
            title "Set a timer"
            check "When you get back to your bench, set a #{qty_display(TIME)} timer."
            check "When the timer is up, get a lab manager to check on the gel."
            note "The lab manager may have you set another timer after checking the gel."
        end
    end

    def clean_up(operations:, ladders_and_dyes:)
        show do
            title "Discard Stripwells"
            note "Discard all the empty stripwells"
        end

        release(ladders_and_dyes, interactive: true)

        # delete input collection parts
        operations.each do |op|
            fv = op.input(FRAGMENT)
            fv.collection.mark_as_deleted
            fv.part.mark_as_deleted
        end
    end

    # group operations by gel [percentage, type]
    def group_ops_by_gel(ops)
        ops_by_gel = ops.group_by { |op| pct_and_type(op) }
        ops_by_gel.each do |gel_params, ops|
            ops.sort_by! { |op| sort_list(op) }.extend(OperationList)
        end
        ops_by_gel
    end

    def sort_list(op)
        fv = op.input(FRAGMENT)
        [fv.child_item_id, fv.row, fv.column]
    end

    def pct_and_type(op)
        [op.input(PERCENTAGE).val, op.input(TYPE).val]
    end

    def associate_test_volumes(ops)
        ops.each { |op| op.input(FRAGMENT).part.associate(:volume, 32) }
    end

    def debug_table(ops, gel_params="")
        show do
            note gel_params
            table ops.start_table
                .input_item(FRAGMENT)
                .custom_column(heading: "Gel Row") { |op| op.input(FRAGMENT).row }
                .custom_column(heading: "Gel Col") { |op| op.input(FRAGMENT).column }
                .end_table
        end
    end

    # Selects `operations` with `status == 'running'`
    # Different from {Operations#running}, which selects based on
    #   `status != 'error'`
    #
    def operations_running_strict
        operations.select { |op| op.status == 'running' }
    end

end