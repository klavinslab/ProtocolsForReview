#this protocol displays directions to make 200 mL of TBSF --> Farheen
class Protocol

  def main

    op=operations.first
    operations.retrieve.make
    
    #ask tech to gather items
   show do
       title "Gather the following items:"
       
       check "Tris solution"
       check "NaCI solution"
       check "2 100 mL bottles"
       check "Graduated Cylinder"
   end
   
   #ask tech to add solutions to cylinder
   show do
       title "Add to cylinder:"
       
       check "1 M Tris: 4 mL"
       check "5 M NaCI: 4 mL"
   end
   
   #display directions to fill cylinder with DI Water
   show do
       title "Fill"
       
       check "Fill to 200 mL mark with DI Water."
   end

    #display directions to transfer solution to bottle
    show do
        title "Transfer to bottle"
        
        check "Transfer the solution from the ylinder into a 250 mL bottle."
    end
    
    #ask tech to add BSA to bottle
    show do
        title "Add to bottle:"
        
        check "Add 2 g of BSA (Bovine Serum Albumin) to 250 mL bottle."
        warning "DO NOT SHAKE"
    end
  
    #display directions to filter sterilize 
   show do 
    title "Filter sterilize"
    
        check "Fully dissolve BSA" 
        check "Filter sterilize 200 mL into 2 bottles of 100 mL aliquots."
    end 
    
    #display directions to label and bottle
    show do
        title "Label"
    
        check "Label with TBSF #{op.output("TBSF").item.id} 10mg/ml."
        check "Store in R4 Fridge."
    end

    
    return {}
    
  end

end
