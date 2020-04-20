# @author Devin Strickland
# @email dvn.strcklnd@gmail.com

needs "Yeast Display/FastMixAndQuench"
needs "Yeast Display/WashYeast"
needs "Yeast Display/NormalizeCultureDensity"
needs "Yeast Display/PrepareTreatmentDilutions"
needs "Yeast Display/LabelWithAntibody"

needs "Yeast Display/ChallengeAndLabelHelper"

class Protocol

    require 'json'

    include FastMixAndQuench, WashYeast, NormalizeCultureDensity, PrepareTreatmentDilutions, LabelWithAntibody
    include ChallengeAndLabelHelper

    attr_accessor :plan_params

    MY_DEBUG = true

    ########## DEFAULT PARAMS ##########

    # Params that are applied equally to all operations. Can be overridden by
    #   associating a list of key, value pairs to the `Plan`.
    #
    # @example my_plan.associate("options", "{"od_ml_needed": 2.0}")
    # @note `:od_ml_needed` should not exceed `3.0`
    # @note `:quench_milliliters`, `:wash_milliliters` should not exceed `1000`
    # @note If `:incubate_with_protease` is `false`, then the protease incubation steps
    #   will be skipped, but `:n_protease_washes` washes will still be performed
    # @note If `:incubate_with_antibody` is `false`, then the antibody incubation steps
    #   will be skipped, but `:n_antibody_washes` washes will still be performed
    def default_plan_params
        {
            make_extra_reagent: 1.1,                # Multiplier to make extra master mix for pipetting error
            od_ml_needed: 2.5,                      # The number of ml of an OD = 1.0 culture, 1.0 = 1.2E7 cells
            assay_microliters: 500,                 # Total volume after protease is added
            protease_dilution_factor: 2.0,          # Protease sample is diluted when mixed with the culture
            protease_working_microliters: 1000,     # How much of each protease sample gets made
            protease_incubation_time_minutes: 5,    # How long the protease incubation is allowed to proceed
            vortex_interval_minutes: 2,             # How often the protease incubation is vortexed
            quench_milliliters: 1.0,                # The volume used to quench the protease reaction
            wash_milliliters: 1.0,                  # The volume used in each protease or antibody wash
            n_protease_washes: 4,                   # The number of times to wash after protease treatment
            antibody_dilution_factor: 100.0,        # The amount that the antibody gets diluted by
            n_antibody_washes: 2,                   # The number of times to wash after antibody treatment
            antibody_microliters_per_od_ml: 200,    # The volume of diluted antibody, scales with # of cells
            incubate_with_protease: true,           # Skips incubation but NOT washes if false
            quench_protease: true,                  # Skips quench step but NOT washes if true
            incubate_with_antibody: true,           # Skips incubation AND washes if false
            pretreatment_item_id: nil,
            pretreatment_incubation_time_minutes: nil,
            pretreatment_dilution_factor: nil
        }
    end

    ########## MAIN ##########

    def main

        # Setup that runs in the background
        # These methods should only call show blocks in debug mode

        override_input_operations if debug && MY_DEBUG

        @plan_params = default_plan_params

        update_plan_params

        calculate_volumes

        sort_operations

        operations.make

        find_and_add_buffers

        associate_tube_labels

        calculate_and_set_protease_volumes

        # Technician display methods begin here

        prepare_equipment

        gather_buffers_and_proteases

        prepare_pretreatment if @plan_params[:pretreatment_item_id]

        prepare_culture_samples

        incubate_with_pretreatment if @plan_params[:pretreatment_item_id]

        if @plan_params[:incubate_with_protease]
            prepare_protease_dilutions
            incubate_with_protease
        end

        if @plan_params[:n_protease_washes] > 0
            wash_out_protease
        end

        if @plan_params[:incubate_with_antibody]
            label_with_antibody
        end

        if @plan_params[:n_antibody_washes] > 0
            wash_out_antibody
        end

        clean_up

        return {}

    end

    def prepare_pretreatment
        pretreatment_item = Item.find(@plan_params[:pretreatment_item_id])

        operations.each { |op| add_input_from_item(op, PRETREATMENT, pretreatment_item) }

        final_dilution_factor = @plan_params[:assay_qty][:qty] / @plan_params[:library_qty][:qty]
        working_dilution_factor = @plan_params[:pretreatment_dilution_factor] / final_dilution_factor

        total_per_rxn = @plan_params[:library_qty][:qty] * @plan_params[:make_extra_reagent]

        stock_per_rxn = {
            qty: total_per_rxn / working_dilution_factor,
            units: @plan_params[:assay_qty][:units]
        }

        buffer_per_rxn = {
            qty: total_per_rxn - stock_per_rxn[:qty],
            units: @plan_params[:assay_qty][:units]
        }

        prepare_reagent(
            stock_per_rxn: stock_per_rxn,
            buffer_per_rxn: buffer_per_rxn,
            reagent_name: pretreatment_item.sample.name,
            reagent_handle: PRETREATMENT,
            buffer_handle: INCUBATION_BUFFER,
            temp: ROOM_TEMP,
            debug: debug && MY_DEBUG
        )
    end

    def incubate_with_pretreatment
        incubation_time = @plan_params[:pretreatment_incubation_time_minutes]
        incubation_time = "#{incubation_time} #{MINUTES}"
        show do
            title "Incubate Resuspended Cultures"

            note "Incubate the resuspended library cultures for #{incubation_time}."
        end
    end

    ########## DISPLAY METHODS WITH DEDICATED MODULES ##########

    # Retrieve the cultures, measure the ODs, centrifuge and resuspend in the appropriate volume.
    #
    def prepare_culture_samples

        operations.retrieve(only: INPUT_YEAST)

        unique_culture_operations = normalize_culture_density(
            input_handle: INPUT_YEAST,
            output_handle: OUTPUT_YEAST,
            buffer_handle: INCUBATION_BUFFER,
            temp: ROOM_TEMP,
            resuspend_qty: @plan_params[:library_qty],
            od_ml_needed: @plan_params[:od_ml_needed],
            debug: debug && MY_DEBUG
        )

        uc_items = unique_culture_operations.map { |op| op.input(INPUT_YEAST).item }

        mark_cultures_for_discard(uc_items)

        release(uc_items, interactive: true)

    end

    def prepare_protease_dilutions
        prepare_treatment_dilutions(
            treatment_handle: PROTEASE,
            buffer_handle: INCUBATION_BUFFER,
            output_handle: OUTPUT_YEAST,
            treatment_working_qty: @plan_params[:protease_working_qty],
            temp: ROOM_TEMP
        )
    end

    def incubate_with_protease
        grouped_ops = ops_by_inc_bfr

        arrange_tubes(
            grouped_ops: grouped_ops,
            output_handle: OUTPUT_YEAST,
            temp: ROOM_TEMP
        )

        mix_samples(
            grouped_ops: grouped_ops,
            treatment_vol: @plan_params[:protease_qty]
        )

        incubate(
            grouped_ops: grouped_ops,
            output_handle: OUTPUT_YEAST,
            incubation_time: @plan_params[:protease_incubation_time_qty],
            vortex_interval: @plan_params[:vortex_interval_qty],
            quench_vol: @plan_params[:quench_qty],
            buffer_handle: QUENCH_BUFFER,
            quench_protease: @plan_params[:quench_protease]
        )
    end

    def wash_out_protease
        buffer_handle = @plan_params[:quench_protease] ? QUENCH_BUFFER : INCUBATION_BUFFER
        wash_yeast(
            grouped_ops: ops_by_inc_bfr,
            n_washes: @plan_params[:n_protease_washes],
            wash_vol: @plan_params[:wash_qty],
            output_handle: OUTPUT_YEAST,
            buffer_handle: buffer_handle,
            temp: ON_ICE
        )
    end

    def label_with_antibody
        prepare_reagent(
            stock_per_rxn: @plan_params[:antibody_stock_per_rxn],
            buffer_per_rxn: @plan_params[:antibody_buffer_per_rxn],
            reagent_name: 'antibody',
            reagent_handle: ANTIBODY,
            buffer_handle: BINDING_BUFFER,
            debug: debug && MY_DEBUG
        )

        incubate_with_antibody(
            antibody_qty: @plan_params[:antibody_qty]
        )
    end

    def wash_out_antibody
        wash_yeast(
            grouped_ops: ops_by_binding_bfr,
            n_washes: @plan_params[:n_antibody_washes],
            wash_vol: @plan_params[:wash_qty],
            output_handle: OUTPUT_YEAST,
            buffer_handle: BINDING_BUFFER,
            temp: ON_ICE
        )
    end

    ########## DATA PROCESSING METHODS ##########

    # Gets :options from the plan associations and uses it to override @plan_params defaults.
    #
    # @note Modifies @plan_params, an instance variable of the Protocol.
    def update_plan_params
        opts = operations.first.plan.associations[:options]

        if opts.present?
            opts = JSON.parse(opts, { symbolize_names: true })
            plan_params.update(opts)
        end

        if debug && MY_DEBUG
            associate_plan_options(plan_params)
        end
    end

    # Calculates volume @plan_params and formats them for display purposes.
    #
    # @note Modifies @plan_params, an instance variable of the Protocol.
    def calculate_volumes
        # TODO: Think about whether this is the right priority for these params being defined
        # Devin removed this calculation because it results in too much culture volume. No longer
        # automatically scaling reaction volume with OD*ml
        # assay_microliters = @plan_params[:assay_microliters_per_od_ml] * @plan_params[:od_ml_needed]
        # @plan_params[:assay_microliters] = assay_microliters

        @plan_params[:protease_microliters] = @plan_params[:assay_microliters] / @plan_params[:protease_dilution_factor]
        @plan_params[:library_microliters] = @plan_params[:assay_microliters] - @plan_params[:protease_microliters]
        @plan_params[:antibody_microliters] = @plan_params[:antibody_microliters_per_od_ml] * @plan_params[:od_ml_needed]

        # Takes _microliters and _milliliters keys and generates _vol keys for display purposes.
        @plan_params = add_qty_display(@plan_params)

        @plan_params[:antibody_stock_per_rxn] = {
            qty: @plan_params[:antibody_qty][:qty] / @plan_params[:antibody_dilution_factor],
            units: @plan_params[:antibody_qty][:units]
        }

        @plan_params[:antibody_buffer_per_rxn] = {
            qty: @plan_params[:antibody_qty][:qty] - @plan_params[:antibody_stock_per_rxn][:qty],
            units: @plan_params[:antibody_qty][:units]
        }

        @plan_params[:antibody_stock_per_rxn][:qty] *= @plan_params[:make_extra_reagent]
        @plan_params[:antibody_buffer_per_rxn][:qty] *= @plan_params[:make_extra_reagent]

        @plan_params
    end

    # Loops over the operations and calls a method to find and add buffers.
    #
    def find_and_add_buffers
        operations.each do |op|
            protease = op.input(PROTEASE).sample
            add_buffers(op, protease, INCUBATION_BUFFER)
            add_buffers(op, protease, QUENCH_BUFFER)

            antibody = op.input(ANTIBODY).sample
            add_buffers(op, antibody, BINDING_BUFFER)
        end
    end

    # Figures out which buffers are needed and adds them to the passed operation.
    #
    def add_buffers(op, reagent, handle)
        sample_id = reagent.properties["#{handle} id"]

        if sample_id
            buffer = Sample.find(sample_id)
        else
            buffer = reagent.properties["#{handle}"]
        end

        return unless buffer
        container = buffer_container(buffer: buffer, handle: handle)
        item = op.add_input(handle, buffer, container)
    end

    # Calculates and sets operation-specific protease volumes based on the activities of the stocks.
    #
    def calculate_and_set_protease_volumes
        protease_samples.each do |protease|
            protease_ops = operations.select { |op| op.input(PROTEASE).sample == protease }
            stock_conc = stock_concentration(ops: protease_ops)
            protease_ops.each { |op| set_protease_volumes(op, stock_conc) }
        end
    end

    def stock_concentration(ops: protease_ops)
        concs = ops.map { |op| op.input(PROTEASE).item.get(:units_per_milliliter) }.uniq
        raise 'Protease activity error.' unless concs.length == 1
        concs.first.to_i
    end

    def protease_ops(protease)
        operations.select { |op| op.input(PROTEASE).sample == protease }
    end

    # Sets protease and buffer volumes for the passed operation.
    #
    # @param op [Operation] the operation that the columes are set for
    # @param stock_conc [Numeric] the activity of the protease stock
    def set_protease_volumes(op, stock_conc)
        this_conc = protease_conc(op) * @plan_params[:protease_dilution_factor]
        prot_vol = @plan_params[:protease_working_qty][:qty] * this_conc / stock_conc
        buf_vol = @plan_params[:protease_working_qty][:qty] - prot_vol
        op.temporary[:treatment_qty] = prot_vol
        op.temporary[:buffer_qty] = buf_vol
    end

    # Assigns an incremental tube number for each yeast culture and protease.
    # Overrides the `associate_tube_labels` in the `TemporaryTubeLabels` module.
    def associate_tube_labels
        operations.each_with_index do |op, i|
            op.output(OUTPUT_YEAST).item.associate(:sample_tube_label, "S#{i + 1}")
            op.output(OUTPUT_YEAST).item.associate(:treatment_tube_label, "T#{i + 1}")
        end

        # check_labels if debug
    end

end