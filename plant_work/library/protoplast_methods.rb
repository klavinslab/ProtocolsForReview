
module Harvesting
    
    INPUT = "Plants"
    OUTPUT = "Digesting Cells"
    ENZYMES = "Cell wall mix"
    
    def harvest_arabidopsis_leaves(op)
        
        show do
            title "Harvest and chop leaves"
            note "You will harvest leaves from all plants in jar  #{op.input(INPUT).item.id}, then further slice with a razorblade before deposting into petri dish#{op.output(OUTPUT).item.id}"
            check "Put on gloves, or if already wearing gloves clean with 70% ethanol"
            check "Place the chopping board in front of you"
            note "<b> Work quickly on the following step </b>"
            check "Using tweezers pull up one or a few plants at a time from Jar #{op.input(INPUT).item.id}. Using the scissors cut all fully expanded adult leaves onto the chopping board. Repeat till all leaves have been cut from all leaves"
            check "Use a spatula or other implement to "
        end
        
        slice_tissue(op)
        
        associate_mass(op)
         
         show do 
            title "Finish up harvesting"
            check "Clean the chopping board with water and 70% ethanol"
            check "Take petri dish off the balance. Place lid on top and wrap in aluminum foil (Place the foil under the dish and then fold on top)."
        end
    end
    
    def harvest_arabidopsis_clumps(op)
        show do
            title "Harvest plant material in clumps"
            note "You will harvest leaves from all plants in jar  #{op.input(INPUT).item.id} directly into petri dish#{op.output(OUTPUT).item.id}"
            check "Harvest leaves from all plants in #{op.input(INPUT).item.id}" 
            note "<b> Work quickly on the following step </b>"
            check "Using tweezers pull up clumps from Jar #{op.input(INPUT).item.id}. Using the scissors cut all expanded adult leaves into petri dish #{op.output(OUTPUT).item.id}. Try and trim the leaves, like you are giving the plants a haircut, aim for each leaf to be cut at least in two.Repeat till all leaves have been cut from all plants."
        end
        
         associate_mass(op)
         
        show do 
            title "Finish up harvesting"
            check "Clean the chopping board with water and 70% ethanol"
            check "Take petri dish off the balance. Place lid on top and wrap in aluminum foil (Place the foil under the dish and then fold on top)."
        end
        
        
    end
    
    def harvest_duckweed_whole_plants(op)
        
        show do
            title "Harvest whole duckweed plants"
            note "You will harvest duckweed plants from container #{op.input(INPUT).item.id} directly into petri dish #{op.output(OUTPUT).item.id}"
            check "Clean tweezers with ethanol and a Kimwipe"
            check "Use tweezers to transfer all duckweed plants from #{op.input(INPUT).item.object_type.name} #{op.input(INPUT).item.id} directly into petri dish #{op.output(OUTPUT).item.id}"
        end
            
        associate_mass(op)
         
        show do 
            title "Finish up harvesting"
            check "Take petri dish off the balance. Place lid on top and wrap in aluminum foil (Place the foil under the dish and then fold on top)."
            check "Carefully dispose of  #{op.input(INPUT).item.object_type.name} #{op.input(INPUT).item.id} "
        end

    end
    
    def harvest_sliced_duckweed(op)
        
        show do
            title "Transfer duckweed plants to choppping board"
            note "You will harvest duckweed plants from container #{op.input(INPUT).item.id} directly into petri dish #{op.output(OUTPUT).item.id}"
            check "Clean tweezers with ethanol and a Kimwipe"
            check "Use tweezers to transfer all duckweed plants from #{op.input(INPUT).item.object_type.name} #{op.input(INPUT).item.id} directly onto a clean chopping board"
        end
        
        slice_tissue(op)
        
        associate_mass(op)

         show do 
            title "Finish up harvesting"
             check "Clean the chopping board with water and 70% ethanol"
            check "Take petri dish off the balance. Place lid on top and wrap in aluminum foil (Place the foil under the dish and then fold on top)."
            check "Carefully dispose of  #{op.input(INPUT).item.object_type.name} #{op.input(INPUT).item.id} "
        end
        
    end
    
    def zero_balance(op)
        
        show do 
            title "Pour enzymes, zero balance"
             check "Pour #{VOL} mL from #{op.input(ENZYMES).object_type.name} #{op.input(ENZYMES).item.id} into petri dish #{op.output(OUTPUT).item.id}"
            check "Place petri dish #{op.output(OUTPUT).item.id} on a balance. TARE the balance."
        end
        
        
    end
    
    def associate_mass(op)
        
       harvest = show do 
            title "Record mass harvested "
            note "Record the leaf mass harvested"
            get "number", var: :leafmass, label: "Enter the exact value of the leaf mass", default: 2.0
        end

        op.output(OUTPUT).item.associate :leafMass, harvest[:leafmass]

    end
    
    def slice_tissue(op)
        
        show do 
            title "Process plant tissue"
            warning "Work carefully with the razorblade. Dispose in Sharps container immediately after use. Do not leave lying around"
            note "Use the blade to pull the plant material into a central clump and then chop in one direction along the clump and the other, repeat up to three times"
            check "Take a fresh razor blade to quickly and finely chop the material harvested in the previous step into <b>thin strips</b>"
            check "Use the blade, a spatula or other implement to scrae the processed tissue into dish of enzyme mix #{op.output(OUTPUT).item.id}. Swirl lightly to wet all the material"
            check "Discard the razorblade into a sharps container"
        end
    end

    
end
    