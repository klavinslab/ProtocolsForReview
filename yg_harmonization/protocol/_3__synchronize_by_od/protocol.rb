# By: Eriberto Lopez 
# 01/08/2018
# elopez3@uw.edu
# Updated: 09/27/18

# Loads necessary libraries
needs "YG_Harmonization/PlateReaderMethods"
needs "YG_Harmonization/HighThroughput_Lib"
needs "YG_Harmonization/Upload_PlateReader_Data"
needs "Standard Libs/Debug" # Used for printing out objects for debugging purposes
needs "Tissue Culture Libs/CollectionDisplay"
needs "Standard Libs/AssociationManagement"
needs "YG_Harmonization/YG_Controls"
needs "YG_Harmonization/SynchronizationLib"

class Protocol
    require 'date'

    include PlateReaderMethods, HighThroughput_Lib, Upload_PlateReader_Data, YG_Controls, SynchronizationLib
    include CollectionDisplay
    include Debug, AssociationManagement
    include PartProvenance
    
    # I/O
    INPUT = "96 Well Flat Bottom"
    OUTPUT = "96 Well Deep U-bottom"
    
    # Parameters
    FINAL_OD = [0.0003, 0.00015, 0.000075] # Future JSON object parameter
    MEDIA = "Type of Media"
    GROWTH_TEMPERATURE = "Growth Temperature (°C)"
    
    # Protocol Constants and Misc.
    SAVING_DIRECTORY = "_UWBIOFAB"
    FINAL_OUTPUT_VOL = 1.0 #mL
    TEMPLATE_FILENAME = 'Single_OD600.prt'
    WAVELENGTH = 600
    
  def main
        operations.make
        intro_sync_OD(WAVELENGTH)
        
        # Initialize these varibles to hold on to measurement used for many synchronizations
        resuspension_and_outgrowth_cultures_measured = false
        up_show = ''
        up_sym = ''
        od_filename = ''
        
        # For each 96 well plate
        operations.each do |op|
            
            in_coll = op.input(INPUT).collection
            out_coll = op.output(OUTPUT).collection
            bio_reps = get_bio_reps_from_outgrowth_plate(in_coll)
            media = op.input(MEDIA).val
            
            # Measure OD on BioTek PlateReader
            if !resuspension_and_outgrowth_cultures_measured
                
                # Measure on BioTek Show blocks
                up_show, up_sym, od_filename = measure_on_plt_reader(in_coll, media)
                
                # Try again if no file was uploaded from Plate Reader
                if (up_show[up_sym].nil?)
                    show {note "<b>No upload found!!! Please try again.</b>"}
                    up_show, up_sym = upload_show(od_filename)
                end
                resuspension_and_outgrowth_cultures_measured = true
            end
            
            # Processing uploaded file; Using data to direct tech and associating data to both input and output items
            if debug
                input_plate_ods, up_ext, upload = debug_upload(in_coll)
                # log_info 'input_plate_ods, up_ext, upload', input_plate_ods, up_ext, upload 
            else
                timepoint = od_filename.split('_')[4] # -1hr
                method = 'od' # what is being measured on the plate reader
                key = "Item_#{in_coll.id}_#{timepoint}_#{method}"
                upload = find_upload_from_show(up_show, up_sym)
                up_ext = upload.name.split('.')[1]
                
                # Associates upload to item and plan - this is _-1hr_ upload is associated
                associate_to_item(in_coll, key, upload)
                associate_to_item(out_coll, key, upload)
                associate_to_plan(upload, key)
            end

            if up_ext.downcase == 'csv'
                
                # From standard Libs Parses out tablular formatted data - Abe's function
                input_plate_ods = (extract_measurement_matrix_from_csv(upload)).to_a # return data matrix obj then I turn that into 2-D Array(.to_a)
                # log_info 'input_plate_ods',input_plate_ods
                # show{note"TEST Input Plate ODs - #{input_plate_ods}"}
                
                # Synchronizing experimental cultures and creating matricies to display for cult_vol and media_vol
                input_cult_coords, cult_vol_mat, media_vol_mat = sync_experimental_cultures(
                    in_collection=in_coll,
                    out_collection=out_coll, 
                    input_plate_ods,
                    bio_reps
                    )
                # log_info 'input_cult_coords', input_cult_coords, 'cult_vol_mat',cult_vol_mat, 'media_vol_mat', media_vol_mat, 'out_collection.matrix', out_coll.matrix
                
                # Creating staining control cultures from a WT culture found in the input collection
                neg_pos_wt_cult_coord_destination = ['H7', 'H8'] # Where I want control cults to be in the output plate
                input_cult_coords, cult_vol_mat, media_vol_mat = creating_neg_pos_wt_staining_control(
                    in_collection=in_coll,
                    out_collection=out_coll,
                    neg_pos_wt_cult_coord_destination,
                    cult_vol_mat, 
                    media_vol_mat,
                    input_cult_coords
                    )
                # log_info 'input_cult_coords', input_cult_coords, 'cult_vol_mat',cult_vol_mat, 'media_vol_mat', media_vol_mat, 'out_collection.matrix', out_coll.matrix
                
                # Creating positive GFP culture from the input collection
                input_cult_coords, cult_vol_mat, media_vol_mat = creating_pos_gfp_control(
                    out_collection=out_coll,
                    input_plate_ods,
                    FINAL_OUTPUT_VOL,
                    cult_vol_mat, 
                    media_vol_mat,
                    input_cult_coords
                    )
                # log_info 'input_cult_coords', input_cult_coords, 'cult_vol_mat',cult_vol_mat, 'media_vol_mat', media_vol_mat, 'out_collection.matrix', out_coll.matrix
                
                # Create a sample dilution matrix for SD2 to track the dilution of a sample the matrix will have each 
                out_coll_dilution_mat(
                    in_coll,
                    out_coll,
                    stain_control_coords=neg_pos_wt_cult_coord_destination,
                    gfp_control_coords=['H9']
                )
                
                # Directs tech to fill new 96 Deep Well Plate with media
                aliquot_media(
                    out_coll,
                    media_vol_mat,
                    media
                ) # PlateReaderMethods
                
                # Associate type of media to output item - 96 Deep Well plate
                Item.find(out_coll.id).associate('type_of_media', media)
                log_info 'type_of_media', media
                
                # Directs tech to inoculate output collection with cultures from input collection
                inoculate_plate(in_coll, out_coll, input_cult_coords, cult_vol_mat)
                
            end
        end
        cleaning_up(operations.map{|op| op.input(INPUT).collection}.uniq) 
        return {}
  end # Main


    def measure_on_plt_reader(in_coll, media)
        timepoint = -1 # timepoint -1 due to prior 1hr incubation Resuspension & Outgrowth
        take [in_coll], interactive: true
        add_blanks({ qty: 200, units: 'ul' }, 'SC')
        
        # Sets up BioTek Workspace
        set_up_plate_reader(in_coll, TEMPLATE_FILENAME)
        
        # Exports measurement file as CSV
        od_filename = export_data(in_coll, timepoint, method='od')
        
        # Upload file; Show block upload button and retrieval of file uploaded
        up_show, up_sym = upload_show(od_filename)
        
        return up_show, up_sym, od_filename
    end
    
    # Creates a debugging upload and in_collection matrix to work with
    def debug_upload(in_coll)
        upload_id = 11188 #10494 # tabular plate reader output
        upload = Upload.find(upload_id)
        up_ext = upload.name.split('.')[1]
        input_plate_ods = []
        in_coll.matrix = [
            [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
            [13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24],
            [25, 26, 27, 28, 29, 30, -1, -1, -1, -1, -1, -1],
            [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1], 
            [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1], 
            [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1], 
            [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1], 
            [-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1]
        ]
        return input_plate_ods, up_ext, upload
    end
    

    def cleaning_up(in_coll_arr)
        display_item_ids = in_coll_arr.map {|in_coll| in_coll.id }
        show do 
            title "Cleaning Up..."
            separator
            note "When finished with 96 Well Flat Bottom <b>#{display_item_ids}</b>"
            note "Please rinse out with DI water and diluted EtOH."
        end
        in_coll_arr.each {|flat_plt| flat_plt.mark_as_deleted }
    end
    
    # def out_rc_index(num_of_input_experimental_samples, r_idx, c_idx, od_idx)
        

    # This function creates a WellMatrix for a given output collection, with well source and well destination information
    # ie: The following object will be placed in each given row, col index
    #
    #   {
    #       source: "#{input collection.id}/#{input collection well}"
    #       destination: {"od600":"#{final OD the output collection well was diluted to}"}
    #   }
    #
    # @params in_collection [collection obj] the input collection that is being diluted to given final ODs
    # @params out_collection [collection obj] the output collection that has cultures synchronized by OD and to which the WellMatrix will be associated to 
    def out_coll_dilution_mat(in_collection, out_collection, stain_control_coords, gfp_control_coords)
        if debug
            in_collection = Collection.find(411551)
        end
        log_info 'out_coll dilution_matrix', out_collection, out_collection.matrix
        in_map = AssociationMap.new(in_collection)
        out_map = AssociationMap.new(out_collection)
        
        # 96 Well alpha coordinates
        coordinates_96 = ('A'..'H').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}}
        
        num_of_input_experimental_samples = in_collection.get_non_empty.select {|r, c| r!=7}.length
        
        # Setting objects into WellMatrix
        FINAL_OD.each_with_index {|f_od, od_idx|
            in_collection.matrix.each_with_index {|row, r_idx|
                row.each_with_index {|in_well, c_idx|
                    if r_idx != 7 # Controls row
                        if in_well != -1
                            r_out_idx, c_out_idx = get_rc_out_from_rc_in_and_od_no(r_idx,c_idx, od_idx, num_of_input_experimental_samples)
                            
                            # record historical relation between input collection part and target collection part
                            from_part = in_collection.part(r_idx, c_idx)
                            from_part_map = AssociationMap.new(from_part)
                            to_part = out_collection.part(r_out_idx, c_out_idx)
                            to_part_map = AssociationMap.new(to_part)
                
                            add_provenance({
                                               from: from_part,
                                               from_map: from_part_map,
                                               to: to_part,
                                               to_map: to_part_map,
                                               additional_relation_data: { process: "dilution" },
                                            })
                            from_part_map.save
                            # associate od600 to out collection parts
                            to_part_map.put('od600', f_od)
                            to_part_map.save
                        end
                    end
                }
            }
        }
        
        # Adding WT controls to routing matrix
        input_wt_cult_coord = find_input_wt_cult_coord(collection=in_collection) # => [r,c]
        stain_control_coords.each {|alpha_coord|
            (alpha_coord.include? 7.to_s) ? type_of_control = 'negative_sytox' : type_of_control = 'positive_sytox' # Position on the plate determines whether it is a positive or negative control
            num_coord = WellMatrix.numeric_coordinate(alpha_coord) #=> [x,y]
            
            from_part = in_collection.part(num_coord[0], num_coord[1])
            from_part_map = AssociationMap.new(from_part)
            to_part = out_collection.part(num_coord[0], num_coord[1])
            to_part_map = AssociationMap.new(to_part)
            add_provenance({
                               from: from_part,
                               from_map: from_part_map,
                               to: to_part,
                               to_map: to_part_map,
                               additional_relation_data: { process: "dilution" },
                            })
            from_part_map.save
            # associate od600 to control wells' data
            to_part_map.put('od600', '0.0003')
            to_part_map.put('control', type_of_control)
            to_part_map.save
        }
        
        # Adding positive gfp control to routing matrix - NOR00-6390
        gfp_control_coords.each {|alpha_coord|
            num_coord = WellMatrix.numeric_coordinate(alpha_coord)
            type_of_control = 'positive_gfp'
            
            # for pos gfp, input and output coords are the same
            from_part = in_collection.part(num_coord[0], num_coord[1])
            from_part_map = AssociationMap.new(from_part)
            to_part = out_collection.part(num_coord[0], num_coord[1])
            to_part_map = AssociationMap.new(to_part)
            add_provenance({
                               from: from_part,
                               from_map: from_part_map,
                               to: to_part,
                               to_map: to_part_map,
                               additional_relation_data: { process: "dilution" },
                            })
            from_part_map.save
            # associate od600 to control wells' data
            to_part_map.put('od600', '0.0003')
            to_part_map.put('control', type_of_control)
            to_part_map.save
        }
        
        out_map.save
        in_map.save
        
        if debug
          show do
            title "output dilution matrix associations"
            table AssociationMap.new(out_collection).get_data_matrix
          end
        end
    end
end # Class