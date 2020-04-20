# Devin Strickland
# dvn.strcklnd@gmail.com

needs "Yeast Display/YeastDisplayHelper"
needs "Standard Libs/Debug"
needs "Standard Libs/PlanParams"
needs "Flow Cytometry/SonySH800S"
needs "Flow Cytometry/BDAriaIII"

class Protocol

    include Debug, PlanParams
    include Cytometers::SonySH800S, Cytometers::BDAriaIII
    include YeastDisplayHelper

    attr_accessor :now_sorting, :tube_ct

    INPUT_YEAST = 'Labeled Yeast Library'
    OUTPUT_YEAST = 'Labeled Yeast Library'

    RESUSPENSION_BUFFER = 'PBSF'

    MICROFUGE_TUBE = '1.5 ml microfuge tube'
    COLLECTION_TUBE = '15 ml polypropylene conical tube'
    SAMPLE_TUBE = '5 ml polystyrene round-bottom tube'

    CALIBRATION_BEADS = "SpheroTech ultra rainbow"
    CALIBRATION_BEAD_VOLUME = { qty: 250, units: MICROLITERS }
    CALIBRATION_BEADS_LABEL = 'beads'
    BEAD_CAP_COLORS = ['brown', 'white']

    AUTOFLUORESCENCE_CONTROL = 'autofluorescence'
    HIGH_FITC_CONTROL = 'high-fitc'
    HIGH_PE_CONTROL = 'high-pe'
    PROTEASE_CONTROL = 'protease'

    CONTROL_NAMES = [AUTOFLUORESCENCE_CONTROL, HIGH_FITC_CONTROL, HIGH_PE_CONTROL, PROTEASE_CONTROL]

    DEFAULT_TEMPLATES = {
        stability: 'protstab template V1',
        protein_binding: 'binding template V1'
    }

    ########## DEFAULT PARAMS ##########

    # Params that are applied equally to all operations. Can be overridden by
    #   associating a list of key, value pairs to the `Plan`.
    #
    # @example my_plan.associate("options", "{"od_ml_needed": 2.0}")
    def default_plan_params
        {
            experiment_template:                DEFAULT_TEMPLATES[:stability],
            events_to_record:                   30000,
            default_to_sort:                    12E6.to_i,
            facs_model:                         Cytometers::SonySH800S::CYTOMETER_NAME,
            run_calibration_beads:              false,
            library_resuspension_milliliters:   2.0
        }
    end

  ########## MAIN ##########

    def main

        @plan_params = update_plan_params(
            plan_params: default_plan_params,
            opts: get_opts(operations)
        )

        # Takes _microliters and _milliliters keys and generates _vol keys for display purposes.
        @plan_params = add_qty_display(@plan_params)

        @plan = operations.first.plan

        if debug
            @plan.associate(:rounds_complete, 0)
            inspect rounds_complete
        end

        @now_sorting = false
        @tube_ct = 0
        @beads = produce_beads if @plan_params[:run_calibration_beads]

        operations.retrieve.make

        set_test_conditions if debug

        operations.each { |op| txfr_tube_labels(op, INPUT_YEAST, OUTPUT_YEAST) }

        get_facs(@plan_params[:facs_model])

        prepare_materials

        go_to_facs_and_login

        job = get_job

        set_up_instrument(
            experiment_name: "Job_#{job.id}",
            template: @plan_params[:experiment_template],
            events_to_record: @plan_params[:events_to_record],
            target_events: target_events(
                default_to_sort: @plan_params[:default_to_sort],
                frac_positive: 0.1
            ),
            args: { left_gate: sort_gate_name }
        )

        all_samples = collect_samples

        show_debug_table(samples: all_samples) if debug

        run_all(samples: all_samples)

        shutdown

        @plan.associate(:rounds_complete, rounds_complete + 1)

        if debug
            inspect rounds_complete
            operations.each do |op|
                inspect op.output(OUTPUT_YEAST).item.associations
            end
        end

        spin_down_samples

        items_to_delete = operations.map { |op| op.input(INPUT_YEAST).item }
        items_to_delete += operations.reject { |op| sort?(op) }.map { |op| op.output(OUTPUT_YEAST).item }
        items_to_delete.each { |i| i.mark_as_deleted }

        discard_input_samples

        operations.store(interactive: false)

        return {}

    end

    ########## SAMPLE CONTROL FLOW ##########

    def run_all(samples:)
        prev_item = nil

        samples.each do |sample|
            item = sample[:item]
            sort = sample[:sort]
            control = sample[:control]

            tube_label = sample_tube_label(item)
            resuspend_pellet(item) unless item.associations[:resuspended]

            if @now_sorting
                remove_tube_from_sorter(item: prev_item, collection_tube: COLLECTION_TUBE)
                @now_sorting = false
            end

            remove_sample_tube(sample_tube: SAMPLE_TUBE) if @tube_ct > 0
            @tube_ct += 1 unless item.associations[:software_tube_id]
            set_and_run_tube(item: item, tube_label: tube_label, tube_ct: @tube_ct, sort: sort)

            if control
                check_gates(
                    control: control,
                    experiment_template: @plan_params[:experiment_template]
                )
            end

            if sort
                sort_tube(
                    item: item,
                    tube_label: tube_label,
                    default_to_sort: @plan_params[:default_to_sort],
                    gate_name: sort_gate_name,
                    debug: debug
                )
                @now_sorting = true
            end

            mark_as_data_collected(item)
            prev_item = item
        end

        remove_tube_from_sorter(item: prev_item, collection_tube: COLLECTION_TUBE) if @now_sorting
        remove_sample_tube(sample_tube: SAMPLE_TUBE)
    end

    ########## SHOW METHODS ##########

    def prepare_materials

        show do
            title "Gather dry materials"

            # Make this more specific for the Sony.
            note "Put these items in a small box."
            check "#{operations.length} #{SAMPLE_TUBE}."
            warning "You must use #{required_sample_tube}!" if required_sample_tube

            check "A 1000 or 1200 ul pipettor."
            check "A box of blue pipet tips."
        end

        sorted_ops = operations.sort_by { |op| sample_tube_label(op, OUTPUT_YEAST) }.extend(OperationList)

        show do
            title "Gather cold materials"

            note "Pack #{operations.length} tubes containing cell pellets on ice in a bucket or small cooler."
            table sorted_ops.start_table
                .custom_column(heading: "Tube label", checkable: true) { |op| sample_tube_label(op, OUTPUT_YEAST) }
                .end_table

            check "Pack a bottle of #{RESUSPENSION_BUFFER} in the cooler. You will need at least #{operations.length * 4} ml."
        end

        show do
            title "Prepare collection tubes"

            note "Get #{libraries_to_sort.length} #{COLLECTION_TUBE}."
            note "Place the tubes in the ice bucket."
        end

        if @plan_params[:run_calibration_beads]
            show do
                title "Prepare calibration beads"

                note "Take one #{SAMPLE_TUBE} and label it \"#{CALIBRATION_BEADS_LABEL}\"."
                note "Pipet #{qty_display(CALIBRATION_BEAD_VOLUME)} #{RESUSPENSION_BUFFER} into the tube."
                note "Get the #{CALIBRATION_BEADS} from the refrigerator."

                BEAD_CAP_COLORS.each do |color|
                    note "Add <b>two drops</b> from the <b>#{color}</b>-capped tube to the tube."
                end

                note "After adding the beads, vortex the tube for 3 Mississippi."
                note "Add the prepared beads to the cooler."
            end

            mark_as_resuspended(@beads)
        end

    end

    # TODO: Need to make this specific for Sony.
    def resuspend_pellet(item)
        tube_label = sample_tube_label(item)
        resuspension_qty = @plan_params[:library_resuspension_qty]

        show do
            title "Resuspend #{tube_label}"

            note "Take a clean #{SAMPLE_TUBE} and label it as \"#{tube_label}.\""
            note "Remove the cap from the #{SAMPLE_TUBE} and place the tube in the ice bucket."

            note "Take the #{MICROFUGE_TUBE} labeled #{tube_label} from the ice bucket."

            if resuspension_qty[:units] == MILLILITERS && resuspension_qty[:qty] > 1.0
                remainder = resuspension_qty.dup
                remainder[:qty] -= 1.0

                note "Pipet 1.0 #{MILLILITERS} #{RESUSPENSION_BUFFER} into the tube."
                note "Gently pipet the #{RESUSPENSION_BUFFER} up and down until " \
                        "the pellet is fully resuspended."
                note "Pipet the resuspended yeast from the #{MICROFUGE_TUBE} to the #{SAMPLE_TUBE}."
                note "Pipet an additional #{qty_display(remainder)}  " \
                        "#{RESUSPENSION_BUFFER} into the  #{SAMPLE_TUBE}."
            else
                note "Pipet #{qty_display(resuspension_qty)} #{RESUSPENSION_BUFFER} into the tube."
                note "Gently pipet the #{RESUSPENSION_BUFFER} up and down until " \
                        "the pellet is fully resuspended."
                note "Pipet the resuspended yeast from the #{MICROFUGE_TUBE} to the #{SAMPLE_TUBE}."
            end

        end

        mark_as_resuspended(item)
    end

    def spin_down_samples
        show do
            title "Go back to the lab"
            note "Pack up your things and go back to the lab."
            note "Keep the #{COLLECTION_TUBE}s on ice as you travel."
        end

        show do
            title "Centrifuge samples"

            note "Make sure the #{COLLECTION_TUBE}s are balanced by adding #{RESUSPENSION_BUFFER}."
            note "Spin for 5 minutes at 4696 RCF (x g) in a swinging bucket centrifuge."
            note "Using the aspirator with a sterile tip, remove all but the last 100 µl of buffer."
            note "You can discard everything except these collecton tubes."
            warning "Go immediately to the next protocol."
        end
    end

    def check_gates(control:, experiment_template:)
        case control
        when AUTOFLUORESCENCE_CONTROL
            # if experiment_template == DEFAULT_TEMPLATES[:protein_binding]
            #     show do
            #         title 'Adjust the All Events gate'

            #         note "In the All Events (BSC-A vs. FSC-A) plot, move the " \
            #                 "ellipse so that it just includes all of the events in " \
            #                 "lower-left end of the major mass."
            #         # image path_to('all_events')
            #     end
            # end

            show do
                title 'Adjust the lower FITC gate limit'

                note "In the FITC histogram, adjust the lower gate limit so that the percentage is " \
                        "between 0.1 and 0.5."
                image path_to('fitc_autofluorescence')
            end

            if experiment_template == DEFAULT_TEMPLATES[:protein_binding]
                show do
                    title 'Adjust the lower PE gate limit'

                    note "In plot D, move the polygon up or down so that the " \
                            "percentage is between 0.01 and 0.05." \
                    # image path_to('all_events')
                end
            end

        when HIGH_FITC_CONTROL
            show do
                title 'Verify / adjust the upper FITC gate limit'

                note "In the FITC histogram, verify that the upper gate includes the entire " \
                        "right-hand tail of the distribution. Adjust if needed."
                # image path_to('fitc_autofluorescence')
            end
        end
    end

    def discard_input_samples
        show do
            title "Discard Input Samples"

            note "Discard all the #{MICROFUGE_TUBE}s and #{SAMPLE_TUBE}s."
            warning "Keep the #{COLLECTION_TUBE}s that you sorted into in the ice bucket."
        end
    end

    ########## LABELS, GETTERS, AND SIMPLE CALCULATIONS ##########

    def collect_samples
        all_samples = []

        all_samples << { item: @beads } if @plan_params[:run_calibration_beads]

        CONTROL_NAMES.each do |name|
            controls(name).each do |item|
                all_samples << { item: item, control: name }
            end
        end

        other_samples.each do |item|
            all_samples << { item: item }
        end

        libraries_to_sort.each do |item|
            all_samples << { item: item, sort: true }
        end

        all_samples
    end

    def controls(name)
        ops = operations.select { |op| op.input('Control?').val =~ /#{name}/i }
        return [] if ops.blank?
        ops.map { |op| op.output(OUTPUT_YEAST).item }
    end

    def libraries_to_sort
        ops = operations.select { |op| sort?(op) }
        items = ops.map { |op| op.output(OUTPUT_YEAST).item }
        items.partition { |item| item.associations[:resuspended] }.reduce(:+)
    end

    def sort?(op)
        op.input('Sort?').val =~ /yes/i
    end

    def other_samples
        ops = operations.select { |op| op.input('Control?').val =~ /no/i && op.input('Sort?').val =~ /no/i }
        return [] if ops.blank?
        ops.map { |op| op.output(OUTPUT_YEAST).item }
    end

    def produce_beads
        beads = produce(new_sample(CALIBRATION_BEADS, of: "Beads", as: "Diluted beads"))
        beads.associate(:sample_tube_label, CALIBRATION_BEADS_LABEL)
    end

    def mark_as_resuspended(item)
        item.associate(:resuspended, true)
    end

    def mark_as_data_collected(item)
        item.associate(:data_collected, true)
    end

    def rounds_complete
        @plan.associations[:rounds_complete] || 0
    end

    def get_job
        operation_ids = operations.map { |op| op.id }
        ja_ids = JobAssociation.where(operation_id: operation_ids).map { |ja| ja.job_id }.uniq
        possible_jobs = Job.find(ja_ids).select { |j| j.active? }

        if possible_jobs.length > 1
            raise "Cannot resolve the current Job"
        else
            possible_jobs.first
        end
    end

    def get_facs(facs_model)
        case facs_model
        when Cytometers::BDAriaIII::CYTOMETER_NAME
            self.extend Cytometers::BDAriaIII
        when Cytometers::SonySH800S::CYTOMETER_NAME
            self.extend Cytometers::SonySH800S
        else
            raise Cytometers::CytometerInputError.new, "Unrecognized FACS Model: #{facs_model}"
        end
    end

    def sort_gate_name
        # TODO: Need a class or module that handles experiment templates
        case @plan_params[:experiment_template]
        when DEFAULT_TEMPLATES[:protein_binding]
            'PE positive'
        when DEFAULT_TEMPLATES[:stability]
            'FITC positive'
        end
    end

    ########## DEBUG METHODS ##########

    def set_test_conditions
        set_test_labels(operations.map { |op| op.input(INPUT_YEAST).item })
    end

    def show_debug_table(samples:)
        debug_table = [["Item", "Label", "Control?", "Sort?"]]
        samples.each do |s|
            debug_table << [s[:item].to_s, sample_tube_label(s[:item]), s[:control], s[:sort]]
        end
        show do
            table debug_table
        end
    end

end