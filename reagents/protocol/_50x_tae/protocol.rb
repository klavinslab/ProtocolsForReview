#this protocol makes a TAE buffer --> Farheen

class Protocol

      def main
      op=operations.first

    operations.retrieve interactive: false
    operations.make

    #ask tech to gather items
    show do 
        title "Gather the following items:"
    
        check "Tris Base"
        check "EDTA Disoidum Salt"
        check "Acetic Acid"
        check "1 L Bottle"
    end 

    #ask tech to add Tris Base to bottle
    show do 
        title "Add to bottle"
    
        check "Weigh out 242g of Tris Base and add to the 1 L Bottle"
    end 

    #ask tech to add EDTA Disodium Salt to bottle
    show do 
    
        check "Weigh out 14.62g EDTA Disodium Salt and add to 1 L bottle"
    end 

    #ask tech to add Acetic Acid to bottle
    show do 
        title "WORK IN THE FUME HOOD"
    
        check "Measure out 57.7 mL Acetic Acid and add to 1 L Bottle"
end

    #ask tech to add DI water
    show do 
        check "Add DI Water up to the 1L mark"
        check "mix well"
    end

    #display directions to label and store bottle
    show do #label
        title "Label"
    
        check "Label the bottle #{op.output("50X TAE").item.id}, 'date', and your initials."
        check "Store in the gel room cabinet"
    end
        operations.store interactive: false
    
    return {}
    
  end

end
