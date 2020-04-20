# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main
      
    op = operations.first
      
    batch_info = show do
        title "Which E. coli strain would you like to make a batch for?"
        
        select ["DH5alpha", "NEBStable", "DB3.1", "KL740"], var: :strain, label: "Choose wisely:", default: 0
        get "number", var: :num, label: "Number of comp cells", default: op.input("Num Cells").val
    end
    
    operations.make
    strain = Sample.find_by_name(batch_info[:strain])
    batch_info[:num].to_i.times { op.output("Batch").collection.add_one strain }
    
    show do
        title "That's it!"
        
        note "Made E. coli Comp Cell Batch of #{op.output("Batch").collection.num_samples} cells"
        note "Batch link #{op.output("Batch").item}"
    end
    
    operations.store
    
    return {}
    
  end

end
