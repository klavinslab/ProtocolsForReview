class Protocol

  def main
    
    #ask tech to gather items
    show do
        title "Gather the following items:"
        
        check "Graduated beaker"
        check "100 mL bottle"
        check "DI H20"
        check "Magnetic stirrer"
    end
    
    #ask tech to add MgSO4 to beaker
    show do
        title "Add to beaker"
        
        check "Add 24.65 g MgSO4 to beaker."
    end
    
    #display directions to adjust with DI water
    show do
        title "Adjust"
        
        check "Adjust to 100 mL with DI H20"
    end
    
    #ask tech to stir solution
    show do
        title "Stir"
       
        check "Stir with magnetic stirrer until dissolved."
    end
    
    #display directions to transfer solution to bottle
    show do
        title "Transfer"
        
        check "Transfer to 100 mL bottle"
    end
   
   #ask tech to autoclave bottle
    show do
        title "Autoclave"
        
        check "Autoclave bottle."
    end
    
    #ask tech to label bottle
    show do
        title "Label"
        
        check "Label bottle with MgSO4 1M"
    end
    
    operations.store
    
    return {}
    
  end

end
