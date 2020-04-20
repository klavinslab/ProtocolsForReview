# Brine Shrimp Library


module BrineShrimp

  def hatch_brine_shrimp()
    
    #totalFeedings = 0
    #operations.each{ |op| totalFeedings = totalFeedings + op.input("Feedings").val }
    #Gather hatching setup
    show do
      title "Gather the following equipment"
        
      bullet "Imhoff Hatching Cone"
      bullet "Hatching Cone Lid (labeled with day of feeding)"
      bullet "Flexible Air Hose"
      bullet "Rigid Tubing"
      bullet "Air Pump"
      bullet "Brine Shrimp Eggs"
    end
    
    #begin hatching shrimp
    show do
      title "Assemble setup"
      
      bullet "Put the cap on the cone"
      bullet "Label the cone for day of use two days later (ie. if it is Monday label the cone for use on Wednesday)"
      bullet "Place Imhoff hatcing cone into a slot of the imhoff cone rack"
      bullet "Fill each Imhoff Hatching Cone with 250ml of Artificial Sea Water"
      bullet "Weigh 1g of brine shrimp eggs (about 1 scoop)"
    end
    
    #Run the procedure, leave eggs to hatch
    show do
      title "Run Procedure"
      
      bullet "Add 1g brine shrimp eggs to the hatching cone"
      bullet "Connect one end of flexible air hose to air pump"
      bullet "Connect other end of flexible air hose to rigid tubing"
      bullet "Place rigid tubing into hatching cone"
      check "Turn on the air pump and leave them to hatch"
    end
    
    data = show do
      title "Make more seawater?"
      select [ "yup", "nope" ], var: "moreplease",
                                label: "Are you running low of artificial seawater?",
                                default: 0
      select [ 1000, 2000 ], var: "howmuch",
                             label: "If so, how much (in mL)?",
                             default: 0
    end
    
    show do
      recipe = 35.8 # (g) mass of Instant Ocean Mix per liter of DI H20
      volume = data[:howmuch] / 1000 # (L) total volume of mix produced
      
      title "Make Artificial Seawater"
      note "Obtain a #{volume} L bottle from the media bay"
      note "Obtain the Instant Ocean Mix from cupboard A2505"
      note "Add #{(recipe * volume).round(2)} g of Instant Ocean Mix to the bottle"
      note "Add #{volume} L of water to the bottle"
      note "<a href='https://youtu.be/8B7xr_EjbzE' target='_blank'>Shake, Rattle, and Roll!</a>"
    end if data[:moreplease] == "yup"
    
    return {}
    
    end
    
end