# Library code hereneeds "Standard Libs/Debug"
needs 'SynAg/Container_methods'
needs 'Tissue Culture Libs/CollectionDisplay'



module DilutionProtocol

    include GatherPlate
    include CollectionDisplay
    
        CYTOMETER = "BD Accuri C6"
        MEDIA = "SC"
        END_VOLUME = 2000 #ul
 
        
        INPUT ="Plate"
        OUTPUT ="Culture"
        
     
    
    def dilute_to_defined_density operations
        
          
        sc = Item.where(object_type_id: ObjectType.find_by_name("800 mL Liquid").id, sample_id: 11769).reject { |i| i.location == "deleted" }.first
        
        divided_plate_ops = operations.select {|op| op.input(INPUT).item.object_type.name == "Divided Yeast Plate"}
        
        unless debug
            operations.select {|op| op.input(INPUT).item.object_type.name == "Yeast Plate"}.each do |op|
                if op.input(INPUT).item.get(:num_colonies).nil?
                    op.error :no_colony_count, "This plate lacks a colony count. Submit a Check Plate operation."
                    show do 
                        title "Yeast plate #{op.input(INPUT).item.id} lacks a colony count"
                        note "Operation #{op.id} has been errored. Please submit a check plate operation and then try again"
                    end
                end
            end
        end
        
        yeast_plate_ops = operations.running.select {|op| op.input(INPUT).item.object_type.name == "Yeast Plate"}
        
        operations.retrieve.make
        
       rows = ['A','B','C','D','E','F','G','H']
       columns = [1,2,3,4,5,6,7,8,9,10,11,12]
       well_array = []
       rows.each{|r| columns.each{|c| well_array.push(r+c.to_s)}}
        
        n=0
        operations.each do |op|
            op.associate :well, well_array[n]
            n = n + 1
        end
        
        show do 
            title "Get liquid media"
            note "Take a small beaker from the clean labware rack"
            check "Remove the foil lid from the beaker but keep it to hand"
            check "From Bottle #{sc.id} pour #{(operations.length * ((END_VOLUME / 1000) + 0.5 ) + 1)} mL of SC into the beaker"
            check "Replace the foil lid over the beaker to keep out contaminations"
        end
        
        show do 
            title "Label 1.5 mL tubes"
            check "Take #{operations.length} 1.5 mL tubes and lay out on a tube rack"
            check "Label with the following IDs:"
            table operations.start_table
                .custom_column(heading: "Tube label") {|op| op.get(:well)}
                .end_table
        end
        
        show do 
            title "Add #{MEDIA} to each tube"
            check "Using a p1000 pipette, add 500 µl sterile #{MEDIA} into each 1.5 mL tube"
            note "Take the SC media from the beaker of SC prepared earlier. Recover with foil after use."
            table operations.start_table
                .custom_column(heading: "Tube label") {|op|  op.get(:well)}
                .end_table
        end
        
        #Add colonies from divided yeast plates
        
        unless divided_plate_ops.empty?
            show do 
                title "Suspend colonies from divided yeast plates in tubes"
                note "Using a p10 tip, pick a single colony (whole colony) and resuspend it into the 1.5 mL tube"
                table divided_plate_ops.start_table
                            .input_collection(INPUT, heading: "Divided Yeast Plate")
                            .custom_column(heading: "Section") {|op| (op.input(INPUT).column) + 1}
                            .custom_column(heading: "Tube label") {|op|  op.get(:well)}
                            .end_table
                check "Vortex tubes till evenly resuspended"
            end
        end
        
        #Add colonies from non-divided yeast plates
        unless yeast_plate_ops.empty?
            show do 
                title "Suspend colonies from yeast plates"
                note "In each case use a marker pen to draw a circle around the picked colony and write the number indicated next to the circle"
                 table yeast_plate_ops.start_table
                            .input_item(INPUT, heading: "Yeast Plate")
                            .custom_column(heading: "Transfer colony") { "Whole colony"}
                            .custom_column(heading: "Tube label") {|op|  op.get(:well)}
                            .custom_column(heading: "Colony Label"){|op| op.output(OUTPUT).item.id}
                            .end_table
                note "Vortex tubes till evenly resuspended"
            end
        end
        
        
        get_plate(true, 1)
        
        ##The next block has a hacky solution to create instructions for well assignments and associate it with the item. But no 'plate' item is created. 
        
            sample_list = []
            operations.each do |op|
                sample_list.push(op.input(INPUT).sample.id)
            end
            
            #This line creates a 96 well plate collection from my input array. Actually it creates an array of collections.
            dilution_plate = Collection.spread(sample_list, "96 U-bottom Well Plate")
            
            alpha_table = {}
            ((0..7).zip('A'..'H')).each { |x| alpha_table[x[0]] = x[1] }
                        
            # Here I am making a new hash to fill with the well locations for each sample. 
            operations.each do |op|
                s = op.input(INPUT).sample.id
                plate_location = dilution_plate[0].find(s)
                plate_location_alpha = plate_location.flat_map{ |r,c| [[alpha_table[r], c + 1]]}
                plate_location_simple = plate_location_alpha.flat_map{ |r,c| "#{r}#{c}"}
                op.associate :dilution_plate_well, plate_location_simple
            end
        
        
        
        show do 
            title "Load samples into a 96 well assay plate:"
            note "100 µl into each well according to the following table"
            table operations.start_table
                .custom_column(heading: "1. 5 mL tube"){|op| op.get(:well)}
                .custom_column(heading: "100 µl into well"){|op| op.get(:well)}
                .end_table
        end
        
        show do 
            title "Ready the Cytometer"
            check "Is the sheath fluid above the 'refill' mark? If not then refill with the bottle in the drawer under the cytometer and then refill that bottle (ask lab manager for help)"
            check "Is the waste below the empty mark? If not empty the waste into the sink and then reattach."
            check "Open up the BD Accuri C6 software"
        end
        
        show do 
            title "Set up the workspace"
            note "Likely the scren will show 'Run finished' from the completion of the last Clean cycle. Close that and in the top left on the toolbar select File> Open Workspace or Template"
            note "Don't save the current workspace"
            check "Open Documents > Aquarium > 96_well_u_bottom_yeast_cytometry_template.c6t"
            check "Navigate to 'Auto Collect' in the tabs at the tab at the top of the page (manual, automatic,analysis,statistics)"
            check "Select the following wells:"
            table highlight_alpha_non_empty(dilution_plate[0])
            check "Check that Fluidics are set to Medium"
            check "Check that Run limits are selected (10,000 events, 30 µL, 1 minute)"
            check "Apply the settings."
            check "Save the workspace as Documents > Biofab_culture_densities > #{DateTime.now.month}#{DateTime.now.day}#{DateTime.now.year}"
            check "You will see the selected wells turn from white to a block color"
        end
        
        show do 
            title "Run the plate"
            check "Press 'Eject Plate'"
            check  "Load the 96 well plate and press 'Load Plate'"
            check "Open run display"
            check "Autorun"
            note "Stay by the cytometer in case of any errors arising. If an error arises alert a lab manager"
            note "This run should take from #{operations.length*0.5} to #{operations.length} minutes to complete"
        end
        
        
        
       read_results = show do 
            title "Upload events per µl"
            note "Close the 'Run complete' alert, and navigate at the top of the page to 'Statistics'. Here select 'Events per µl' at the top and then select 'All Samples' along the side ('Add to Table'). Enter results below"
              table operations.start_table
                .custom_column(heading: "Well") { |op| op.get(:well)}
                .get(:concentration, type: "number", heading: "Events per µl", default: 5000) 
                .end_table
        end
    
        
        ##THIS BLOCK ISN' WORKING. I'M NOT ACCESSING THE DATA IN THE TABLE CORRECTLY. I NEED TO GO THROUGH THAT WITH ABE
        operations.each do |op|
            startpoint = read_results.get_table_response(:concentration, op: op)
            density_goal = op.get(:density_goal)
            if debug then startpoint = 5000.0 end
            µl_to_dilute = ((density_goal / startpoint) * END_VOLUME).to_f.ceil
            op.associate :ul_to_dilute,  µl_to_dilute
        end
        
        show do 
            title "Run a clean cycle"
            check "Are there at least 500µl of C,D and S solution? If not top them up"
            warning "If you don't know what you are doing, ask for assistance from a lab manager"
            check "Eject the 96 well plate"
            check "Load the cleaning plate"
            check "Load the template (Documents > Aquarium > Cleaning_cycle.c6t)"
            check "Run (overwrite the existing file)"
        end
        
        show do 
            title "Gather and label glass culture tubes"
            note "In the media bay"
            check "Take #{operations.length} 14 mL glass culture tubes and a rack"
            note "Label with the following IDs:"
            table operations.start_table
                .output_item(OUTPUT, heading: "Tube label", checkable: true)
                .end_table
        end
        
        show do 
            title "Add medium to culture tubes"
            note "Use a seriological pipette and pipetteboy"
            table operations.start_table
                .output_item(OUTPUT, heading: "Tube label", checkable: true)
                .custom_column(heading: "Add medium") {"#{END_VOLUME / 1000} mL of SC medium"}
                .end_table
        end
        
        show do
            title "Prepare overnight dilutions"
            check "Vortex all the  1.5 mL tubes at your bench. The yeast will have settled by now"
            note "Prepare the following overnights"
                table operations.start_table
                    .custom_column(heading: "1.5 mL tube") { |op| op.output(OUTPUT).item.id}
                    .custom_column(heading: "Label 14 mL glass tube") { |op| op.output(OUTPUT).item.id}
                    .custom_column(heading: "µl of Yeast from 1.5 mL tube"){|op| op.get(:ul_to_dilute)}
                    .end_table
            check "Place tubes in the 30°C Shaking incubator"
        end
        
        return_plate(true, 1)
        
        show do 
            title "Clean up"
            check "Place tubes in the 30°C shaking incubator"
            check "Discard the #{operations.length} 1.5 mL tubes"
            check "Discard used seriological pipette in the Black waste bin"
            check "Place beaker used to hold SC medium into the blue cleaning bin by the sink"
        end
        
        
        operations.each do |op|
            op.output(OUTPUT).item.location = "30C incubator"
            op.output(OUTPUT).item.store
        end
        
        #Store inputs only
        operations.store(io: 'input', interactive: true)
    
        {}
    
     end

end


