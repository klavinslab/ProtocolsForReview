needs "Standard Libs/Debug"

class Protocol

include Debug

  def main

    operations.retrieve.make
    
    if operations.length > 12
        raise "maximum batch of 12 operations"
    end

    
    # output_collections = []
    # output_collections.push produce(new_collection "Stripwell")
    show do 
        title "Label output stripwell"
        note "Get a fresh stripwell and label it #{operations.first.output("Fragment").collection.id}"
    end

    
    
    fragment_well = 0 
    
    
    operations.each do |op|
        # if fragment_well == 12
        #     fragment_well = 1
        #     output_collections.push produce(new_collection "Stripwell")
        #     show do 
        #         title "Label output stripwell"
        #         note "Get a fresh stripwell and label it #{output_collections.last}"
        #     end
        # else
            fragment_well += 1
        # end
        
     
        
        transfer_table = [["Input Stripwell", "Input Well Index", "Output Stripwell", "Output Well Index"]]
        op.input_array("Strain").each do |input|
            transfer_table.push [input.collection.id, input.column + 1, op.output("Fragment").collection.id, { content: fragment_well, check: true }]
        end
        
        op.input_array("Strain").each do |input|
            input.collection.set input.row, input.column,  nil
            if input.collection.empty?
                input.item.mark_as_deleted
            end
        end
        
        show do 
            title "Combine Wells"
            note "Combine contents of CPCR result samples into a single well of an output stripwell according to the follwing table"
            table transfer_table
        end
    end
    
    # output_collections.each do |coll|
    #     coll.move "Bench"
    # end

    
    operations.store
    return {}
    
  end

end
