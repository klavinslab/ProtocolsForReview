# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

    # I/O
    INCOL="Collection id"

    def main
        
        operations.each { |op|
        
            col_id = op.input(INCOL).val.to_f.round
            if(debug)
                col_id =  277728 # some collection
            end
            
            # find collection, get matrix, mark all matrix ITEMS as deleted
            item_list = Collection.find(col_id).matrix.flatten.select { |it| it>0 }.uniq
            
            item_list.each { |id| 
                Item.find(id).mark_as_deleted
            }
            
            # delete collection
            Item.find(col_id).mark_as_deleted
            
            show { 
                note "deleted collection: #{col_id}"
                note "deleted items: #{item_list.to_sentence}" 
            } 
            
        }
        
        return {}
    
    end

end
