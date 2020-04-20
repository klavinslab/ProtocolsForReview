needs 'Flow Cytometry/Inducer_plate_libs'

class Protocol
    
include Dilutions

#Sample input and output names
INPUT = "Strains (8 max)"
OUTPUT = "Plate"
PARAMETER = "Inducer and range"

#Defining 'pseudoitems' that can 
ASSAY_PLATE = {object_type_name: "96 well U-bottomed Assay Plate", location: "Nearest the door to the lab, in the final row belonging to the Klavins lab"}
DEEPWELL_PLATE = {object_type_name: "96 well Eppendorf Deepwell Plate", location: "Cupboard under Cami's bench"}
INCUBATOR = {name: "Large 30C incubator I1", location: "In third BIOFAB bay"}

#Relevant file constants
CLEAN_CYCLE = 'Documents > CleanRegular_c6t'
DESTINATION_FOLDER = 'Documents > BIOFAB_Yeast_Inducer_Plate_Assay'


  def main
    
    if operations.length > 1
        show do
            title "Rerun operations separately"
            warning "Please cancel this job, and rerun each Operation as it's own Job"
            note "This Protocol is designed for use with one Operation at a time. This is because of the length of
            time required to set up each plate. Each plate must be set up and then measured in the cytometer 5 hours later,
            with as little deviation from this timing as possible."
        end
    end
    
    operations.each do |op|
        if op.input(PARAMETER).val == "Beta-estradiol (to 100 nM)" then inducer = "be" and units = 'nM' end
        if op.input(PARAMETER).val == "Coronatine (to 15 uM)" then inducer = "coronatine" and units = 'uM' end
        
        show do 
            title "Summary of this protocol"
            note "Step 1: Set up 96-well plate and place in 30C incubator for 90 minutes"
            note "Step 2: After 60 minutes set up inducer series, then wait a further 30 minutes"
            note "Step 3: Add inducer to yeast plate, then incubate for a further 100 minutes"
            note "Step 4: Transfer from deepwell to assay plate"
            note "Step 5: Run assay plate in the Flow cytometer"
            note "Ensure Flow cytometer is reserved for at least one hour, beginning 3 hours from now"
        end
        
        #########################################
        
        operations.retrieve.make
        
        ##########################################
        #SECTION 1
        #DILUTE YEAST FROM OVERNIGHTS
        
        # plate_key = inducer_plate_set_up(op.input_array(INPUT).item_ids, op.input_array(INPUT).sample_ids, inducer)
        # op.associate(:plate_scheme, plate_key)
        items = op.input_array(INPUT).item_ids
        densities = items.map{ |i| 10000}
        
        sc_needed = 0
        items_wells = []
        yeast_vol = 25
        sc_vol = 975
        concentrations = 10
        sc_needed = sc_vol * concentrations * items.length + 500
    
        possible_rows = ('A'..'H').to_a
        rows_in_use = possible_rows[0..(items.length - 1)]
        well_summary = rows_in_use.map{|r| "Row " + r + ", wells 1 - 10"}
        
        show do
            title "Retrieve SC medium"
            note "#{(sc_needed / 1000).round(1)} mL of SC medium into a clean reagent reservoir"
        end
        
        show do 
            title "Retrieve 96 well plate"
            note "Take a sterile #{DEEPWELL_PLATE[:object_type_name]}, from #{DEEPWELL_PLATE[:location]}"
            check "Label the plate #{op.output(OUTPUT).collection.id}"
        end
        
        show do 
            title "Add 975 uL SC to each relevant well"
            note " Add 975 uL SC to each well noted below. Use the p1000 multichannel."
            items.each do |i|
                check "#{well_summary[items.index(i)]}"
            end
        end
        
                
        yeast_item_table = Table.new(
              a: "Plate Row",
              b: "Wells",
              c: "Yeast overnight ID",
              d: "Volume of yeast overnight (µl)"
            )
            
        items.each do |i|
            yeast_item_table.a(rows_in_use[items.index(i)]).b("1 - 10").c(i).d("25").append
        end
            
        show do 
            title "Add Yeast"
            note "Use a multi-stepper with 0.5 mL tip for this task"
            table yeast_item_table
        end
        
        show do 
            title "Place in shaker incubator"
            note "Place an AreaSeal on the plate, label with #{op.id} and secure  plate into the shaker in the #{INCUBATOR[:name]} in #{INCUBATOR[:location]}"
            timer initial: { hours: 0, minutes: 60, seconds: 00}
        end
        
       ######################################### 
        #SECTION 2
        #PREPARE INDUCER SERIES AND ADD TO PLATE  
        show do 
            title "Summary of next steps"
            note "In the next steps you will prepare an inducer series to add to the yeast plate prepared earlier"
            note "This will take approx 30 minutes, but if you are finished quicker than this wait till the timer is finished, to ensure the yeast have had sufficient time to enter log phase growth"
             timer initial: { hours: 0, minutes: 30, seconds: 00} 
        end
        
        concs = inducer_series(inducer, items.length)
    
        
        show do
            title "Retrieve plate"
            note "Only proceed if the 30 minute timer is done"
            note "Retrieve 96-well plate labelled #{op.id} from ther 30C Shaker incubator"
            note "Remove the Aeraseal and place to one side"
        end
        
        #This block creates a table to guide the addition of inducer to the relevant wells
        possible_rows = ('A'..'H').to_a
        rows_in_use = possible_rows[0..(items.length - 1)]
        inducer_wells = (1..10).to_a
        transfer_wells = []
        inducer_wells.each do |i|
            r_wells = []
                rows_in_use.each do |r|
                    r_wells.push("#{r}#{i}")
                end
            transfer_wells.push(r_wells)
        end
        
        inducer_transfer_table = Table.new(
              a: "Inducer well",
              b: "Volume to transfer",
              c: "Plate wells to transfer to"
            )
            
        inducer_wells.each do |i|
            inducer_transfer_table.a(i).b("1 µL").c(transfer_wells[i - 1]).append
        end
            
            
        show do 
            title "Add inducer to plate"
            note "Use a p10 multichannel pipette to make the following transfers"
            warning "It's easy to mis-pipette with the p10 multichannel, visually inspect the volume in each well every time you make a trnasfer"
            table inducer_transfer_table 
        end
        
        show do
            title "Place plate back in incubator"
            check "Re-seal plate with Aeraseal (from draw under the flow cytometer')"
            note "Secure deepwell plate into the shaker in the #{INCUBATOR[:name]} in #{INCUBATOR[:location]}"
        end
        
        show do 
            title "Set up a 100 minute timer"
            timer initial: { hours: 0, minutes: 100, seconds: 00}
        end
        
        show do
            title "Clean up"
            note "Place yeast overnight suspension items into the cleaning tub by the sink"
            note "Clear your work area"
        end
        
        #############################################
        #SECTION 3 
        #ASSOCIATE PLATE DATA WITH OPERATION FOR LATER RETRIEVAL WITH TRIDENT
        #Will associate an array with each well on the plate
        #[Strain_id, Inducer, units, concentration]
        
        #Create an array with all the wells on the plate
        wells_on_plate = []
        columns = ['01','02','03','04','05','06','07','08','09','10']
        rows_in_use.each do |r|
            row_columns = columns.map{|c| r + c}
            wells_on_plate.push(row_columns)
        end
        
        wells_on_plate = wells_on_plate.flatten
        
        plate_rows = ('A'..'H').to_a
        columns = ['01','02','03','04','05','06','07','08','09','10']
        plate_metadata = {}
        n = 0
        op.input_array(INPUT).sample_ids.each do |s|
            sample_wells = columns.map{|c| plate_rows[n] + c}
            t = 1
            sample_wells.each do |w|
                plate_metadata[w.to_sym] = [s,inducer,units,concs[t]]
                t = t + 1
            end
        n = n + 1
        
        op.associate :plate_metadata, plate_metadata
        end
        
        
        ##############################################
        #SECTION 4
        #RUN PLATE IN FLOW CYTOMETER
        show do 
            title "Prepare the Flow Cytometer"
            check "Waste container is less than 75% full? Otherwise empty the waste"
            check "Sheath fluid container is more than 25% full? Otherwise refill"
            check "Open BD Accri C6 software on the computer"
        end
        
        show do 
            title "Enter settings for cytometry run"
            check "Select the following wells"
            note "#{wells_on_plate}"
            check "Speed to 'Medium'"
            check "Run Limits: Volume - 30 uL, Time - 45 seconds, Events - 10,000"
            check "Save file in Folder #{DESTINATION_FOLDER} as 'Yeast Inducer Plate 1 - #{op.user.name} - #{Time.now.strftime("%m/%d/%Y")}"
        end
        
        show do 
            title "Transfer yeast to assay plate"
            check "Retrieve 96 deepwell plate labelled #{op.id} from the 30C shaker incubator"
            check "Retrieve a clean, non-sterile 96-well U-bottom clear assay plate from the draws under the Flow cytometer"
            check "Retrieve the 6-channel p1000 pipette"
            check "Transfer 100 uL from each of the wells of the deepwell plate into the corresponding wells of the assay plate"
            items.each do |i|
                note "#{items_wells[items.index(i)]}"
            end
            warning "Ensure the yeast in the deepwell plate are well mixed by pipetting up and down 3 times before making each transfer"
        end
        
        show do
            title "Return Deepwell plate to incubator"
            check "Replace Areaseal and place Deepwell plate back into the incubator"
        end
        
        show do 
            title "Plate plate in machine and run"
            check "Take assay plate to the cytometer"
            check "Load the plate into the cytometer"
            check "Hit Autorun"
            note "This will take roughly #{items.length*10} minutes and does not need to be attended."
        end
        
        show do 
            title "Remove plate upload data"
            check "Eject plate"
            note "If you are not already, log into Aquarium on the Cytometer laptop and run this step from there"
            note "Export all files as FCS and then from the FCS Exports folder find the most recent directory containing the files you just exported"
            upload {:plate_1}
        end
        
        show do 
            title "Enter settings for cytometry run"
            note "You will now carry out a second reading, with exactly the same parameters as the first"
            check "Select the following wells"
            note "#{wells_on_plate}"
            check "Speed to 'Medium'"
            check "Run Limits: Volume - 30 uL, Time - 45 seconds, Events - 10,000"
            check "Save file in Folder #{DESTINATION_FOLDER} as 'Yeast Inducer Plate <b>2</b> - #{op.user.name} - #{Time.now.strftime("%m/%d/%Y")}"
        end
        
        show do 
            title "Transfer yeast to a second assay plate"
            check "Retrieve 96 deepwell plate labelled #{op.id} from the 30C shaker incubator"
            check "Retrieve a clean 96-well U-bottom clear assay plate from the draws under the Flow cytometer"
            check "Retrieve the 6-channel p1000 pipette"
            check "Transfer 100 uL from each of the wells of the deepwell plate into the corresponding wells of the assay plate"
            items.each do |i|
                note "#{items_wells[items.index(i)]}"
            end
            warning "Ensure the yeast in the deepwell plate are well mixed by pipetting up and down 3 times before making each transfer"
        end
        
        show do 
            title "Plate plate in machine and run"
            check "Take assay plate to the cytometer"
            check "Load the plate into the cytometer"
            check "Hit Autorun"
            note "This will take roughly #{items.length*10} minutes and does not need to be attended."
        end
        
        show do 
            title "Remove plate upload data"
            check "Eject plate"
            note "If you are not already, log into Aquarium on the Cytometer laptop and run this step from there"
            note "Export all files as FCS and then from the FCS Exports folder find the most recent directory containing the files you just exported"
            upload {:plate_2}
        end
    
        show do
            title "Run cleaning cycle"
            note "As always, if you do not feel confident that you understand these directions check with a lab manager"
            check "Eject the assay plate"
            check "Load the cleaning plate. Check that there are three 1.5 mL tubes in there, loaded in the order C->D->S, in wells D4,5,6 (Red sticker indicates A1)."
            check "Run the cleaning cycle (#{CLEAN_CYCLE}). Ensure that you run it on Auto and not Manual collect"
        end
            
        show do 
            title "Discard plate"
            check "Discard Assay plate in the Biohazard waste"
            check "Place 96 well plate in the cleaning bucket by the sink"
        end
        ##############################################
 
    end
    

    {}

  end


end