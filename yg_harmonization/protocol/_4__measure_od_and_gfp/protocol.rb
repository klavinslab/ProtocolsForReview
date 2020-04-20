# By: Eriberto Lopez 11/05/2017
# elopez3@uw.edu
# µl
# Updated: 08/15/18

needs "Yeast Display/YeastDisplayHelper"
needs "Standard Libs/Debug"
needs "YG_Harmonization/PlateReaderMethods"
needs 'YG_Harmonization/Upload_PlateReader_Data'
needs "YG_Harmonization/YG_Measure_OD_GFP"
needs "Standard Libs/AssociationManagement"

class Protocol

    require 'date'
    include YeastDisplayHelper
    include Debug
    include PlateReaderMethods, Upload_PlateReader_Data, YG_Measure_OD_GFP
    include AssociationManagement, PartProvenance
    
    # I/O
    INPUT = "96 Deep Well Plate"
    OUTPUT = "96 Well Flat Bottom Plate"
    CAL_PLATE = 'Calibration Plate'
    
    # Params & Constants
    OD_WAVELENGTH = 600
    TEMPLATE_FILENAME = 'OD600_GFP_measurement' 
    TIMEPOINT = "Timepoint (hr)"
    TRANSFER_VOL = {qty: 300, units: 'µl' }
    MEASUREMENTS = ['od','gfp']

    def main
        
        operations.make
        
        measurement_intro
        
        # For each plate 
        operations.each do |op|
            
            timepoint = get_timepoint(op, TIMEPOINT)
            
            in_item = op.input(INPUT).item
            out_item = op.output(OUTPUT).item
            
            take [in_item], interactive: true
            
            transfer_cultures(in_item, out_item)
            
            media = get_media_type(in_item)
            
            add_blanks(TRANSFER_VOL, media)
            
            set_up_plate_reader(out_item, TEMPLATE_FILENAME)
            in_collection = Collection.find(in_item.id)
            out_collection = Collection.find(out_item.id)
            
            out_collection.matrix = in_collection.matrix
            out_collection.save
            
            record_plate_provenance_parallel_transfer(in_collection, out_collection)

            MEASUREMENTS.each do |method|
                
                filename = export_data(in_collection, timepoint, method=method)
                
                # Show block upload button and retrieval of file uploaded
                up_show, up_sym = upload_show(filename)
                if (up_show[up_sym].nil?)
                    show {warning "No upload found for Time Point #{timepoint} hrs. Try again!!!"}
                    up_show, up_sym = upload_show(filename)
                else
                    upload = find_upload_from_show(up_show, up_sym)
                    key = "#{timepoint}hr_#{method}"
                    
                    # Associates upload to in and out collections
                    # associate_to_item(in_collection,  key, upload) # old association to item
                    # We do not want to associate the upload_obj with the item that is being sampled from
                    # instead we would like to only associate the upload obj with the item that is directly being placed on the instrument
                    associate_to_item(in_collection,  key, upload.id)
                    associate_to_item(out_collection, key, upload)
                    
                    
                    # Associating all files to one plan
                    # associate_to_plan(upload, plan_key) - old version only associates to one plan if batching plans
                    plan = op.plan
                    plan_key = "Item_#{out_collection.id}_#{timepoint}hr_#{method}"
                    plan.associate plan_key, "plan_#{plan.id}", upload
                    
                    # Associates data hash of measurements to item/collection
                    associate_PlateReader_Data(upload, in_collection, method, timepoint)
                    associate_PlateReader_Data(upload, out_collection, method, timepoint)
                end
            end
            
            # cleaning_up(in_collection)
            case op.input('Final Timepoint').val
            when 'Yes'
                mark_deep_well_deleted = show do
                    title "Do you want to keep the plate #{in_collection}?"
                    separator
                    note "<b>Ask manager to select an option</b>"
                    select [ "Yes", "No"], var: "keep_plate", label: "Do we still need this plate?", default: 1
                end
                if mark_deep_well_deleted[:keep_plate] == 'Yes'
                    # Deep Well plate needs to be quenched and stored at -80
                    in_collection.location = 'Give to manager - See EL' 
                    in_collection.save
                else
                    in_collection.mark_as_deleted
                    in_collection.save
                end
            when 'No'
                # Deep Well plate needs to be kept in incubator
                in_collection.location = '30C Shaker @ 800rpm' 
                in_collection.save
            end
            out_collection.location = '30C Shaker @ 800rpm'
            out_collection.save
            show {warning "Place lid and tape shut before placing flat bottom 96 well plate on shaker."}
            
            release [in_collection, out_collection], interactive: true
            
            # Adding stain to plate before it is read on the the Flow Cytometer
            num_of_non_empty_wells = out_collection.get_non_empty.length
            
            adding_live_dead_stain(op)
            
            show {
                title "Cleaning Up..."
                separator
                note "Clean bench and make sure any reagents used are placed back before ending the protocol :D"
            }
            
        end
        
        # operations.store
        
        return {}
        
    end # Main
    
    def adding_live_dead_stain(op)
        if debug
            in_item = Item.find(276614) # has new part data 
            in_collection = Collection.find(in_item.id)
            out_collection = Collection.find(in_item.id)
        else
            in_item = op.input(INPUT).item
            out_collection = op.output(OUTPUT).collection
            in_collection = op.input(INPUT).collection
        end
        
        # Find Sytox stain item and take it
        sytox_item = find(:item, { sample: { name: "SYTOX Red Stain" }, object_type: { name: "Screw Cap Tube" } } ).first
        take [sytox_item], interactive: true 
        
        stain_display_matrix = Array.new(out_collection.object_type.rows) { Array.new(out_collection.object_type.columns) {-1}}
        stain_display_rc_list = []
        in_collection.get_non_empty.each {|r,c|
            control_check = in_collection.get_part_data(:control, r, c)
            if control_check != 'negative_sytox'
                stain_display_matrix[r][c] = 3 # Stain_vol
                stain_display_rc_list.push([r,c])
            end
        }
        
        
        # part_data_matrix = Item.find(in_collection.id).get('part_data')
        # rc_list = []
        # # Creating rc_matrix that will direct tech to add SYTOX stain to specific wells (not negative sytox or the positive gfp well)
        # stain_display_matrix = part_data_matrix.each_with_index.map {|row, r_idx| 
        #     row.each_with_index.map {|part_data_obj, c_idx|
        #         # ie: part_data_obj => {"source"=>[{"id"=>291209, "row"=>0, "column"=>0, "process"=>"dilution"}], "od600"=>0.0003}
                
        #         obj_keys = part_data_obj.keys
                
        #         if !obj_keys.empty?
        #             if obj_keys.include? 'control'
        #                 (part_data_obj[:control] == 'negative_sytox' || part_data_obj[:control] == 'positive_gfp') ? stain_vol = -1 : stain_vol = 3
        #                 (part_data_obj[:control] == 'negative_sytox' || part_data_obj[:control] == 'positive_gfp') ? nil :  rc_list.push([r_idx, c_idx])
        #             else
        #                 stain_vol = 3
        #                 rc_list.push([r_idx, c_idx])
        #             end
        #             stain_vol
        #         else
        #             stain_vol = -1
        #         end
        #     }
        # }
        log_info 'stain_display_matrix', stain_display_matrix 
        
        num_of_wells_to_stain = in_collection.get_non_empty.length + 8 # make enough for the full plate
        tot_vol_of_diluted_stain = num_of_wells_to_stain * 3#ul of stain per 300ul of culture
        sytox_stk_vol = tot_vol_of_diluted_stain/10 # 1:10 dilution
        dmso_vol = tot_vol_of_diluted_stain - sytox_stk_vol
        # Preparing and diluting stain to working concentraion 
        show {
            title "Preparing SYTOX Live/Dead Stain"
            separator
            check "In a <b>1.5mL tube</b> aliquot <b>#{dmso_vol}</b> of 100% DMSO and label: <b>SYTOX</b>"
            check "Next, from the thawed SYTOX tube, take <b>#{sytox_stk_vol}µl</b> and resuspend into the SYTOX tube."
            bullet "Give the tube a quick vortex & spin down to collect the stain"
            check "Finally, in an 8 well stripwell, aliquot #{tot_vol_of_diluted_stain/8}µl of diluted stain to each well."
            bullet "Store stripwell away from light until needed"
        }
        release [sytox_item], interactive: true 
        
        show {
            title "Adding SYTOX to Plate #{out_collection}"
            separator
            check "Using a multichannel pipette, aliquot <b>3µl</b> of SYTOX stain to each well highlighted below."
            bullet "<b>Follow the table below to add SYTOX to the correct wells</b>"
            table highlight_alpha_rc(out_collection, stain_display_rc_list) {|r,c| "#{stain_display_matrix[r][c]}µl"}
            check "Tape lid and place on the shaker incubator (37C)"
            check "Next, set a <b>15 min</b> timer. Let a manager know if you will not be there when it finishes."
        }
    end
    
    
    def measurement_intro()
        show do
            title "Optical Density & GFP Measurements"
            
            note "This protocol will instruct you on how to take measurements on the BioTek Plate Reader."
            note "ODs are a quick and easy way to measure the growth rate of your culture."
            note "GFP measurements help researchers assess a response to a biological condition <i>in vivo</i>."
            note "<b>1.</b> Transfer culture to plate reader plate and add blank."
            note "<b>2.</b> Setup plate reader workspace."
            note "<b>3.</B> Take measurement, save data, & upload."
        end
    end
  
    def cleaning_up(item)
        show do 
            title "Cleaning Up..."
            
            note "Before finishing up, ask manager whether to save or discard item #{item}."
            note "If discarding, rinse out 96 Deep Well Plate and soak with diluted bleach."
        end
    end
    
    def record_plate_provenance_parallel_transfer(in_plate, out_plate)
        out_plate.dimensions[0].times do |r_idx|
          out_plate.dimensions[1].times do |c_idx|
            if (in_plate.part(r_idx, c_idx))
                in_part = in_plate.part(r_idx, c_idx)
                out_part = out_plate.part(r_idx, c_idx)
                out_plate_associations = AssociationMap.new(out_part)
                in_plate_associations = AssociationMap.new(in_part)
                add_provenance({
                               from: in_part,
                               from_map: in_plate_associations,
                               to: out_part,
                               to_map: out_plate_associations
                             })
                out_plate_associations.save
                in_plate_associations.save
            end
          end
        end

    end
    

end # Class