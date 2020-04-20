needs "Plant Work/Plant Work General"
needs "Plant Work/Plant Work Training"
class Protocol
    include General
    include Training
    
  def main
      
    selection_criterion = "If there is at least one fully green leaf then harvest the whole aerial portions (leaves+stem) of the plant. Otherwise do not harvest."

    operations.make
    
    if training_mode? == "Yes"
        training_mode_on = true
    else 
        training_mode_on = false
    end
    
    show do 
        title "Retrieve petri dishes from the main lab"
        check "Retrieve #{operations.length} petri dishes from the media bay in the main lab"
        check "Bring them to the plant lab"
    end
    
    standard_PPE
    
    show do 
        title "Label petri dishes"
        note "Using a sharpie or other permenant marker write each of the following ID numbers on the lid and side of a petri dish:"
        operations.each do |op|
            check "#{op.output("Tissue").item.id}"
        end
    end
    
    show do 
        title "Gather trays of plants for harvesting"
        note "Take the following trays to the work bench"
        operations.each do |op|
            check "#{op.input("Plants").item.id} from #{op.input("Plants").item.location}"
        end
    end
    
    if training_mode_on
        show do 
            title "Taking pictures of trays"
            note "You can use the lab chromebook to take pictures of trays as shown below"
            note "Open the camera app, position everything and use the mouse to click the take photo button"
            note "Contrary to these images place the tray such that the ID number will be visible in the photo"
            image "Actions/Plant Maintenance/Photgraphing_trays_1.jpg"
            image "Actions/Plant Maintenance/Photographing_trays_2.jpg"
        end
    end
    
    photo = show do 
        title "Take a photo of each tray and upload"
        operations.each do |op|
            note "#{op.input("Plants").item.id}"
            upload var: "photo_#{op.id}"
        end
    end

        
        
    if operations.select {|op| op.input("Dry after harvest?").val == "Yes"}.empty? == false
        show do 
            title "Turn on the torture chamber"
            note "Plug in the light and heater mid-way. Aiming for a temperature around 100°F"
        end
    end
    
    operations.each do |op|
        show do 
            title "Harvest tissue from #{op.input("Plants").item}"
            if op.input("Tissue to harvest").val == "Aerial"
                note "Use the following selection criterion"
                note selection_criterion
                note "Using tweezers pinch off the base of the aerial tissue of each plant in tray #{op.input("Plants").item.id} and place it into petri dish #{op.output("Tissue").item.id}"
            end
        end
        
        if op.input("Dry after harvest?").val == "Yes"
            show do 
                title "Place dish in the torture chamber"
                note "Place dish #{op.output("Tissue").item.id} in the torture chamber with the lid open (underneath the dish)"
            end
            op.output("Tissue").item.location = "Torture chamber"
            op.output("Tissue").item.save
        end
    
    end
    
    operations.each do |op|
        op.input("Plants").item.location = "Harvested"
        op.input("Plants").item.save
        op.output("Tissue").item.associate :tissue_harvested, op.input("Tissue to harvest").val
        op.output("Tissue").item.associate :selection_criterion, selection_criterion
        op.input("Plants").item.associate :photo, photo["photo_#{op.id}"]
    end
    
    
    operations.store
    
    return {}
    
  end

end
