# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!
needs "Plant Work/Plant Work General"
needs "Plant Work/Plant Work Training"


class Protocol
    include Training
    include General

  def main
    
    if training_mode? == "Yes"
        training_mode_on = true
    else 
        training_mode_on = false
    end
    
    operations.retrieve.make
    
    i = 0
    operations.each do |op|
        i = i + op.input("Tissue").item.get(:pooled_biomass).to_f
    end
    
    
    buffer_sufficient = show do 
        title "Retrieve DNA extraction buffer"
        note "Check in the plant room fridge for a bottle of gDNA extraction buffer"
        note "Judging by eye, are there at least #{i} mL of buffer left?"
        select ["Yes", "No"], var: "answer", label: "Enough left?", default: 1
    end
    
    if buffer_sufficient[:answer] == "No"
        show do 
            title "Prepare new buffer"
            check "Return to the media bay"
            check "Take a clean 250 mL glass bottle"
            check "Add 90mL DI H20"
            check "Add 2.9g Sodium Chloride cyrstals"
            check "Add 10 mL 10% SDS (Sodium Dioecyl Sulfate) solution using a seriological pipette"
            check "Dissolve by sealing and inverting the bottle gently"
        end
        
        show do 
            title "Label bottle"
            note "Label with your initials, today's date and 'DNA extraction buffer (1% SDS, 0.5M NaCl)"
            note "Clean up the media bay and return to the plant lab with the buffer"
        end
    end
    
        show do 
            title "Gather materials for next steps"
            check "1 mL pipette and tips"
            check "Scissors"
            check "Mortar and pestle"
            check "#{operations.length} 15 mL falcon tubes"
        end
        
        standard_PPE
    
        operations.each do |op|
            show do
                title "Homogenize tissue"
                note "Pour contents of falcon tube #{op.input("Tissue").item.id} into a clean mortar"
                note "Add #{op.input("Tissue").item.get(:pooled_biomass)} mL of extraction buffer"
                note "Grind with pestle until homogeneous"
                note "Take 1 mL pipette tip and cut the end off with scissors"
                note "Using a 1mL pipette with a cut tip transfer into a clean 15 mL falcon tube and label it #{op.output("gDNA").item.id}"
            end
            
            show do 
                title "Clean mortar"
                note "Spray with 70% ethanol and wipe clean"
            end
        end
        
        show do 
            title "Pellet homogenized tissue"
            note "Spin down the 15mL falcon tubes in the large centrifuge at 7,500xg for 15 minutes"
            warning "Be sure to balance. Not just the number of tubes but the volumes should also be balanced"
            note "Once the centrifuge is running click to proceed"
        end
        
        show do 
            title "Prepare tubes of ice-cold isopropranol"
            note "Go to the -20 freezer in the side lab. Take out the bottle of isopropanol and a styrofoam box with ice block"
            note "Grab #{operations.length} 50 mL falcon tubes"
            note "Label as follows and add the following volumes of ice cold isopropanol:"
            operations.each do |op|
                check "#{op.output("gDNA").item.id} with #{op.input("Tissue").item.get(:pooled_biomass).to_f * 5} mL of ice-cold isopropanol"
            end
        end
        
        show do 
            title "Add supernatant from tissue homogenate into isopropanol"
            note "Transfer supernatant from each 15 mL falcon into the 50mL falcon with the matching ID number. Vortex 50mL falcon immediately after."
            note "Avoid disturbing the pellet of plant tissue."
            operations.each do |op|
                check "#{op.output("gDNA").item.id} and vortex"
            end
        end
        
        show do
            note "Incubate on the ice-block for 5 minutes"
            timer initial: { hours: 0, minutes: 5, seconds: 00}
            note "In the meantime chill the large lab centrifuge to 4°C"
        end
        
        show do
            title "Pellet DNA"
            note "Spin down falcons in the large lab centrifuge for 1 hour"
            warning "Balance properly (equal volumes opposite each other) before starting the centrifuge"
        end
        
        show do
            title "Discard supernatant"
            note "Check each falcon tube for a pellet. It should be visible white smear at the bottom of the falcon"
            note "Using a pipette boy carefully remove all supernatant but don't disturb the pellet"
            note "Dispose supernatant into a bottle labelled 'waste ethanol/isopropanol'"
        end
        
        show do 
            title "Add 70% ethanol"
            note "In this step we clean the pellet with ethanol"
            note "Add 5mL of room temperature 70% ethanol to each tube"
            note "Shake each tube to break apart the pellet."
            note "Spin down in the large lab centrifuge for 30 minutes"
        end
        
        show do 
            title "Dry pellet"
            note "Remove 70% ethanol from each tube and dispose into waste bottle as before"
            note "Again, be sure not to disturb the pellet"
            note "Leave the falcon lying on its side with the aperture pointed downwards to encourage drying out"
            note "Leave for at least 5 minutes, or until dry"
        end
        
        show do
            title "Dissolve pellet in MG H20"
            note "Add 100µl MG H20"
            note "Vortex to redissolve fully"
        end
        
        operations. each do |op|
            nanodrop = show do
                title "Measure #{op.output("gDNA").item.id} at the nanodrop"
                get "number", var: "ng_#{op.id}", label: "ng per µl", default: 100
                get "number", var: "260_#{op.id}", label: "260/280 ratio", default: 2
                get "number", var: "230_#{op.id}", label: "260/230 ratio", default: 2
            end
        
            op.output("gDNA").item.associate :concentration, nanodrop["ng_#{op.id}".to_sym]
            op.output("gDNA").item.associate :ratio_260_280, nanodrop["260_#{op.id}".to_sym]    
            op.output("gDNA").item.associate :ratio_260_230, nanodrop["230_#{op.id}".to_sym]    
        end
        
    
    
    operations.each do |op|
        if op.input("Tissue").item.get(:experiment_role) == "control"
            op.output("gDNA").item.associate :experiment_role, "control"
        else
            op.output("gDNA").item.associate :experiment_role, "treatment"
        end
        op.input("Tissue").item.mark_as_deleted
        op.input("Tissue").item.save
    end
        
    operations.store

    
    return {}
    
  end

end
