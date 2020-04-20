#O. de Lange. June 2017. Rewritten 2nd Nov 2017
#PART 1: Methods to find and sort relevant items into hashes to be called in the rest of the protocol.
#PART 2: Watering plants
#PART 3: Checking plant statuses
#PART 4: General room maintenance

needs "Standard Libs/Debug"
needs "Plant Work/Plant Work Training"
needs "Plant Work/Plant Maintenance"
needs "Plant Work/Plant Work General"

class Protocol
    include Debug
    include ItemandOperationMethods
    include WateringandChecking
    include General
    include RoomMaintenance
    include Training
    include PlantMaintenanceGeneral
    
    def main
          
        standard_PPE
        
         if training_mode? == "Yes"
            training_mode_on = true
        else 
            training_mode_on = false
        end
    
            
        ##################
        show do 
            title "Watering"
            note "The next slides will instruct you to go through the plants in the grow room by Object Type and water them"
        end
        
        # if training_mode_on
        #     show do
        #         title "Open up the growth racks"
        #         note" Unhook the bungee cords and fasten them at the side of each rack as shown below"
        #         image "Actions/Plant Maintenance/GR12_Open.jpg"
        #         image "Actions/Plant Maintenance/GR3_open.jpg"
        #     end
        # end
        
        # if training_mode_on then pot_watering && tray_watering && jiffy_squeeze end
        if training_mode_on then tray_watering && jiffy_squeeze end  
        
        
        # water "Arabidopsis seedlings on soil", "GR2", "25 mL per pot"
        # water "Arabidopsis seedlings on soil", "GR3", "25 mL per pot"
        # water "Pot of N. benthamiana seedlings", "GR2", "50mL per pot"
        # water "Tray of Arabidopsis plants", "GR1", "100 mL per tray, less if they are still damp"
        water "Tray of Arabidopsis plants", "LAB BENCH", "100 mL per tray, less if they are still damp"
        # water "Flat of Arabidopsis", "GR3", "50mL per pot"
        # water "Tray of N. benthamiana plants", "GR1", "100mL per pot"
        
       ####################
    
        ## PART TWO: Checking statuses
        #Pot_germination
        
        # germination_check "Arabidopsis seedlings on soil", 12
        # germination_check "Pot of N. benthamiana seedlings", 6
    
        #Check for bolting
            ##trays
            # bolting_trays_check "Tray of Arabidopsis plants"
            # bolting_trays_check "Tray of T1 Arabidopsis"
            # bolting_trays_check "Tray of N. benthamiana plants"
            
            # ##flats
            # flats_check "Flat of Arabidopsis T1 plants"
            # flats_check "Flat of Arabidopsis"
        
        #Move T0 flats to the drying table
        # t0_flats= gather_plant_items "Flat of T0 plants"
        # t0_flats_to_move = t0_flats.select {|f| days_old f >= 1}
        # move_plants t0_flats_to_move, "Drying table", "DT"
        
        # #Move non-transgenic plants to the drying table
            # wt_plants_for_harvest =  delayed_plan_input_check 280, "Plant", "Arabidopsis line"
            # if wt_plants_for_harvest.empty? == false
            #     wt_plants_to_move = wt_plants_for_harvest.select {|wp| wp.get(:infloresence) == "green siliques"}
            #     move_plants wt_plants_to_move, "Drying table", "DT"
            # end
       
        #Check leaf sizes of plants going to be infiltrated
        # arab_leaf_infiltrations = delayed_plan_input_check 284,"Plants","Arabidopsis line"
        # if arab_leaf_infiltrations.any? then leafsize_check arab_leaf_infiltrations, "2 cm", "Arabidopsis" end
        # benthi_leaf_infiltrations = delayed_plan_input_check 284,"Plants","Nicotiana benthamiana"
        # if benthi_leaf_infiltrations.any? then leafsize_check benthi_leaf_infiltrations, "3 cm", "N. Benthamiana" end
        
        # #Check selection plates
        # check_selection_plates "Arabidopsis T1 selection plate"

        ##Checking for tray drying##
        # trays_to_dry = delayed_plan_input_check 280,"Tray","Arabidopsis ecotype"
        
        #Checking for items that are ready for seed harvest
        
        # dt_items = items_by_location "DT"
            
        #     data = show do 
        #         if training_mode_on
        #             note "Siliques are ready for harvesting when they are brown and some are beginning to open"
        #         end
        #         dt_items.each do |dt|
        #             note "Are the infloresences on plant item #{dt.id} ready to harvest?"
        #             select ["No", "Yes"], var: "infloresences_#{dt.id}", label: "ready to harvest?", default: 0
        #         end
        #     end
            
        # dt_items.each do |dt|
        #     dt.associate :ready_for_harvest, data["infloresences_#{dt.id}"]
        # end
        
        ######  
        item_comment_query
        #####
        
        
        #PART 4: GENERAL ROOM MAINTENANCE
        # show do
        #     title "Refill the humidifier"
        #     note "Refill the humidifier which is on the floor next to GR1/2. You can just pour water directly out of the cuboid plastic water carrier into the huimdifier until the full line"
        # end
        
        # cleaning = show do
        #     select ["Yes" , "No" ], var: "water", label: "Is there still at least half a carboy full of water?", default: 0
        #     select ["Yes" , "No" ], var: "floor_clean", label: "Is the floor clean?", default: 1
        #     select ["Yes" , "No" ], var: "surfaces_clean", label: "Are all the work surfaces tidy and clean?", default: 0
        #     select ["No" , "Yes"], var: "waste_full", label: "Is the plant waste bin more than 2/3 full?", default: 0
        # end
        
        # if cleaning[:floor_clean] == "No" then clean_floor end
        # if cleaning[:surfaces_clean] == "No" then clean_surfaces end
        # if cleaning[:waste_full] == "Yes" then waste_disposal end
        # if cleaning[:water] == "No" then refill_protocol end
        
        if training_mode_on
            show do
                title "Leaving comments for the operation"
                note "In the next slide you'll be asked if you'd like to leave any comments for the operation. Examples of appropriate comments include:"
                bullet "Insects present in the room"
                bullet "Any issue with lights or humidifiers"
            end
        end
        
        # show do 
        #     title "Close up the growth racks"
        #     note "Close up the growth racks by re-fastening the bungee cords as they were when you came into the room"
        #     note "Now you're done :)"
        # end
        
        op_comments
        
        operations.each do |op|
            op.change_status "waiting"
        end
    end
end
