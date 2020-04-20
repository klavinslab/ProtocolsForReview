#this protocol makes 200 mL of TBS --> Farheen
class Protocol

  def main
      
    op=operations.first
    operations.retrieve.make
    
    #ask tech to gather items
    show do
        title "Gather the following items:"
       
        check "Tris solution"
        check "NaCI solution"
        check "200 mL graduated cylinder"
        check "250 mL bottle"
    end
    
    #ask tech to add solutions to cylinder
    show do
        title "Add to cylinder:"
        
        check "1 M Tris: 4 mL"
        check "5 M NaCI: 4 mL"
    end
    
    #display directions to add DI Water to cylinder
    show do
        title "Fill"
       
        check "Fill to 200 mL with DI Water."
    end
    
    #display directions to transfer solution to bottle
    show do
        title "Transfer to bottle:"
        
        check "Transfer the solution from the cylinder to a 250 mL bottle."
    end 
    
    #display directions to label bottle
     show do
        title "Label"
        
        check "Label with TBS #{op.output("TBS").item.id} 10mg/ml."
    end
    
    return {}
    
  end

end
