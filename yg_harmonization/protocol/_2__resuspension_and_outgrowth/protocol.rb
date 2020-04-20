# By: Eriberto Lopez
# elopez3@uw.edu
# 02/05/2018
# Updated 08/15/18
needs "Tissue Culture Libs/CollectionDisplay"
needs "Standard Libs/Debug" # Used for printing out objects for debugging purposes
needs "YG_Harmonization/HighThroughput_Lib"
needs "YG_Harmonization/BiotekPlateReaderCalibration"
needs "YG_Harmonization/YG_Controls"

class Protocol
  include CollectionDisplay
  include Debug
  include HighThroughput_Lib, BiotekPlateReaderCalibration, YG_Controls
  
  # I/O
  INPUT = "Yeast Plate"
  OUTPUT = "96 Well Flat Bottom"
  CAL_PLATE = "Calibration Plate"
  BIO_REPS = "Biological Replicates"
  
  # Constants
  WELL_VOL = 200#ul
  PLT_LOC = "Under the Flow Cytometer"
  POSITIVE_GFP_WELL = "H9"
  
    def main
        
        operations.make
        
        intro
        
        gather_materials
        
        need_to_create_new_control_plate = 'No'
        
        # For each input_array of Yeast Plates
        operations.each do |op|
            plates = op.input_array(INPUT).items.flatten
            
            out_coll = op.output(OUTPUT).collection
            
            bio_reps = op.input(BIO_REPS).val.to_i
            
            # Empty collection matrix
            out_coll = blank_collection_mat(out_coll) # Highthroughput lib
            
            # Fill empty collection matrix with sample ids from input items using the amount of bio_reps given by parameter
            out_coll = fill_collection_mat(out_coll, plates, bio_reps) # Highthroughput lib
            
            # Associate the bio_reps parameter to the output collection
            Item.find(out_coll).associate 'bio_reps'.to_sym, bio_reps
            
            # Resuspend the number of bio_rep colonies from each plate in the input plate array 
            need_to_create_new_control_plate = resuspension(out_coll, plates, bio_reps)
            log_info 'need_to_create_new_control_plate', need_to_create_new_control_plate
        end
        
        # Outgrowth for 1hr
        outgrowth
        
        # Check to see if the previous calibration plate is less than a month old, if so reuse
        cal_plate = operations.map {|op| op.output(CAL_PLATE).collection}.first # we do one in batched mode
        create_a_cal_plt, calibration_plate = check_cal_plate_date()
        log_info 'create_a_cal_plt, calibration_plate',create_a_cal_plt, calibration_plate
        # If Calibration plate is >1 month then create a new cal plate else use the cal plate made and delete the ones that this protocol .makes
        if create_a_cal_plt || calibration_plate.nil?
            create_cal_plate(cal_plate)
        else
            take [calibration_plate], interactive: true
            operations.map {|op| op.output(CAL_PLATE).collection.mark_as_deleted}
        end
        
        # Extract information from calibration plate and associate to item/collection - LUDOX factor, GFP Standard curve function
        measure_cal_plate(cal_plate)
        
        # Do we need to create a new control plate(s)?
        if need_to_create_new_control_plate == 'No'
            # TODO: Produce new postive_gfp control Yeast Plate - show block if this gets executed - Have tech create plate here. Or spin out an operation that will streak out new plate
            # With a positive control flag, for future look ups
            show {warning "Before finishing inform a Manager that a new gfp control plate must be created using strain <b>Sample_id: 6390</b>"}
        end
        
        # Clean up
        plates = operations.map {|op| op.input_array(INPUT).items.map {|plate| plate}}.flatten.to_a
        cleaning_up(plates)
        
        if debug
            operations.each do |op|
                show do
                    title "input plate associations"
                    op.input_array("Yeast Plate").each do |input|
                        note "#{AssociationMap.new(input.item)}"
                    end
                end
                show do
                    title "output 96 associations"
                    table AssociationMap.new(op.output("96 Well Flat Bottom").collection).get_data_matrix
                end
            end
        end
        
        return {}
    end # Main
    
    
    
    def intro()
        show do 
            title "Resuspension and Outgrowth"
            separator
            note "This protocol will instruct you on how to begin a high throughput experiment."
            note "We will be starting cultures from single colonies then, incubating them in liquid media before the beginning of the experiment."
            note "This is done to keep cells in a logarithmic physiological state where growth and metabolic activity are at their peak."
            note "<b>1.</b> Fill 96 Well Flat Bottom with media."
            note "<b>2.</b> Inoculate single colonies to single wells in 96 well plate."
            note "<b>3.</b> Incubate plate on shaker for 1hr."
        end
    end
    
    def gather_materials()
        output_container = operations.map {|op| op.output(OUTPUT).item.object_type.name}.first
        show do
            title "Gather Materials"
            separator
            note "Gather the following materials:"
            check "<b>#{operations.length}</b> - #{output_container}" 
            check "Synthetic Complete liquid media"
            check "P20 tips"
            check "Multichannel Pipette"
            check "Multichannel Reservoir"
        end
    end
    
    # Guides technician to inoculate a 96 well plate with single colonies
    #
    # @params collection [collection] collection to be filled with media and yeast colonies
    # @params bio_reps [integer] the number of colonies that are to be picked from an input item
    def resuspension(collection, items, bio_reps)
        
        samp_id_to_item_hash = samp_id_to_item_hash(items)
        
        media_vol = ((items.length * bio_reps * (WELL_VOL + 5))/1000.0).round(2) # a little extra media per well to not run out in reservoir 
        
        rc_list = collection.get_non_empty
        
        # add well for GFP positive control - H9
        rc_list.push(find_rc_from_alpha_coord(alpha_coord=POSITIVE_GFP_WELL).flatten)
        
        show do
            title "Fill 96 Well Plate for Inoculation"
            separator
            check "Grab a clean Black Costar 96 Well Clear Flat Bottom Plate and label: #<b>#{collection}</b>"
            note "You can find the plates <b>#{PLT_LOC}</b>"
            check "You will need <b>#{media_vol.to_f} mLs</b> of SC media"
            separator
            note "Follow table below and fill 96 well plate with the following volume of SC media:"
            table highlight_alpha_rc(collection, rc_list){|r,c| "#{WELL_VOL}µl"}
        end
        
        take(items, interactive: true)
        
        show do
            title "Inoculate 96 Well Plate"
            
            note "Using a P20 pipette set to 5 µl, pick a single colony from the plate and resuspend it in the corresponding well."
            separator
            note "Follow table below and inoculate the 96 well plate with single colonies corresponding to the item id:"
            table highlight_alpha_non_empty(collection){|r,c| samp_id_to_item_hash[collection.matrix[r][c]]} 
            # check "<b>Finally, place clear lid on top and tape shut before placing it on the plate shaker.</b>"
        end
        
        # Adding controls to plate
        need_to_create_new_control_plate = adding_positive_gfp_control(collection, well=POSITIVE_GFP_WELL) # YG_Controls
        
        collection.move "30 C incubator; Plate Shaker @ 800rpm"
        release([collection], interactive: true)
        return need_to_create_new_control_plate
    end
    
    # Starts a timer for outgrowth after colonies have been resuspended in liquid media
    #
    # @params items [input_array] agar plates that were used to fill 96 well flat bottom
    def outgrowth()
        show do
            title "Outgrowth"
            separator
            check "Start 1hr timer"
            note"<a href='https://www.google.com/search?q=1+hr+timer&oq=1+hr+timer&aqs=chrome..69i57j0l5.1684j0j7&sourceid=chrome&es_sm=122&ie=UTF-8#q=1+hour+timer' target='_blank'>
                Set a 1 hr timer on Google</a> to start the yeast outgrowth and to set a reminder to retrieve the flat bottom plate from the shaker."
            note "Then, proceed to the next slide."
        end
    end

    # Creates a sample id to item id hash
    #
    # @params plates [array] input array of plate item ids 
    # @return samp_item_id_hsh [hash] a hash of sample ids to item ids
    def samp_id_to_item_hash(items)
        samp_id_to_item_hash = Hash.new()
        items.each {|i| samp_id_to_item_hash[Item.find(i).sample_id] = i.id}
        return samp_id_to_item_hash
    end
    
    def cleaning_up(items)
        clean_up = show do
            title "Cleaning Up"
            separator
            check "<b>Double check with Lab Manager whether to parafilm and save plates or to dispose in the biohazard bin.</b>"
            select ['Yes', 'No'], var: "keep_plates", label: "Do we want to save and store plates?", default: 0
        end
        clean_up[:keep_plates] == 'Yes' ? release(items, interactive: true) : items.each {|item| item.mark_as_deleted}
    end
    
end # Class