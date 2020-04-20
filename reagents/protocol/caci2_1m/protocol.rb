
class Protocol

  def main

    operations.retrieve.make
    
    #ask tech to gather items
    show do
        title "Gather the following items:"
        
        check "Graduated Beaker"
        check "100 mL bottle"
        check "CaCl2"
        check "DI H2O"
        check "Magnetic stirrer"
    end
    
    #ask tech to add CACI2 to beaker
    show do
        title "Add to graduated beaker"
        check "11.10 g CaCI2"
    end
    
    #display directions to adjust CACI2 with DI water
    show do
        title "Adjust"
        
        check "Adjust to 100 mL with DI H2O"
    end
    
    #ask tech to stir solution
    show do
        title "Stir"
        
        check "Stir with magnetic stirrer until dissolved"
    end
    
    #display directions to transfer solution to bottle
    show do
        title "Transfer to bottle"
        
        check "Transfer solution to 100mL bottle"
    end
    
    #ask tech to autoclave bottle
    show do
        title "Autoclave"
        
        check "Autoclave."
    ends
    
    #ask tech to label bottle
    show do
        title "Label"
        
        check "Label bottle with CaCI2 1M"
    end
    
    
    return {}
    
  end

end
