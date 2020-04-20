needs 'Standard Libs/CommonInputOutputNames'
needs "Standard Libs/Units"
needs "Standard Libs/TemporaryTubeLabels"
needs "Yeast Display/YeastDisplayShows"

module YeastDisplayHelper

    include CommonInputOutputNames, Units, TemporaryTubeLabels
    include YeastDisplayShows

    ADD_WASH_BUFFER = "Add %{qty} %{units} of chilled quench buffer to each tube according to the table."
    VORTEX_CELLS = 'After adding buffer, vortex each tube for 3 pulses.'
    SPIN_CELLS = 'Spin 1 min at 5000 x g in a 4 °C microcentrifuge.'
    REMOVE_BUFFER = 'Aspirate off the buffer without disturbing the cell pellet.'
    LABEL_TUBES_FROM_TABLE = 'Label the tubes and add the reagent volumes as indicated'

    ROOM_TEMP = { style: 'bg-color: lightorange', temp: 'AT ROOM TEMPERATURE' }
    ON_ICE = { style: 'bg-color: powderblue', temp: 'ON ICE' }

    INCUBATOR = "30 °C shaker incubator"

    def prepare_media_and_dilute(container, container_group, protocol=:yeast_display)
        container_group.extend(OperationList)

        language = container_specific_language(protocol, container)

        if container == "Labeled Yeast Library Suspension"
            get_media(container_group)
        else
            prepare_media(container_group, language)
        end

        innoculate_flasks(container_group, language)
    end

    def group_ops_by_container
        ops_by_container = operations.group_by { |op| container_name(op) }
        ops_by_container.each_value { |ops_group| ops_group.extend(OperationList) }
        ops_by_container
    end

    def container_name(op, handle=INPUT_YEAST)
        op.input(handle).object_type.name
    end

    def media_volume(op, handle=INPUT_YEAST)
        op.input(handle).item.associations[:media_vol]
    end

    def transfer_volume(op, handle=INPUT_YEAST)
        op.input(handle).item.associations[:txfr_vol]
    end

    def temp_instructions(substitutions)
        "<span style=\"%{style}\">KEEP TUBES AND BUFFERS <b>%{temp}</b></span>" % substitutions
    end

    def materials_prep_temp(substitutions)
        "<span style=\"%{style}\">These materials should be placed <b>%{temp}</b></span>" % substitutions
    end

    def set_unique_items(handle)
        donor = operations.first.input(handle)
        operations.each { |op| op.input(handle).set( { item: donor.item }) }
    end

    def container_specific_language(protocol, container)
        case protocol

        when :yeast_display
            yeast_display_containers(container)

        when :library_transformation
            library_transformation_containers(container)

        else
            raise "Unrecognized Protocol: #{protocol}."

        end
    end

    def yeast_display_containers(container)
        case container

        when "Yeast Library Glycerol Stock"
            {
                flask_type: '250 ml baffled flask',
                media_volume: '50 ml',
                passage_amount: 'Pipette the entire glycerol stock of each input %{input_type} into the corresponding flask.'
            }

        when "Labeled Yeast Library Suspension"
            {
                flask_type: '15 ml culture tube',
                media_volume: '5 ml',
                passage_amount: 'Using a new 5 ml serological pipette for each sample, pipette %{media_volume} of media into each collection tube, pipette up and down a few times, then transfer to the corresponding culture tube.'
            }

        when "Yeast Library Liquid Culture", "Yeast 5ml culture", "Yeast 50ml culture"
            {
                flask_type: '250 ml baffled flask',
                media_volume: '50 ml',
                passage_amount: 'Pipette 1 ml of each input %{input_type} into the corresponding flask.'
            }

        when "Yeast Plate", "Divided Yeast Plate"
            {
                flask_type: '15 ml culture tube',
                media_volume: '5 ml',
                passage_amount: 'Pick 1 colony of each input %{input_type} into the corresponding flask.'
            }

        else
            raise "Unrecognized Container for Item in #{container}"

        end
    end

    def library_transformation_containers(container)
        case container

        when "Yeast Plate", "Divided Yeast Plate"
            {
                flask_type: '250 ml baffled flask',
                media_volume: '50 ml',
                passage_amount: 'Pick 1 colony of each input %{input_type} into the corresponding flask.'
            }

        when 'Yeast 50ml culture'
            {
                flask_type: '500 mL baffled flask',
                media_volume: 'the indicated amount',
                passage_amount: 'Pipette the indicated volume of each input %{input_type} into the corresponding flask.'
            }

        when '8 ml High Efficiency Transformation'
            {
                flask_type: '500 ml baffled flask',
                media_volume: '92 ml',
                passage_amount: 'Pipette the entire 8 ml of each input %{input_type} into the corresponding flask.'
            }

        else
            raise "Unrecognized Container for Item in #{container}"

        end
    end

    def mark_cultures_for_discard(culture_items)
        culture_items.each { |item| item.move_to('Culture discard area') }

        ids = culture_items.map { |item| item.to_s }
        discard_date = (Date.today + 2).strftime("%-m/%-d/%y")

        show do
            title "Label cultures with discard date"

            note "Label each of the cultures #{ids.to_sentence} with \"DISCARD ON #{discard_date}\""
        end
    end

    def return_to_incubator
        operations.each { |op| op.output(OUTPUT_YEAST).item.update_attributes(location: INCUBATOR) }
    end

    # Generates table for adding quench buffer to samples.
    #
    # @param ops [OperationList] usually a subset of the operations
    # def quench_buffer_table(ops, output_handle)
    #     ops.start_table
    #         .custom_column(heading: "Yeast library") { |op| library_tube_label(op, output_handle) }
    #         .custom_column(heading: "Buffer") { |op| quench_buffer(op)[:label] }
    #         .end_table
    # end

    # Generates a table for adding wash buffer to the samples.
    #
    def wash_buffer_table(ops, args)
        ops.start_table
            .custom_column(heading: "Sample") { |op| sample_tube_label(op, args[:output_handle]) }
            .custom_column(heading: "Wash Buffer") { |op| op.input(args[:buffer_handle]).sample.name }
            .end_table
    end

    # Retrieve the antibody and dilute it to the appropriate concentration.
    #
    def prepare_reagent(args)
        reagent_name = args[:reagent_name]
        reagent_handle = args[:reagent_handle]
        buffer_handle = args[:buffer_handle]
        stock_per_rxn = args[:stock_per_rxn]
        buffer_per_rxn = args[:buffer_per_rxn]
        temperature = args[:temp] || ON_ICE

        set_unique_items(reagent_handle) if args[:debug]

        operations.retrieve(only: reagent_handle)

        operations.each do |op|
            op.temporary[:modified_buffer] = reagent_label(op, reagent_handle, buffer_handle)
        end

        ops_by_combo = operations.group_by { |op| op.temporary[:modified_buffer] }

        # h1 = "#{reagent_name.sub(/^./, &:upcase)} volume (#{MICROLITERS})"
        # h2 = "Buffer"
        # h3 = "Buffer volume (#{MICROLITERS})"
        # h4 = "Tube label"

        reagent_table = [[
            "#{reagent_name.sub(/^./, &:upcase)}",
            "Volume (#{MICROLITERS})",
            "Buffer",
            "Volume (#{MICROLITERS})",
            "Tube label"
        ]]

        ops_by_combo.each do |combo, ops|
            op = ops[0]
            row = [
                op.input(reagent_handle).item.to_s,
                { content: total_vol(stock_per_rxn, ops.length), check: true },
                op.input(buffer_handle).sample.name,
                { content: total_vol(buffer_per_rxn, ops.length), check: true },
                op.temporary[:modified_buffer]
            ]
            reagent_table.append(row)
        end

        show do
            # TODO Need to calculate the volume for volumes over 1000 ul
            title "Prepare #{reagent_name} dilutions"
            note temp_instructions(temperature)

            note "Dilute the #{ops_by_combo.length > 1 ? reagent_name.pluralize : reagent_name} with buffer according to the table"
            note "Label the tube(s) according to the table"
            table reagent_table
        end

        uniq_items = operations.map { |op| op.input(reagent_handle).item }.uniq
        release(uniq_items, interactive: true)
    end

    def total_vol(vol_per_rxn, n_rxns)
        (vol_per_rxn[:qty] * n_rxns).round
    end

    def reagent_label(op, reagent_handle, buffer_handle)
        reagent_name = op.input(reagent_handle).try(:sample).try(:name) || "unknown"
        buffer_name = op.input(buffer_handle).try(:sample).try(:name) || "unknown"
        "#{reagent_name} in #{buffer_name}"
    end

    def add_input_from_item(op, name, item)
        ft = FieldType.new(
            name: name,
            ftype: "sample",
            parent_class: "OperationType",
            parent_id: nil
        )
        ft.save

        fv = FieldValue.new(
            name: name,
            child_item_id: item.id,
            child_sample_id: item.sample.id,
            role: 'input',
            parent_class: "Operation",
            parent_id: op.id,
            field_type_id: ft.id
        )
        fv.save
    end

    ########## DEBUG METHODS ##########

    def set_test_labels(items)
        items.each_with_index do |item, i|
            item.associate(:sample_tube_label, "S#{i+1}")
        end
    end

    def set_test_ods(items=[])
        items = operations.map { |op| op.input(INPUT_YEAST).item } unless items.present?
        items.uniq.each { |item| item.associate(:od, (2.0 + 3*Random.rand) / 10) }
    end

end