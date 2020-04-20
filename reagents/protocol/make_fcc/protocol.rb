#Make FCC buffer protocol --> Farheen
needs "Reagents/MediaMethods"

class Protocol
include MediaMethods

  def main
      
      op=operations.first
      
  operations.retrieve interactive: false
      operations.make
    
    #describes protocol
     show do 
      title "About this Protocol"
      
      note "This protocol makes FCC for yeast transformations."
    end
    
    
    #ask tech to gather items
    show do
        title "Gather the following items:"
        
        check "250 mL bottle"
        check "DMSO"
        check "Glycerol"
        check "MG H20"
    end
    
    #ask tech to add DMSO
   measure 20, "mL", "DMSO"
    
    #ask tech to add Glycerol
    show do
        title "Add Glycerol"
        
        check "Measure out 20 mL of Glycerol and add to bottle."
    end
    
    #ask tech to add MG H20
    show do
        title "Add MG H20"
        
        check "Measure out 160 mL of MG H20 and add to bottle."
    end
    
    #display directions to mix contents
    show do
       title "Shake"
      
       check "Shake until all contents are well mixed. Label the bottle #{op.output("FCC").item.id}, 'date', and your initials."
    end 
    
    #ask tech to gather items
    show do
        title "Gather the following items"
        
        check "250 mL bottle"
        check "Bottle-top filter sterilizer"
    end
    
    #display instructions to filter sterilize
    show do
        title "Filter Sterilize"
        
        check "Screw bottle-top filter onto empty 250 mL bottle"
        check "Connect to vacuum and turn vacuum on"
        check "Slowly pour in the unsterilized FCC"
    end
    
    #ask tech to label bottle
    show do
        title "Label"
        
        check "After all the solution has filtered through turn off vacuum"
        check "Remove bottle-top filter sterilizer"
        check "Label bottle with 'FCC Filter Sterilized', #{op.output("FCC").item.id}, 'date', and your initials."
    end
    
    #ask tech to return items
    show do
        title "Return:"
        
        check "DMSO"
        check "Glycerol"
        check "MG H20"
        check "Throw away bottle-top filter"
        
    end     
    
    operations.store interactive: false
    
    return {}
    
  end

end