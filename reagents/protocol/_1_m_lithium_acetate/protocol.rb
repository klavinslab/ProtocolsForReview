#this protocol makes 1 M Lithium Acetate for yeast transformations --> Farheen

needs "Reagents/MediaMethods"

class Protocol
include MediaMethods

  def main
      
    op=operations.first

 
    operations.retrieve interactive: false
    operations.make    
    
    #describe function of protocol
    show do
        title "About"
        
        note "This protocol makes 1 M Lithium Acetate for yeast transformations."
    
    #ask tech to gather items    
     show do 
        title "Gather the following items:"
       
        check "250 mL bottle"
        check "Lithium Acetate"
      
    end
    
    #ask tech to add Lithium Acetate to bottle 
    show do
        
        check "Weigh out 13.2g Lithium Acetate and add to bottle"
    end
    
    #display directions to add DI water
    show do
        title "Add water"
        
        check "Take the bottle to the DI water carboy and add water up to the 200 mL mark."
    end
    
    #display directions to label bottle and dissolve powder
    show do 
        title "Label"
        
        check "Label bottle #{op.output("1 M Lithium Acetate").item.id}, 'date,' and your initials"
        check "Shake until the powder is dissolved"
        
    end
    
   #step 5-7
   
   steps 250, "1 M Lithium Acetate"
    
   #display directions to label and store bottle
    show do 
        title "After all of the solution has been filtered"
        
        check "turn off vacuum"
        check "remove bottle top filter sterilizer"
        check "label bottle with '1M Lithium Acetate Filter Sterilized', #{op.output("1 M Lithium Acetate").item.id} filter sterilized, 'date,' and your initials"
        check "place on shelf"
   end
    
    #display directions to clean up
    show do
        check "throw away bottle top filter sterilizer"
        
        check "place empty 200 mL bottle in dishwashing station"
        check "return the Lithium Acetate"
    end
    
    operations.store interactive: false
    
    return {}
    
  end

end
