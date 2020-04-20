class Protocol

  def main

    operations.retrieve.make
    
   
   #ask tech to gather items
    show do
        title "Gather the following items:"
        
        check "Graduated beaker"
        check "Thiamine Hydrochloride"
        check "DI H20"
        check "Magnetic stirrer"
    end
    
   #ask tech to add thiamine hydrochloride to beaker
    show do
        title "Add to beaker"
        
        check "Add 3.4 g Thiamine Hydrochloride to beaker."
    end
    
    #display directions to adjust solution with DI Water
    show do
        title "Adjust"
        
        check "Adjust to 100 mL with DI H20"
    end
    
    #ask tech to stir solution
    show do
        title "Stir"
        
        check "Stir until dissolved."
    end
    
    #display directions to sterile filter
    show do
        title "Sterile filter"
        
        check "Sterile filter into 100 mL bottle."
    end
    
    #ask tech to label bottle
    show do
        title "Label"
        
        check "Label bottle with Thiamine Hydrochloride 34 g/L"
    end
    
    return {}
    
  end

end
