

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

INPUT = "Sample Type"

class Protocol

  def main
      
    operations.each do |op|
      
        items = check_sample_type(op)
    
        store_items(items)
        
        {}
    end

  end
  
    def store_items(items)
        
        batched_items = items.each_slice(5).to_a
        
        batched_items.each do |items|
            show do 
                title "Store items"
                items.each do |i|
                    i.store
                    note "#{i.sample.name} #{i.object_type.name}"
                    check "Item #{i.id} to #{i.location}"
                    note "------------"
                end
            end
        end
        
    end
  
    def check_sample_type(op)
      
        st_name = op.input(INPUT).val 
        samples = Sample.select{|s| s.sample_type.name == st_name}
        items = []
        
        samples.each do |s|
            s_items = s.items.select{|i| i.location != "deleted"}
            items.push(s_items)
        end
        
        items = items.flatten
    
        return items
    end
    

end
