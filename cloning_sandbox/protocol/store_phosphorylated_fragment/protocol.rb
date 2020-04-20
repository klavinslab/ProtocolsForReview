# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

   show do 
       title "Take #{operations.length} tubes from incubator"
       note "Take the following tubes from the incubator. In the next steps you will store them in the freezer and the protocol will end."
       operations.each do |op|
           check "#{op.input("Incubator").item.id}"
        end
    end
    
    
    
    operations.each do |op|
    op.pass("Incubator", "Freezer")
    op.output("Freezer").item.store
    end
    
    operations.store

    return {}
    
  end

end
