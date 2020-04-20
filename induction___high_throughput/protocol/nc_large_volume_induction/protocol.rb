# By: Eriberto Lopez
# elopez3@uw.edu
# 05/23/18
# °C µl

# Protocol outline
# L.1	Prepare culture_plates_5h* for 5h incubations with 2x location-dependant µL media + inducers (see next step)		
# L.2	Stamp/transfer from 96_deep_2 to plates prepared above for __ x dilution	70	7.5
# L.3	Stamp half the culture from the culture_plates_5h to the culture_plates_18h*		
# L.4	Incubate culture_plates_5h 5 hours @ 30/37C, 800rpm, 3mm orbital shaker		


needs "Standard Libs/Debug"
needs "YG_Harmonization/Upload_PlateReader_Data"
needs "YG_Harmonization/PlateReaderMethods"
needs "Tissue Culture Libs/CollectionDisplay"
needs "Induction - High Throughput/NovelChassisLib"

class Protocol
    
    include Debug
    include Upload_PlateReader_Data
    include PlateReaderMethods
    include CollectionDisplay
    include NovelChassisLib
    
    #I/O
    INPUT = "96 Well Plate in"
    OUTPUT_24s = "24 Deep Wells"
    
    # Parameters 
    
    # Constants
    PLATE_READER_TEMPLATE = "novel_chassis_20hr_outgrowth"
    MEDIA_LABEL_HASH = {
        'None_None'=>'M9', 
        'None_arab_25.0'=>'M9+Arab', 
        "None_IPTG_0.25"=>'M9+IPTG', 
        "None_IPTG_0.25|arab_25.0"=>'M9+IPTG+Arab',
        'Kan_None'=>'M9+Kan',
        "Kan_IPTG_0.25"=>'M9+Kan+IPTG', 
        "Kan_arab_25.0"=>'M9+Kan+Arab',
        "Kan_IPTG_0.25|arab_25.0"=>"M9+Kan+IPTG+Arab"
    }
    TRANSFER_ROWS = [[1,3,5,7], [2,4,6,8]] # Selecting everyother row to transfer from 96 to 24 well plates; This is currently the only way to transfer from 96 to 24 without an expandable pipettor
    DEEP_WELL_24_WELL_VOL = 3#mL
    TRANSFER_VOL = 43#ul
    INCUBATION_TIME = 5#hr
    
    
    
    def main
        intro()
        
        operations.make # Creates array of 24DeepWell plates
        operations.each do |op|
            
            # Gather materials
            gather_materials(op)
            
            if debug
                # From the input collection get associated matricies
                in_collection = Collection.find(271260) # test plate
                experimental_media_mat =  Item.find(in_collection.id).get('experimental_media_mat')
                sample_id_mat = in_collection.matrix
                # Collection dimesions 
                out_collection_rows = 4
                out_collection_cols = 6
            else
                # From the input collection get associated matricies
                in_collection = op.input(INPUT).collection
                experimental_media_mat =  Item.find(in_collection.id).get('experimental_media_mat')
                sample_id_mat = in_collection.matrix
                # Collection dimesions 
                out_collection_rows = op.output_array(OUTPUT_24s).collections.first.object_type.rows
                out_collection_cols = op.output_array(OUTPUT_24s).collections.first.object_type.columns
                
            end
            
            # Collection dimesions    
            in_collection_rows = op.input(INPUT).object_type.rows
            in_collection_cols = op.input(INPUT).object_type.columns
            in_collection_wells = in_collection_rows * in_collection_cols
            out_collection_wells = out_collection_rows * out_collection_cols
            
            
            # Slice 8x12 matricies into 4x6 2-D Arrays to Associate to the new 24DeepWell plates
            coordinates_96 = ('A'..'H').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}} 
            
            # Slicing up matricies in the same way [ [[1..6],[7..12]],[[1..6],[7..12]],.... ]
            coordinates_slices = slice_matrix(coordinates_96, out_collection_cols)
            # log_info coordinates_slices
            
            # Slicing sample id matrix
            sample_id_matrix_slices = slice_matrix(in_collection.matrix, out_collection_cols)
            # log_info sample_id_matrix_slices, 'sample_id_matrix_slices'
            
            # Slicing experimental media matrix
            experimental_media_matrix_slices = slice_matrix(experimental_media_mat, out_collection_cols)
            log_info experimental_media_matrix_slices, 'experimental_media_matrix_slices'
            
            # Gathering slices from every other row in order to transfer cultures to new 24 Deep Wells
            deep_well_transfer_coords = []
            deep_well_transfer_samp_ids = []
            deep_well_transfer_experimental_media = []
            TRANSFER_ROWS.each do |set|
                gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=coordinates_slices).each {|plt| deep_well_transfer_coords.push(plt)}
                gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=sample_id_matrix_slices).each {|plt| deep_well_transfer_samp_ids.push(plt)}
                gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=experimental_media_matrix_slices).each {|plt| deep_well_transfer_experimental_media.push(plt)}
                # deep_well_transfer_coords.push( gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=coordinates_slices) )
                # deep_well_transfer_samp_ids.push( gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=sample_id_matrix_slices) )
                # deep_well_transfer_experimental_media.push( gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=experimental_media_matrix_slices) )
            end
            
            # Grab input collection 
            input_item = Item.find(in_collection.id)
            take [input_item], interactive: true
            in_collection.location = 'Bench'
            in_collection.save
            
            # Display instruction and associate matricies to new 24 Deep wells and prepare 20hr 96 flat bottom
            op.output_array(OUTPUT_24s).collections.each_with_index do |coll, idx|
                associate_to_item(coll, 'experimental_media_mat', deep_well_transfer_experimental_media[idx])
                associate_to_item(coll, 'deep_well_transfer_coords', deep_well_transfer_coords[idx])
                coll.matrix = deep_well_transfer_samp_ids[idx]
                coll.location = '37°C Incubator Shaker - 800rpm'
                coll.save
                
                show do
                    title "Filling 24 Deep Well Plate ##{coll.id}"
                    separator
                    check "Gather a 24 Deep Well Plate and label: <b>#{coll.id}</b>"
                    note "Follow the table below to fill each well with <b>#{DEEP_WELL_24_WELL_VOL}mL</b> of the appropriate media:"
                    table highlight_non_empty(coll) {|r,c| MEDIA_LABEL_HASH[(deep_well_transfer_experimental_media[idx][r][c]).to_s]}
                    bullet "Continue on to the next step to inoculate 24 Deep Well Plate with cells."
                end
                show do
                    title "Inoculating 24 Deep Well Plate ##{coll.id}"
                    separator
                    note "For this step, use P20 tip boxes that have every other row filled."
                    note "Follow the table below to transfer <b>#{TRANSFER_VOL}µl</b> of culture from Item #<b>#{in_collection.id}</b> to Item #<b>#{coll.id}</b>"
                    bullet "Coordinates correspond to cultures in the 96 Well plate #<b>#{in_collection.id}</b>"
                    table highlight_non_empty(coll){|r,c| deep_well_transfer_coords[idx][r][c]}
                    bullet "Continue on to the next step to transfer 200µl of culture to a 96 Well Flat Bottom Plate"
                end
            end
            
            # DO NOT DELETE input plate in this step of the NC workflow
            # Plate will be used subsequently in plate reader induction
            # Perform this operation first to get the incubation going ASAP
            # in_collection.mark_as_deleted
            # in_collection.save
            
            # Place 24DW plates on incubator shaker
            out_coll_arr = op.output_array(OUTPUT_24s).collections.map {|coll| Item.find(coll.id)}
            release out_coll_arr, interactive: true
            show do
                title "Incubating 24 Deep Well Plates"
                separator
                note "Set a <b>#{INCUBATION_TIME}hr</b> timer & tell a manager if you will not be present when it finishes."
            end
            
            # Clean Up
            # show {
            #     title "Cleaning Up.."
            #     separator
            #     note "Take plate <b>#{in_collection}</b> to sink and soak with diluted bleach."
            # }
        end
        
        return {}
        
    end # Main
    
    def intro()
        show do
            title "Introduction - Novel Chassis Induction"
            separator
            note "In this portion of the workflow you will be inoculating and inducing cultures into a 96 Well plate & multiple 24 Deep Well plates."
            note "<b>1.</b> Fill 24 Deep Well plates with the appropriate induction media"
            note "<b>2.</b> Inoculate 24 Deep Well plates from 96 Flat bottom outgrowth plate"
            note "<b>3.</b> From the induced cultures in the 24 Deep Well plates, inoculate a new 96 Flat bottom plate"
            note "<b>4.</b> Setup plate reader and load 96 Well Flat bottom plate"
            note "<b>5.</b> Incuabate 24 Deep Well plates for 5 hrs."
        end
    end
    
    def gather_materials(op)
        in_collection = op.input(INPUT).collection
        if debug
            experimental_antibiotic_mat = Item.find(271260).get('experimental_antibiotic_mat')
            inducer_mat = Item.find(271260).get('inducer_mat')
        else
            experimental_antibiotic_mat = Item.find(in_collection.id).get('experimental_antibiotic_mat')
            inducer_mat = Item.find(in_collection.id).get('inducer_mat')
        end
        
        media_hash, experimental_media_matrix = experimental_media_hash_matrix(inducer_mat, experimental_antibiotic_mat)
        
        types_of_media = media_hash.map {|media, quant| MEDIA_LABEL_HASH[media] } 
        log_info types_of_media
        show do 
            title "Gather Materials"
            separator
            note "Materials needed for this experiment"
            check "Gather <b>#{op.output_array(OUTPUT_24s).collections.length}</b> sterile 24 Deep Well Plates."
            check "Gather <b>#{op.output_array(OUTPUT_24s).collections.length}</b> Aera breathable seals."
            check "Gather <b>#{media_hash.length}</b> reagent reservoirs."
            check "Gather <b>1</b> box of P20 pipette tips with every other row filled in."
            check "Gather the following types of media: <b>#{types_of_media}</b>"
        end
    end
    
    def gather_96_to_24_well_slices(set_of_rows, deep_24_cols, matrix)
        gathered_slices_for_24_well = []
        from_start_column = 0
        while from_start_column < deep_24_cols + 1 do
            gathered_slices_for_24_well.push(selecting_slices(matrix, set_of_rows,(from_start_column...from_start_column + 6).to_a))
            from_start_column += deep_24_cols
        end
        return gathered_slices_for_24_well
    end
    

    
    def slice_matrix(matrix, columns)
        slices = matrix.each_with_index.map do |row, idx|
            row.each_slice(columns).map do |slice|
                slice
            end
        end
        return slices
    end
    
    #
    # @params sliced_matrix [3-D Array]
    def selecting_slices(sliced_matrix, selected_rows, selected_cols)
        arr = []
        selected_cols = selected_cols.sum > 15 ? 1 : 0 
        sliced_matrix.each_with_index do |row, r_idx|
            r_idx += 1
            if selected_rows.include? r_idx
                arr.push(row[selected_cols])
            end
        end
        return arr
    end

    def flat_96_rc_list(coordinates)
        rows = ('A'..'H').to_a
        cols =  (1..12).to_a
        flat_96_rc_list = []
        coordinates.map do |row_arr|
            row_arr.map do |col|
                r = rows.find_index(col.first)
                c = col[1..col.length].to_i - 1
                flat_96_rc_list.push([r,c])
            end
        end
        return flat_96_rc_list
    end
    
    def transfer_24_to_96_row(row)
        arr = [1, 3, 5, 7]
        if arr.include? row
            row = arr.find_index(row)
        else
            arr = [0, 2, 4, 6]
            row = arr.find_index(row)
        end
        
        # arr = (arr.include? row) ? arr : arr = [0, 2, 4, 6]
        # row = arr.find_index(row)
        return row
    end
    
    def transfer_24_to_96_col(col)
        if col > 5
            col = col - 6
        else
            col
        end
        return col
    end

    
    
    # Copied from Dilute 96 Deep Well & outgrowth
    def experimental_media_hash_matrix(inducer_mat, experimental_antibiotic_mat)
        media_hash = Hash.new(0)
        experimental_media_matrix = [] # Combines antibiotic and inducer media strings to create a matrix that combines both medias
        inducer_mat.each_with_index do |row, r_idx|
            mat_row = []
            row.each_with_index do |col, c_idx|
                if col != "-1"
                    media = experimental_antibiotic_mat[r_idx][c_idx] + "_" + col
                    mat_row.push(media)
                    if !media_hash.include? media
                        media_hash[media] = 1
                    else
                        media_hash[media] += 1
                    end
                end
            end
            experimental_media_matrix.push(mat_row)
        end
       return media_hash, experimental_media_matrix 
    end




end # Class
