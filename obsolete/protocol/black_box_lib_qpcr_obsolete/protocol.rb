# Black box for library qPCR1
needs "Standard Libs/SortHelper" # for sorting ops by program

class Protocol
    
    # I/O
    IN="Library stock"
    OUT="Library qPCR1"
    
    include SortHelper # for sorting ops by input program 

    def main
    
        # sort ops
        ops_sorted=sortByMultipleIO(operations, ["in"], [IN], ["id"], ["io"]) 
        operations=ops_sorted
        operations.make
    
        show do 
          title "I/O map"
          table operations.start_table
            .input_item(IN)
            .output_item(OUT)
            .end_table
        end
        
        return {}
    
    end

end
 