# By: Eriberto Lopez
# elopez3@uw.edu
# 05/23/18
# C l

# Protocol outline
# L.1	Prepare culture_plates_5h* for 5h incubations with 2x location-dependant L media + inducers (see next step)		
# L.2	Stamp/transfer from 96_deep_2 to plates prepared above for __ x dilution	70	7.5
# L.3	Stamp half the culture from the culture_plates_5h to the culture_plates_18h*		
# L.4	Incubate culture_plates_5h 5 hours @ 30/37C, 800rpm, 3mm orbital shaker		


needs "Standard Libs/Debug"
needs "YG_Harmonization/Upload_PlateReader_Data"
needs "YG_Harmonization/PlateReaderMethods"
needs "Tissue Culture Libs/CollectionDisplay"
needs "Induction - High Throughput/NovelChassisLib"
needs "High Throughput Culturing/ExperimentInitializer"
needs "Standard Libs/MatrixTools"
needs "Standard Libs/AssociationManagement"

class Protocol
    
    include Debug
    # include Upload_PlateReader_Data
    # include PlateReaderMethods
    # include NovelChassisLib
    include CollectionDisplay
    include ExperimentInitializer
    include MatrixTools
    include AssociationManagement
    include PartProvenance

    
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
            
            in_collection = op.input(INPUT).collection
            
            # From the input collection get associated matricies
            overnight_antibiotic_mat      = in_collection.data_matrix_values("Overnight Antibiotic")
            experimental_antibiotic_mat =  in_collection.data_matrix_values("Experimental Antibiotic")
            media_type_mat              =  in_collection.data_matrix_values("Type of Media")
            inducer_mat                 = in_collection.data_matrix_values("Inducers")
            ctag_mat                      = in_collection.data_matrix_values("Control Tag")
            sample_id_mat = in_collection.matrix
            # Collection dimesions 
            out_collection_rows = op.output_array(OUTPUT_24s).collections.first.object_type.rows
            out_collection_cols = op.output_array(OUTPUT_24s).collections.first.object_type.columns
            
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
            overnight_anti_matrix_slices = slice_matrix(overnight_antibiotic_mat, out_collection_cols)
            experimental_anti_matrix_slices = slice_matrix(experimental_antibiotic_mat, out_collection_cols)
            media_type_matrix_slices = slice_matrix(media_type_mat, out_collection_cols)
            inducer_matrix_slices = slice_matrix(inducer_mat, out_collection_cols)
            ctag_matrix_slices = slice_matrix(ctag_mat, out_collection_cols)
            
            # Gathering slices from every other row in order to transfer cultures to new 24 Deep Wells
            deep_well_transfer_coords = []
            deep_well_transfer_samp_ids = []
            deep_well_transfer_overnight_anti = []
            deep_well_transfer_experimental_anti = []
            deep_well_transfer_media_type = []
            deep_well_transfer_inducer = []
            deep_well_transfer_ctag = []
            TRANSFER_ROWS.each do |set|
                gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=coordinates_slices).each {|plt| deep_well_transfer_coords.push(plt)}
                gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=sample_id_matrix_slices).each {|plt| deep_well_transfer_samp_ids.push(plt)}
                gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=inducer_matrix_slices).each {|plt| deep_well_transfer_inducer.push(plt)}
                gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=overnight_anti_matrix_slices).each {|plt| deep_well_transfer_overnight_anti.push(plt)}
                gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=experimental_anti_matrix_slices).each {|plt| deep_well_transfer_experimental_anti.push(plt)}
                gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=media_type_matrix_slices).each {|plt| deep_well_transfer_media_type.push(plt)}
                gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=inducer_matrix_slices).each {|plt| deep_well_transfer_inducer.push(plt)}
                gather_96_to_24_well_slices(set_of_rows=set, deep_24_cols=out_collection_cols, matrix=ctag_matrix_slices).each {|plt| deep_well_transfer_ctag.push(plt)}

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
                coll.matrix = deep_well_transfer_samp_ids[idx]
                coll.set_data_matrix('Overnight Antibiotics', deep_well_transfer_overnight_anti[idx])
                coll.set_data_matrix('Experimental Antibiotics', deep_well_transfer_experimental_anti[idx])
                coll.set_data_matrix('Type of Media', deep_well_transfer_media_type[idx])
                coll.set_data_matrix('Inducers', deep_well_transfer_inducer[idx])
                coll.set_data_matrix('Control Tag', deep_well_transfer_ctag[idx])
                coll.set_data_matrix('deep_well_transfer_coords', deep_well_transfer_coords[idx])
                coll.location = '37C Incubator Shaker - 800rpm'
                coll.save
                
                # Add provenance between input and output plate using the deep_well_transfer_coords of this output plate
                out_plate_associations = AssociationMap.new(coll)
                in_plate_associations = AssociationMap.new(in_collection)
                coll.dimensions[0].times do |r_idx|
                  coll.dimensions[1].times do |c_idx|
                    from_coord = WellMatrix.numeric_coordinate(deep_well_transfer_coords[idx][r_idx][c_idx])
                    if (in_collection.matrix[from_coord[0]][from_coord[1]] != -1)
                      add_provenance({
                          from: in_collection, 
                          from_map: in_plate_associations,
                          from_coord: from_coord,
                          to: coll,
                          to_coord: [r_idx, c_idx],
                          to_map: out_plate_associations
                      })
                    end
                  end
                end
                out_plate_associations.save
                in_plate_associations.save
                
                
                show do
                    title "Filling 24 Deep Well Plate ##{coll.id}"
                    separator
                    check "Gather a 24 Deep Well Plate and label: <b>#{coll.id}</b>"
                    note "Follow the table below to fill each well with <b>#{DEEP_WELL_24_WELL_VOL}mL</b> of the appropriate media:"
                    table highlight_non_empty(coll) { |r,c| deep_well_transfer_media_type[idx][r][c].to_s + " " + (deep_well_transfer_experimental_anti[idx][r][c]).to_s + " + " + deep_well_transfer_inducer[idx][r][c].map { |inducer, conc|  inducer + ":" + conc.to_s + "mM" }.join(" + ") }
                    bullet "Continue on to the next step to inoculate 24 Deep Well Plate with cells."
                end
                show do
                    title "Inoculating 24 Deep Well Plate ##{coll.id}"
                    separator
                    note "For this step, use P20 tip boxes that have every other row filled."
                    note "Follow the table below to transfer <b>#{TRANSFER_VOL}l</b> of culture from Item #<b>#{in_collection.id}</b> to Item #<b>#{coll.id}</b>"
                    bullet "Coordinates correspond to cultures in the 96 Well plate #<b>#{in_collection.id}</b>"
                    table highlight_non_empty(coll){|r,c| deep_well_transfer_coords[idx][r][c]}
                    bullet "Continue on to the next step to transfer 200l of culture to a 96 Well Flat Bottom Plate"
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
            show {
                title "Cleaning Up.."
                separator
                note "Take plate <b>#{in_collection}</b> to sink and soak with diluted bleach."
            }
        end
        
        return {}
        
    end # Main
    
    def intro()
        show do
            title "Introduction - High Throughput Induction"
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
        experimental_antibiotic_mat = in_collection.data_matrix_values('Experimental Antibiotic')
        inducer_mat = in_collection.data_matrix_values('Inducers')
        media_type_mat = in_collection.data_matrix_values('Type of Media')
        
        media_hash = complex_tally_induced_media_variants(inducer_mat, experimental_antibiotic_mat, media_type_mat)
        
        
        types_of_media = media_hash.map do |media_type_and_inducers, quant|
          media_type = media_type_and_inducers[0]
          inducer_hash = media_type_and_inducers[1]
          full_name = media_type
          inducer_hash.each do |inducer, conc|
            full_name += " + " + inducer + ":" + conc.to_s + "mM"
          end
          full_name
        end
        
        # log_info types_of_media
        show do 
            title "Gather Materials"
            separator
            note "Materials needed for this experiment"
            check "Gather <b>#{op.output_array(OUTPUT_24s).collections.length}</b> sterile 24 Deep Well Plates."
            check "Gather <b>#{op.output_array(OUTPUT_24s).collections.length}</b> Aera breathable seals."
            check "Gather <b>#{media_hash.length}</b> reagent reservoirs."
            check "Gather <b>1</b> box of P20 pipette tips with every other row filled in."
            check "Gather the following types of media: <b>#{types_of_media.join(",")}</b>"
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
end # Class
