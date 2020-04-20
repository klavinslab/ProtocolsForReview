module Training 
    def training_mode?
        
       question = show do
            title "Enter training mode?"
            note "Would you like additional guidance for this protocol? Choose yes to receive background and tips on plant cultivation? Choose no to proceed quicker through the protocol"
            select ["No","Yes"], var: "answer", label: "Guidance?", default: 1
        end
        
        return question[:answer]
    end
    
    def arabidopsis_general_info
        show do
            title "Background on <i>Arabidopsis thaliana</i>"
            note "<i>Arabidopsis thaliana</i> AKA Arabidopsis, is the best studied laboratory plant. It is a weedy plant of Northern latitudes. It has a short life cycle, small size and small genome, relative to other plants"
            note "Arabidopsis doesn't need a lot of water but letting it dry out will interfere with growth and development."
            note "Here's a picture of healthy 4 week old Arabidopsis. The rosette of leaves are fully developed"
            image "Actions/Plant Maintenance/Arabidopsis_needing_watering.jpg"
        end
    end
    
    def nicotiana_benthamiana_general_info
        show do 
            title "General info on <i>Nicotiana benthamiana</i>"
            note "<i>Nicotiana benthamiana</i> AKA N. benth or benthi, is an Australian cousin of tobacco. Laboratory varieities are prized for their weak immune systems that allows transient leaf transformation, and for high transgene expression levels. They grow quickly and at full size one plant can produce grams of seed."
            image "benthi"
        end
    end
    
    
    def pot_watering
        show do 
                title "Tip: Watering pots of arabidopsis and benthamiana"
                note "Check the soil visually, it should be moist and dark. If it's light brown then add up to 50ml water"
                note "The pot below has dried out further than is recommended and is in definite need of water"
        end
            
        show do
            title "This is what you are aiming for after watering"
            image "Actions/Plant Maintenance/Benth_pot_watered.jpg"
        end
    end

    def jiffy_squeeze
          show do 
                title "Tip: The jiffy-squeeze"
                note "The little soil bags that the Arabidopsis are growing in are called Jiffy-pellets"
                note "Wearing gloves it can be hard to sense how wet the soil is with a touch. In addition it can be hard to judge visually without looking up close. This is especially true for plants growing under colored light. Give the jiffy pot a very slight squeeze and you'll instantly get a good idea of how wet it is. A dried jiffy pellet will feel very light and brittle to the touch, instead of heavy and pliant for a moist jiffy pellet"
        end
    end

    def tray_watering
        show do
            title "Tip: Watering trays of arabidopsis"
            note "Add up to 100 ml water per tray. Add less if jiffy pellets still look dark and moist. Arabidopsis shouldn't be waterlogged"
            note "Below is an image of a tray of arabidopsis with a typical amount of water"
            note "Ensure that water is evenly distributed by tilting the tray back and forth once after adding the water"
            image "Actions/Plant Maintenance/Arabidopsis_watered.jpg"
        end
    end
    
    def media_bay_ground_rules
        show do 
            title "Media bay ground rules"
            note "This is a bay dedicated to preparing sterile media."
            warning "Do not bring microbial plates or cultures in here"
            note "Leave the bay as clean or cleaner than you found it"
            warning "Always clean the balance after you're done with it, even if you can't see any visible remnants"
            note "Above all enjoy yourself :)"
            warning "That was a joke. This is a lab, not a funfair."
        end
    end
    
end
     
   