needs "Plant Work/Plant Work Training"
needs "Plant Work/Plant Work General"

class Protocol

include Training
include General

  def main

    standard_PPE
    
    if training_mode? == "Yes"
            training_mode_on = true
        else 
            training_mode_on = false
    end
    
    operations.make

    show do 
        title "Prepare labels"
        note "Take a marker pen and #{operations.length} plastic plant labels"
        note "Create labels with the following numbers:"
        operations.each do |op|
            check "#{op.output("Pots").item.id}"
        end
        note "After you're done, put on gloves for the next steps"
    end
    
    show do
        title "Prepare workbench"
        note "Work at the potting bench"
                note "<a href= https://docs.google.com/spreadsheets/d/16OkfwIC0hgEmXjRQMZeab9gaVdNIjzv-g99trjd2MZs/edit?usp=sharingPlant lab inventory> Plant lab inventory </a>"
        check "1 clean back tray to work in"
        check "1 1.5ml tube rack to hold seed tubes"
        check "Clear plastic tub for soil mixing"
        check "Soil scoops"
        check "500ml plastic measuring beaker"
        check "#{operations.length} sheets of white legal paper"
    end
    
    operations.retrieve
    
    
    show do
        title "Prepare soil"
        check "Into the clear plastic tub place #{operations.length * 1.25} cups of potting soil"
        note "Cup measurements are printed on scoop handles"
        check "Add #{operations.length * 120} ml of water and mix well"
        if training_mode_on
            check "Mix until all soil is wet but there is no liquid water visible"
        end
    end
    
    show do
     title "Prepare pots"
     check "Retrieve #{operations.length} small square black pots from under the cultivation bench"
     check "Place all pots into a clean black tray"
     check "Fill each with one scoop of soil"
     check "Gently push down soil by hand till level and just under the rim of the pot"
     image "Actions/Plant Maintenance/Pots_with_soil.jpg"
    end
    
    show do
        title "Prepare seed dispensors"
        check "Take #{operations.length} clean sheets of white paper"
        check "fold each in half along its long edge"
    end
    
    if training_mode_on
        show do 
            title "Guidance on dispensing seeds"
            note "Hold the tube of seeds almost parallel to the dispensor (sheet of paper)"
            note "Tilt the tube slightly down to the paper and tap gently with your index finger. About 10 seeds should fall out with each tap. You'll get better at guaging this the more you do."
            note "A similar technique can be used to get seeds from the dispensor onto the soil."
            warning "Better to err on the side of caution, tapping lightly. Don't pour seeds everywhere."
        end
    end
    
    operations.each do |op|
    
        if op.input("Seeds").item.get(:Germination) == "Poor"
            show do
                title "Sow seeds"
                note "Sow seeds from tube #{op.input("Seeds").item.id} onto pot #{op.output("Pots").item.id}"
                note "Scatter roughly 200 seeds onto the dispensor and from there evenly onto the surface of the soil"
            end
        else
            show do
                title "Sow seeds"
                note "Sow seeds from tube #{op.input("Seeds").item.id} onto pot #{op.output("Pots").item.id}"
                image "Actions/Plant Maintenance/IMG_20170906_100221.jpg"
                note "Scatter roughly 100 seeds onto the dispensor and from there evenly onto the surface of the soil"
            end
        end
        
        seeds_left = show do
            title "Roughly how many seeds are left in tube #{op.input("Seeds").item.id}"
            select ["Almost full", "Half-full", "Quarter full", "Nearly empty", "Empty"], var: "seeds_left_#{op.input("Seeds").item.id}", label: "How much is left in the tube?", default: 1
        end
        
        op.input("Seeds").item.associate :amount_remaining, seeds_left["seeds_left_#{op.input("Seeds").item.id}".to_sym]
        
        if seeds_left["seeds_left_#{op.input("Seeds").item.id}".to_sym] == "Empty"
            show do 
                title "Discard empty tube"
                note "Discard tube #{op.input("Seeds").item.id} into the incineration waste"
            end
            
            op.input("Seeds").item.mark_as_deleted
            op.input("Seeds").item.save
        end
        
        show do
            title "Wash your hands"
            note "Spray a little ethanol on your gloves and wipe with a paper towel"
            if training_mode_on
                note "This is to help you avoid getting seeds cross-contaminated between pots"
            end
        end
        
        op.output("Pots").item.associate :provenance, op.input("Seeds").item.id
    end
    
    operations.store
    
    show do
        title "Clean workbench"
        note " Clean black tray with paper towel and 70% ethanol"
        note "Return all items to their previous locations"
        note "Wipe up any soil or spilt seeds"
    end
    
    return {}
    
  end

end

