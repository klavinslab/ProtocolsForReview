# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    show do 
        title "Water plants and remove from torture chamber"
        note "Take the plants listed in the next slide out of the torture chamber and return them to the listed location"
        note "Add 100mL of water to each tray"
        operations.each do |op|
            check "#{op.input("Plants").item.id}"
        end
    end
    
    operations.each do |op|
        op.pass("Plants")
    end
        
    operations.store(io: "output", interactive: true)
    
    show do 
        title "Shut down torture chamber if empty"
        note "If there are no more plants left in the chamber turn off the light and heater"
    end
    
    return {}
    
  end

end
