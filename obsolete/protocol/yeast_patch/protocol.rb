# November 9, 2017

class Protocol

  def main

    operations.retrieve.make
    
    show do
        title "Materials for Yeast Patching"
        
        check "Obtain #{operations.length} YPD plates without divisions, from the 4C plate fridge."
        check "Box of P1000 tips."
        check "Sharpie Pen"
    end
    
    operations.each do |op|
        coll = op.input("Colony").collection
        sample = op.input("Colony").sample
        row =  op.input("Colony").row
        column =  op.input("Colony").column

        show do 
            title "Patch a Single Colony from Divide Yeast Plate"
            
            check "Obtain a YPD plate without divisions and label with Item# <b>#{op.output('Plate').item.id}</b>."
            # note "Next, take sample #{sample} from #{coll} in row #{row} and column #{column} and plate onto #{op.output("Plate").item}"
            note "Using a P1000 pipette tip in hand, take a whole single colony from <b>#{coll.id}.#{column + 1}</b> and streak onto #{op.output("Plate").item.id}."
            note "Using the same tip, turn the plate 90 degrees and streak again."
            note "This should create a large criss-cross patch of cells across a whole plate."
        end
        op.output("Plate").item.move "30 C incubator"
    end
    operations.store
    
    return {}
    
  end

end
