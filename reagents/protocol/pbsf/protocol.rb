#this protocol makes 200 mL of PBSF --> Farheen
class Protocol

  def main
      
    op=operations.first
    operations.retrieve.make
    
    #ask tech to gather items
    show do
    title "Gather the following items:"
    
    check "Graduated cylinder"
    check "250 mL bottle"
    check "Na2HPO4 solution"
    check "NaHPO4 solution"
    check "5 M NaCl solution"
end
    
    #ask tech to add solutions to cylinder
    show do
        title "Add to cylinder:"
        
        check "1 M Na2HPO4: 3.096 mL"
        check "1 M Na2HPO4: 0.904 mL"
        check "5 M NaCI: 6mL"
    end
    
    #ask tech to add DI water
    show do
        title "Fill"
        
        check "Fill to 200mL with DI Water"
    end
    
    #display directions to transfer solution from cylinder into bottle
    show do
        title "Transfer to bottle"
        
        check "Transfer solution from cylinder into 250 mL bottle"
    end
    
    #ask tech to add BSA to bottle
    show do
        title "Add to bottle:"
        
        check "Add 2 g of BSA (Bovine Serum Albumin) to 250 mL bottle"
        warning "DO NOT SHAKE"

    end
    
   #display directions to filter sterilize 
    show do
        title "Filter steralize"
        
        check "Fully disolve BSA"
        check "Filter sterilize 200 mL into 2 bottles of 100 mL aliquots"
        check "Store in R4 fridge"
    end
    
    #display directions to label bottle
    show do
        title "Label"
        
        check "Label with PBSF #{op.output("PBSF").item.id} 10mg/ml"
        check "Store in R4 Fridge"
    end
    
    operations.store interactive: false
    
    return {}
    
  end

end
