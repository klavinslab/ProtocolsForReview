#this protocol makes 200 mL of PBS --> Farheen

class Protocol
def main
    
    op=operations.first
    
  #ask tech to gather items    
  show do
    title "Gather the following items:"
    
    check "Na2HPO4 solution"
    check "NaH2PO4 solution"
    check "NaCI solution"
    check "200 mL graduated cylinder"
    check "250 mL bottle"
  end
  
  #ask tech to add solutions to cylinder
  show do
    title "Add the following to graduated cylinder:"
    
    check "1 M Na2HPO4: 3.096 mL"
    check "1 M NaH2PO4 0.904 mL"
    check "5 M NaCI: 6 mL"
  end

  #display directions to fill cylinder with DI water  
  show do
    title "Fill:"
   
    check "Fill to 200 mL mark wtih DI Water."
  end
  
  #display directions to transfer solution to bottle
  show do
      title "Transfer to bottle:"
     
      check "Transfer solution from the cylinder to a 250 mL bottle."
  end
  
  #display directions to label bottle
  show do
      title "Label"
      
      check "Label with PBS #{op.output("PBS").item.id} 10mg/ml."
  end
      
    return {}
    
  end

end
