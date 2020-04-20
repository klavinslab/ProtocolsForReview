
INPUT = "Plants"
GOAL = "5 - 25"     

class Protocol

    def main
        
        operations.retrieve
    
        thin_out_seedlings    
        
        operations.store
        
        {}
    end
    
    def thin_out_seedlings
        
        plants_left = show do 
            title "Prepare to thin out seedlings"
            check "Take two pairs of tweezers"
            note "Take all jars of plants and move to the flow hood"
            check "Turn on the blower and lights, put on fresh gloves. Wipe down worksurface inside the flow hood with 70% ethanol"
            check "Surface sterilize tweezers with 70% ethanol"
        end
        
        show do
            title "Tips for thinning out"
            note "Hold jars of plants at a slight angle to improve access and visibility. "
            note "Remove plants from the substrate slowly and gently to avoid pulling up neighbouring plants"
            note "If plants are growing in dense clumps use two pairs of tweezers and use one pair to hold down neighbouring plants as you pull up others. To free up both hands place the lid of the jar on the surface of the flow hood and the jar half on top of the lid, pointed towards you. You can rotate the jar to get access to different sections."
        end
        
        plants_left = show do
            title "Thin out plants"
            note "Take each jar in turn. Open it up. Use tweezers to remove plants from the jar, aiming for #{GOAL} plants left, spaced out as evenly as possible in the jar. If you don't think you can pull out a plant without pulling out all of its neighbours then leave it"
            note "Record the numnber of plants lefts in the jar, estimated to the nearest 5." 
            note "Also record how clumped the remaining plants are. Singles = Plants are not touching any other plants, Small clumps = Most plants are touching 2-3 other plants, Large clumps = Most plants are touching more than 3 other plants"
            operations.each do |op|
                check "Thin out plants from jar #{op.input(INPUT).item.id}"
                select [5, 10, 15, 20, 25], var: "no_plants_#{op.id}", label: "How many plants left in the jar?", default: 1
                select ["Singles","Small clumps", "Large clumps"], var: "distribution_#{op.id}", label: "How dispersed?", default: 0
            end
        end
        
        operations.each do |op|
            op.input(INPUT).item.associate :thinned, true
            op.input(INPUT).item.associate :plants_in_jar, plants_left["no_plants_#{op.id}".to_sym]
            op.input(INPUT).item.associate :plant_distribution, plants_left["distribution_#{op.id}".to_sym]
        end
        
        show do 
            title "Clean up"
            check "Gather up all discarded seedligns and place into Biohazard waste"
            check "Clean flow hood with 70% ethanol"
            check "Close hood and turn off light"
            check "Clean and return tweezers"
        end
    
    end
    
    
end