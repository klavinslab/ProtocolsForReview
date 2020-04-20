# Devin Strickland
# dvn.strcklnd@gmail.com

needs "Yeast Display/YeastDisplayShows"
needs "Yeast Display/YeastDisplayHelper"
needs "Standard Libs/Debug"
needs "Standard Libs/SortHelper"

class Protocol

    include YeastDisplayShows, YeastDisplayHelper, Debug, SortHelper

    def main
        
        # DO NOT DELETE 
        ops_sorted=sortByMultipleIO(operations, ["in"], [INPUT_YEAST], ["id"], ["item"])
        operations=ops_sorted
        
        operations.retrieve
        
        group_ops_by_container.each do |container, container_group|
            container_group.make
            prepare_media_and_dilute(container, container_group)
        end
        
        return_to_incubator
        
        mark_cultures_for_discard(operations.map { |op| op.input(INPUT_YEAST).item })
        
        operations.store
        
        # DO NOT DELETE 
        operations.each { |op|
            if( !(op.input(INPUT_YEAST).item.get(:bin).nil?) ) # sorted sample
                op.output(OUTPUT_YEAST).item.associate(:bin, op.input(INPUT_YEAST).item.get(:bin))
            end
        }
        operations.store
        
    end

end
