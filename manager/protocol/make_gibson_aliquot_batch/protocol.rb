#Produce a new Gibson Aliquot Batch
#Current object definition for Gibson Aliquot batch needs to be updated, it is currently listed as a 1x12 collection
class Protocol

  def main
      
    op = operations.first
      
    batch_info = show do
        title "How many aliquots are in the new Gibson batch?"
        get "number", var: :num, label: "Number of aliquots", default: op.input("Num Aliquots").val
    end
    
    operations.make
    gibson_aliquot = Sample.find 13003
    batch_info[:num].to_i.times { op.output("Batch").collection.add_one gibson_aliquot}
    
    show do
        title "That's it!"
        
        note "Made Gibson Aliquot Batch of #{op.output("Batch").collection.num_samples} aliquots"
        note "Batch link #{op.output("Batch").item}"
    end
    
    operations.store
    
    return {}
    
  end

end
