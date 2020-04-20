# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    trays = operations.select {|op| op.input("Plants").item.object_type.name.include? "Flat"}
    flats = operations.select {|op| op.input("Plants").item.object_type.name.include? "Tray"}


    if inputs contain transgenics then show a warning
        
    Standard PPE method
    
    
    show do 
        title "Gather equipment"
        check "#{operations.length} sheets of clean white paper"
        check "seed sieve"
        check "Box of 1.5mL tubes and a tube rack"
        check "Tube labels and a pen"
        check "Scissors"
    end
    
    show do 
        title "Gather samples"
        note "Gather the following trays"
        trays.each do |t|
            check "#{t.input("Plants").item.id} at #{t.input("Plants").item.location}"
        end
        note "Gather the following flats"
        flats.each do |t|
            check "#{t.input("Plants").item.id} at #{t.input("Plants").item.location}"
        end
    end
    
    trays.each do |t|
        show do 
            title "Harvest tray #{t.input("Plants").item.id}"
            note "Cut the bolts of of all the plants in tray #{t.input("Plants").item.id}"
        end
    
    end
    
    show do 
    
    return {}
    
  end

end
