# Library code here

    module Recipes
        
        ms_complete = "MS complete salts and vitamins"
        sh_salts = 'Schenk and Hildebrandt (SH) Salts'
        
        ppm = 'Plant Preservative Mixture'
        media_fridge = "media fridge in middle bay"
        balance = 'shelf above the balance'
        dry_chem = 'solid chemicals storage shelves'
        g = 'grams'
        ml = 'ml'
        
        #Sugars
        sucrose_point_one = {:name => 'Sucrose', :location => balance, :amount => 0.01, :units => g}
        sucrose_point_five =  {:name => 'Sucrose', :location => balance, :amount => 0.005, :units => g}
        
        #Nutrients
        ms_complete = {:name => ms_complete, :location => media_fridge, :amount => 0.00443, :units => g}
        sh_salts = {:name => sh_salts, :location => media_fridge, :amount => 0.0016, :units => g}
        
        #preservatives
        ppm = {:name => ppm, :location => media_fridge, :amount => 0.001, :units => ml}
        gelling_agent_full = {:name => 'Phytagel', :location => balance, :amount => 0.002, :units => g}
        gelling_agent_weak = {:name => 'Phytagel', :location => balance, :amount => 0.0015, :units => g}

        
        MS_1 = {
            :ingredients => {:sugar => sucrose_point_one, :nutrients => ms_complete,:preservative => ppm, :gelling_agent => gelling_agent_full},
            :ph_adjustment => {'target' => 6.0, 'adjustor' => '0.1M NaOH', 'starting_amount' => '1 mL'}
        }
        
        SH1 = {
            :ingredients => {:sugar => sucrose_point_five, :nutrients => sh_salts,:preservative => ppm, :gelling_agent => nil},
            :ph_adjustment => {'target' => 6.0, 'adjustor' => '0.1M NaOH', 'starting_amount' => '1 mL'}
        }
        
        SH2 = {
            :ingredients => {:sugar => sucrose_point_five, :nutrients => sh_salts,:preservative => nil, :gelling_agent => nil},
            :ph_adjustment => {'target' => 6.0, 'adjustor' => '0.1M NaOH', 'starting_amount' => '1 mL'}
        }
        
        SH3 = {
            :ingredients => {:sugar => nil, :nutrients => sh_salts,:preservative => nil, :gelling_agent => gelling_agent_weak},
            :ph_adjustment => {'target' => 6.0, 'adjustor' => '0.1M NaOH', 'starting_amount' => '1 mL'}
        }
        

    end
        
    
    #Define as a class and instantiate that class in the vessel protocol. 
    #Input items
    #Proportions
    