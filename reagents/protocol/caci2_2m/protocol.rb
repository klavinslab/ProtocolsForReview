class Protocol

  def main

    operations.retrieve.make
    
    show do
        title "Gather the following items:"
        
        check "Graduated Beaker"
        check "100 mL bottle"
        check "CaCl2"
        check "DI H2O"
        check "Magnetic stirrer"
    end
    
    show do
        title "Add to graduated beaker"
        check "11.10 g CaCI2"
    end
    show do
        title "Adjust"
        
        check "Adjust to 50 mL with DI H2O"
    end
    show do
        title "Stir"
        
        check "Stir with magnetic stirrer until dissolved"
    end
    show do
        title "Transfer to bottle"
        
        check "Transfer solution to 100mL bottle"
    end
    show do
        title "Autoclave"
        
        check "Autoclave."
    end
    show do
        title "Label"
        
        check "Label with CaCI2 2M"
    end
    
    return {}
    
  end

end
