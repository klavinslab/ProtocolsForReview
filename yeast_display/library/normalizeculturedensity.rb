needs "Yeast Display/YeastDisplayHelper"

module NormalizeCultureDensity

    include YeastDisplayHelper

    TUBE_50_ML_CONICAL = "50 ml conical tube"
    TUBE_15_ML_CONICAL = "15 ml conical tube"
    TUBE_MICROFUGE = "1.5 ml microfuge tube"

    # Check culture densities, then aliquot and resuspend specified number of cells
    #
    # @param args [Hash]
    # @option args [String] :input_handle  the `Name` of the culture `Input` of the `Operation`
    # @option args [String] :output_handle  the `Name` of the resuspended culture `Output` of the `Operation`
    # @option args [Numeric] :od_ml_needed  the number of cells in each aliquot, as OD*ml
    # @option args [Hash] :temp (YeastDisplayHelper::ROOM_TEMP)  info about the temperature,
    #   usually passed as a constant from `YeastDisplayHelper`
    # @option args [Hash] :resuspend_qty  the volume to resuspend the yeast in
    # @option args [Boolean] :debug (false)  set realistic ODs for testing
    # @return [OperationList] a subset of the `Job Operations` with unique input culture
    def normalize_culture_density(args)

        args = normalize_defaults.update(args)

        input_handle = args[:input_handle]

        normalize_reqd_args.each do |ra|
            unless args[ra]
                raise NormalizeCultureDensityInputError.new(
                    "Required argument :#{ra} not found."
                )
            end
        end

        unique_culture_operations = operations.uniq { |op| op.input(input_handle).item }.extend(OperationList)

        measure_culture_ods(unique_culture_operations)

        unique_culture_operations.each { |op| op.input(input_handle).item.associate(:od, op.temporary[:od]) }

        set_test_ods if args[:debug]

        max_volume = unique_culture_operations.map { |op|library_culture_volume(op, args) }.max

        ops_by_culture_item = operations.group_by { |op| op.input(input_handle).item }

        show do
            title 'Aliquot library cultures'
            note temp_instructions(args[:temp])

            note "You will need #{operations.length} #{destination_tube(max_volume)}s."

            note LABEL_TUBES_FROM_TABLE

            ops_by_culture_item.each do |culture_item, ops|
                note "<b>#{input_handle} Item ID #{culture_item.id}</b>"
                table ops.extend(OperationList).start_table
                    .custom_column(heading: "Label") { |op| sample_tube_label(op, args[:output_handle]) }
                    .custom_column(heading: "Culture (#{MICROLITERS})", checkable: true) { |op| library_culture_volume(op, args) }
                    .end_table
                note " "
            end

            warning 'Balance the tubes with sterile PBS' unless destination_tube(max_volume) == TUBE_MICROFUGE
            note 'Spin 1 min at 5000 x g in a <b>room temperature</b> centrifuge, and aspirate off all the media.'
        end

        resuspend_units = args[:resuspend_qty][:units]
        resuspend_vol = args[:resuspend_qty][:qty].to_s

        ops_by_buffer = operations.group_by { |op| resuspension_buffer(op, args[:buffer_handle]) }

        show do
            title 'Resuspend yeast library cultures'
            note temp_instructions(args[:temp])

            ops_by_buffer.each do |bfr, ops|
                note "<b>#{bfr}</b>"
                table ops.extend(OperationList).start_table
                    .custom_column(heading: "Label") { |op| sample_tube_label(op, args[:output_handle]) }
                    .custom_column(heading: "Vol (#{resuspend_units})", checkable: true) { |op| resuspend_vol }
                    .end_table
                note " "
            end

            note VORTEX_CELLS
        end

        unique_culture_operations
    end

    def resuspension_buffer(op, handle)
        input = op.input(handle)

        if op.temporary[:modified_buffer].present?
            op.temporary[:modified_buffer]
        elsif input.value.present?
            input.value
        elsif input.sample.present?
            input.sample.name
        else
            'not found'
        end
    end

    def normalize_reqd_args
        [:input_handle, :output_handle, :od_ml_needed, :resuspend_qty, :buffer_handle]
    end

    def normalize_defaults
        {
            temp: ROOM_TEMP,
            debug: false
        }
    end

    # Calculate the volume of culture to take based on the OD and the OD*ml needed
    #
    # @param op [Operation]
    # @param [Hash] args
    # @option args [String] :input_handle  the `Name` of the culture `Input` of the `Operation`
    # @option args [Numeric] :od_ml_needed  the number of cells in each aliquot, as OD*ml
    # @return [Numeric] the volume of culture to take, in `MICROLITERS`
    def library_culture_volume(op, args)
        (1000 * args[:od_ml_needed] / (op.input(args[:input_handle]).item.associations[:od] * 10)).round
    end

    def destination_tube(volume)
        if volume > 15000
            return TUBE_50_ML_CONICAL
        elsif volume > 1500
            return TUBE_15_ML_CONICAL
        else
            return TUBE_MICROFUGE
        end
    end

    class NormalizeCultureDensityInputError < StandardError; end

end