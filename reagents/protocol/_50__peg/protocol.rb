#protocol makes 50% PEG for yeast transformations--> Farheen
needs "Reagents/MediaMethods"
class Protocol
include MediaMethods
  def main
      
      op=operations.first

    operations.retrieve interactive: false
    operations.make
   
   #display function of protocol
   show do
       title "About"
       
       note "This protocol makes 50% PEG for yeast transformations"
   
   #ask tech to gather items
   show do
       title "Gather the following items:"
       
       check "250 mL bottle"
       check "PEG 3350"
       check "Medium Magnetic Stir Bar"
       check "Hot/stir plate"
   end
   
   #ask tech to add stir bar to bottle
   show do
    title "Add to bottle"
    
    check "Add stir bar to bottle"
   end 
   
   #ask tech to add PEG 3350 to bottle
   show do 
       title "Add to bottle:"
      
       check "Weigh out 100g PEG 3350 and add to bottle."
   end
   
   #display directions to add DI water
   show do
       title "Add water"
       
       check "Take the bottle to the DI water carboy and add water up to the 200 mL mark."
   end
   
   #display directions to label bottle and dissolve powder
   show do
       title "Label"
       
       check "Label bottle #{op.output("50% PEG").item.id}, ‘date’, and your initials."
       check "Stir at ~80°C on hot plate until all powder is dissolved."
   end

 steps 250, "50% PEG"
    
    #display directions to label bottle
    show do
        title "Label"
        
        check "After all of the solution has been filtered turn off vacuum"
        check "remove bottle top filter sterilizer"
        check "label bottle with '50% PEG Filter Sterilized', #{op.output("50% PEG").item.id} filter sterilized, ‘date’, and your initials. Place on shelf."
    end
   
   #display directions to clean up
    show do
        title "Return"
        
        check "Throw away bottle top filter sterilizer." 
        check "Place empty 200 mL bottle in dishwashing station."
        check "return the PEG 3350."
    end
    
    operations.store interactive: false
    
    return {}
    
  end

end
