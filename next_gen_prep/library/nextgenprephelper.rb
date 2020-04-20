
needs "Standard Libs/Units"

module NextGenPrepHelper

    include Units

    LONG_SPIN = { qty: 5, units: MINUTES }
    LONG_SPIN_EXTRACT_PLASMID = { qty: 10, units: MINUTES }
    SHORT_SPIN = { qty: 1, units: MINUTES }

    PB = "binding buffer PB"
    PB_VOL = { qty: 700, units: MICROLITERS }
    PB_WASHES = 1

    PE = "wash buffer PE"
    PE_VOL = { qty: 700, units: MICROLITERS }
    PE_WASHES = 2

    EB = "elution buffer EB"
    EB_VOL = { qty: 30, units: MICROLITERS }

    COLUMN = "<b>blue</b> Qiagen miniprep column"
    MICROFUGE_TUBE = "1.5 #{MILLILITERS} microfuge tube"

    CENTRIFUGE_SPEED = "17,000 #{TIMES_G}"

    CENTRIFUGE = "Centrifuge samples at <b>#{CENTRIFUGE_SPEED}</b> for <b>%s</b>"
    ADD_BUFFER = "Add <b>%s</b> of <b>%s</b> to each column"


    def assign_tube_numbers(in_handle, out_handle)
        operations.sort_by! { |op| op.input(in_handle).item.id }

        operations.each_with_index do |op, i|
            op.input(in_handle).item.associate(:tube_number, "#{i + 1}")
            txfr_tube_numbers(op, in_handle, out_handle)
        end
    end

    def number_tubes_and_columns
        show do
            title "Number tubes and columns"

            note "Get #{operations.length} #{COLUMN}s with collection tubes"
            note "Number each set 1 - #{operations.length}"
        end
    end

    def wash_samples(pb_washes=PB_WASHES, pe_washes=PE_WASHES)
        show do
            title "Wash samples"

            pb_washes.times do |i|
                check CENTRIFUGE % qty_display(SHORT_SPIN)
                check "Aspirate the flow-through out of each collection tube"
                check ADD_BUFFER % [qty_display(PB_VOL), PB]
            end

            pe_washes.times do |i|
                check CENTRIFUGE % qty_display(SHORT_SPIN)
                check "Aspirate the flow-through out of each collection tube"
                check ADD_BUFFER % [qty_display(PE_VOL), PE]
            end
        end
    end

    def elute_samples(out_handle)
        show do
            title "Centrifuge 2X to remove residual buffer"

            check CENTRIFUGE % qty_display(SHORT_SPIN)
            check "Aspirate the flow-through out of each collection tube"
            check CENTRIFUGE % qty_display(SHORT_SPIN) + " to remove any residual buffer"

            check "While you wait, get #{operations.length} #{MICROFUGE_TUBE}s and label them with the numbers in the table"
            check "Carefully transfer each column to the corresponding #{MICROFUGE_TUBE}"

            table operations.start_table
                .custom_column(heading: "Column number") { |op| op.output(out_handle).item.associations[:tube_number] }
                .custom_column(heading: "Microfuge tube number", checkable: true) { |op| op.output(out_handle).item.id }
                .end_table
        end

        show do
            title "Elute DNA"

            check ADD_BUFFER % [qty_display(EB_VOL), EB]
            check "Wait 1 #{MINUTES}"
            check CENTRIFUGE % qty_display(SHORT_SPIN)

            check "Reload the eluted volume of each sample on its column"
            check "Wait 1 #{MINUTES}"
            check CENTRIFUGE % qty_display(SHORT_SPIN)

            check "Throw away the #{COLUMN}s and close the caps to the #{MICROFUGE_TUBE}s"
        end
    end

    def txfr_tube_numbers(op, in_handle, out_handle)
        op.output(out_handle).item.associate :tube_number, op.input(in_handle).item.associations[:tube_number]
    end

    def expanded_volume_display(qty, volume_factor, precision=0)
        total_qty = (qty[:qty] * volume_factor).round(precision)
        "#{total_qty} #{qty[:units]}"
    end

    def txfr_bin(op, in_handle, out_handle)
        txfr_association(op, in_handle, out_handle, :bin)
    end

    def txfr_barcode(op, in_handle, out_handle)
        txfr_association(op, in_handle, out_handle, :barcode)
    end

    def txfr_association(op, in_handle, out_handle, key)
        input_item = part_or_item(op.input(in_handle))
        output_item = part_or_item(op.output(out_handle))
        data = input_item.get(key)
        output_item.associate(key, data) if data
    end

    def part_or_item(field_value)
        field_value.part? ? field_value.part : field_value.item
    end

    def associate_random_barcodes(operations:, in_handle:)
        operations.each do |op|
            item = part_or_item(op.input(in_handle))
            item.associate(:barcode, Array.new(6) { |i| %w(C A T G).sample }.join)
        end
    end

    def display_barcode_associations(operations:, in_handle:, out_handle: nil)
        out_handle ||= in_handle
        show do
            table operations.start_table
                .custom_column(heading: "input item") { |op| part_or_item(op.input(in_handle)).to_s }
                .custom_column(heading: "input bc") { |op| part_or_item(op.input(in_handle)).get(:barcode) }
                .custom_column(heading: "output bc") { |op| part_or_item(op.output(out_handle)).get(:barcode) }
                .end_table
        end
    end

end