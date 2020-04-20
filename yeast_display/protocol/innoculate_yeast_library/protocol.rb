# Devin Strickland
# dvn.strcklnd@gmail.com

needs "Yeast Display/YeastDisplayShows"
needs "Yeast Display/YeastDisplayHelper"
needs "Standard Libs/SortHelper"

class Protocol

    include YeastDisplayShows, YeastDisplayHelper, SortHelper

    INPUT_YEAST = 'Yeast Culture'

    def main

        # DO NOT DELETE SORT BY ID
        ops_sorted=sortByMultipleIO(operations, ["in"], [INPUT_YEAST], ["id"], ["item"])
        operations=ops_sorted

        set_test_labels(operations.map { |op| op.input(INPUT_YEAST).item }) if debug

        group_ops_by_container.each do |container, container_group|
            container_group.retrieve.make
            prepare_media_and_dilute(container, container_group)
        end

        return_to_incubator

        input_items = operations.map { |op| op.input(INPUT_YEAST).item }

        discards = input_items.reject { |i| i.object_type.name =~ /(plate|glycerol)/i }

        mark_cultures_for_discard(discards)

        glycerol_stocks = input_items.select { |i| i.object_type.name =~ /(Yeast Library Glycerol Stock)/i }
        glycerol_stocks.map { |i| i.mark_as_deleted }

        show do
            title "Throw Away Glycerol Stocks"

            note "Throw away all the <b>empty</b> glycerol stocks (#{glycerol_stocks.map { |i| i.to_s }.to_sentence})."
        end

        operations.store

        # DO NOT DELETE
        operations.each { |op|
            if( !(op.input(INPUT_YEAST).item.get(:bin).nil?) ) # sorted sample
                op.output(OUTPUT_YEAST).item.associate(:bin, op.input(INPUT_YEAST).item.get(:bin))
            end
        }

        # library glycerol stocks need to be deleted
    end

end