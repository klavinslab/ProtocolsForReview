# By: Eriberto Lopez 06/11/2018
# elopez3@uw.edu
# µl


needs "Standard Libs/Debug"
needs "Standard Libs/UploadHelper"
needs "Plate Reader/PlateReaderHelper"
needs "Tissue Culture Libs/CollectionDisplay"
needs 'YG_Harmonization/Upload_PlateReader_Data'

class Protocol

    require 'date'
    
    # Standard Libs
    include Debug, UploadHelper
    
    
    # Other Libs
    include CollectionDisplay
    include PlateReaderHelper
    # include Upload_PlateReader_Data
    
    # I/O
    INPUT = "96 Deep Well Plate"
    OUTPUT = "96 Well Flat Bottom Plate"
    
    # Parameters
    CULT_VOL = 'Volume from Culture (µl)'
    MEDIA_VOL = 'Volume of Media (µl)'
    MEASUREMENT_TYPE = 'Type of Measurement(s)'
    MEDIA_TYPE = 'Type of Media'
    KEEP_OUT_PLT = "Keep Output Plate?"
    
    # Constants
    TEMPLATE_FILENAME = {'OD'=>'OD600_GFP_measurement', 'OD_GFP'=>'OD600_GFP_measurement', 'CAL_OD_GFP'=>'calibration_template_v1'} # always collect both OD & GFP and decide which to export
    MEASUREMENTS = {'OD'=>['od'], 'OD_GFP'=>['od','gfp'], 'CAL_OD_GFP'=>['cal_od', 'cal_gfp']}

    def main
        
        # If samples have already been added to a 96 well flat bottom (black) plate
        input_object_type = operations.first.input(INPUT).item.object_type.name
        type_of_measurement = operations.first.input(MEASUREMENT_TYPE).val.to_s
        
        log_info 'type_of_measurement', type_of_measurement
        
        # Make output collection if the input is not a 96 flat bottom or if the measurement is not a calibration
        if (input_object_type != '96 Well Flat Bottom (black)') && (type_of_measurement != "CAL_OD_GFP")
            operations.make
        end
        
        measurement_intro() 
        
        operations.each do |op|
            
            in_collection = op.input(INPUT).collection
            out_collection = op.output(OUTPUT).collection


            if type_of_measurement == "CAL_OD_GFP"
                # Creating new collection to which calibration data will be assoacited to
                input_object_type = '96 Well Flat Bottom (black)'
                container = ObjectType.find_by_name(input_object_type)
                
                cal_plate = produce new_collection container.name
                log_info 'Produced cal_plate collection', cal_plate.id
                create_cal_plate(cal_plate)
            end
            
            # Samples from a 96 deep well plate if the input collection is not already in a 96 flat bottom plae or if the type of measurement is not a calibration measurement
            if (input_object_type != '96 Well Flat Bottom (black)') && (type_of_measurement != "CAL_OD_GFP")
                # Transferring sample id matrix
                in_coll_matrix = in_collection.matrix
                out_collection.matrix = in_coll_matrix
                out_collection.save
                
                record_plate_provenance_parallel_transfer(in_collection, out_collection)
                
                prefill_media(op) # Prefills output plate with parameter vol media
                
                take [Item.find(op.input(INPUT).collection.id)], interactive: true
                
                transfer_culture(op) # Transfers cultures from input plate to output plate reader plate that has been prefilled with media
                
                release [Item.find(op.input(INPUT).collection.id)], interactive: true # Returns 96 deep well plate to incubator right after it has been sampled
            end
            
            tot_vol = op.input(CULT_VOL).val.to_i + op.input(MEDIA_VOL).val.to_i # total well volume of culture + media
            # Finds wells that are empty and fills them with blank slected media OR one can specify which wells they would like to use for media
            if (type_of_measurement != "CAL_OD_GFP") # We do not need to add blanks to a calibration plate
                if (input_object_type != '96 Well Flat Bottom (black)')
                    add_blanks(collection=out_collection, type_of_media=op.input(MEDIA_TYPE).val.to_s, tot_vol=tot_vol, blank_wells=nil)
                else
                    add_blanks(collection=in_collection, type_of_media=op.input(MEDIA_TYPE).val.to_s, tot_vol=tot_vol, blank_wells=nil)
                end
            end
            
            # Setup BioTek HT PlateReader workspace to collect measurement
            if (input_object_type != '96 Well Flat Bottom (black)')
                filename = set_up_plate_reader(out_collection, TEMPLATE_FILENAME[type_of_measurement])
            else
                filename = set_up_plate_reader(in_collection, TEMPLATE_FILENAME[type_of_measurement])
            end
            
            # Export measurements taken, upload, and associate data
            MEASUREMENTS[type_of_measurement].each do |method|
                if (type_of_measurement != "CAL_OD_GFP")
                    if (input_object_type != '96 Well Flat Bottom (black)')
                        filename = export_filename(out_collection, method, timepoint=nil)
                    else
                        filename = export_filename(in_collection, method, timepoint=nil)
                    end
                else
                    filename = export_filename(cal_plate, method, timepoint=nil)
                end
                
                export_plate_reader_data(filename, method) # Directs tech how to save and export plate reader data from the BioTek HT 
                
                # Show block upload button and retrieval of file uploaded
                up_show, up_sym = upload_show(filename)
                if (up_show[up_sym].nil?)
                    show {warning "No upload found for #{method} measurements. Try again!!!"}
                    up_show, up_sym = upload_show(filename)
                else
                    time = Time.now
                    upload = find_upload_from_show(up_show, up_sym)
                    
                    if (type_of_measurement != "CAL_OD_GFP")
                        if (input_object_type != '96 Well Flat Bottom (black)')
                            key = "Item_#{out_collection.id}_#{method.upcase}_#{time.strftime "%Y%m%d_%H:%M"}"
                        else
                            key = "Item_#{in_collection.id}_#{method.upcase}_#{time.strftime "%Y%m%d_%H:%M"}"
                        end
                    else # Calibration measurement key
                        key = "Calibration_#{cal_plate.id}_#{method.upcase}_#{time.strftime "%Y%m%d_%H%M"}"
                    end
                    
                    if (type_of_measurement != "CAL_OD_GFP")
                        # Associates upload to in and out collections
                        associate_to_item(in_collection, key, upload)
                        if (input_object_type != '96 Well Flat Bottom (black)')
                            associate_to_item(out_collection, key, upload)
                        end
                    else
                        log_info 'cal plate data association'
                        associate_to_item(cal_plate, key, upload)
                        
                    end
                    
                    # Associates upload to plan
                    # associate_to_plans(key, upload) # For some reason, this associates the upload object to the plan, but as an object and not as a clickable link to download
                    associate_to_plan(upload, key)
                    
                    # Account for dilution and associate plate reader data to item data associations as a matrix
                    dilution_factor = (op.input(CULT_VOL).val.to_f + op.input(MEDIA_VOL).val.to_f)/op.input(CULT_VOL).val.to_f
                    
                    if (type_of_measurement != "CAL_OD_GFP")
                        # Associates data hash of measurements to item/collection
                        associate_PlateReader_measurements(upload, in_collection, method, dilution_factor)
                        if (input_object_type != '96 Well Flat Bottom (black)')
                            associate_PlateReader_measurements(upload, out_collection, method, dilution_factor)
                        end
                    else
                        associate_PlateReader_Data(upload, cal_plate, method, timepoint=nil)
                    end
                    
                    
                    
                end
            end
            
            # show{note"#{op.input(KEEP_OUT_PLT).val.to_s == "Yes"}"}
            # Keeping the output plate?
            if (type_of_measurement != 'CAL_OD_GFP')
                if (input_object_type != '96 Well Flat Bottom (black)')
                    (op.input(KEEP_OUT_PLT).val.to_s == "Yes") ? (out_collection.location = "BioTek Plate Reader") : (out_collection.mark_as_deleted) # Deletes input collection
                    out_collection.save
                    (op.input(KEEP_OUT_PLT).val.to_s == "Yes") ?  (nil): (cleaning_up(out_collection))
                else
                    (op.input(KEEP_OUT_PLT).val.to_s == "Yes") ? (in_collection.location = "BioTek Plate Reader") : (in_collection.mark_as_deleted) # Deletes input collection
                    (op.input(KEEP_OUT_PLT).val.to_s == "Yes") ?  (nil): (cleaning_up(in_collection))
                end
            else
                time = Time.now
                todays_date = time.strftime "%Y%m%d"
                cal_plate.location = "4C Fridge"
                cal_plate.save
                show {
                    title "Cleaning Up.."  # Calibration plate items 
                    separator
                    note "Before finishing up the protocol, clean up put back reagents."
                    check "Make sure Calibration Plate is labeled with today's date: <b>#{todays_date}</b>"
                    check "Place in the 4C deli fridge. <b>If there are more than 3 plates, then throw out the oldest one.</b>"
                }
                
            end
            
            
        end
        
        return {}
        
    end # Main

    def measurement_intro()
        show do
            title "Plate Reader Measurements"
            
            note "This protocol will instruct you on how to take measurements on the BioTek Plate Reader."
            note "ODs are a quick and easy way to measure the growth rate of your culture."
            note "GFP measurements help researchers assess a response to a biological condition <i>in vivo</i>."
            note "<b>1.</b> Transfer culture to plate reader plate and add blank."
            note "<b>2.</b> Setup plate reader workspace."
            note "<b>3.</b> Take measurement, save data, & upload."
        end
    end
  
    def cleaning_up(item)
        show do 
            title "Cleaning Up..."
            separator
            note "Before finishing up, rinse out plate <b>#{item}</b> with diluted bleach & H2O."
            note "Then rinse once more with EtOH"
        end
    end
    
    def transfer_culture(op)
        input_plate = "#{op.input(INPUT).item.object_type.name} #{op.input(INPUT).item.id}"
        output_plate = "#{op.output(OUTPUT).item.object_type.name} #{op.output(OUTPUT).item.id}"
        cult_vol = op.input(CULT_VOL).val.to_i
        show {
          title "Transfer Culture Aliquots to Plate for Reader" 
          separator
          check "Use a multi-channel pipettor to transfer <b>#{cult_vol}µl</b> from <b>#{input_plate}</b> to the <b>#{output_plate}</b>."
        }
    end
    
    def prefill_media(op)
        output_obj_type = op.output(OUTPUT).item.object_type.name
        media_vol = op.input(MEDIA_VOL).val.to_i#µl
        type_of_media = op.input(MEDIA_TYPE).val
        # log_info 'media_vol', media_vol
        show {
            (media_vol == 0) ? (title "Prepare Measurement #{output_obj_type}") : (title "Fill #{output_obj_type} with #{type_of_media} Media")
            separator
            check "Grab a clean <b>#{output_obj_type}</b>."
            check "Label the #{output_obj_type} => <b>#{op.output(OUTPUT).item.id}</b>."
            if (media_vol != 0)
                bullet "Follow the table below to fill the plate with the appropriate volume and <b>#{type_of_media}</b> liquid media."
                table highlight_non_empty(op.input(INPUT).collection) {|r,c| "#{media_vol}µl"}
            end
        }
    end
    
    
    def record_plate_provenance_parallel_transfer(in_plate, out_plate)
        out_plate_associations = AssociationMap.new(out_plate)
        in_plate_associations = AssociationMap.new(in_plate)
        out_plate.dimensions[0].times do |r_idx|
          out_plate.dimensions[1].times do |c_idx|
            if (in_plate.part(r_idx, c_idx))
              add_provenance({
                  from: in_plate, 
                  from_map: in_plate_associations,
                  from_coord: [r_idx, c_idx],
                  to: out_plate,
                  to_coord: [r_idx, c_idx],
                  to_map: out_plate_associations
              })
            end
          end
        end
        out_plate_associations.save
        in_plate_associations.save
    end

    
end # Class
