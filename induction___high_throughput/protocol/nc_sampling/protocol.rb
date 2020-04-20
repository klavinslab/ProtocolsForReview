# By: Eriberto Lopez
# elopez3@uw.edu
# 05/30/18
# °C µl

# Outline
# After 5hr incubation sample 4 24 Deep Well plates
# Prepare PBS + Kan plate for ribosomal arrest - PBS_Kan_Plate #
# Sample 24 Deep wells and transfer to PBS_Kan_Plate
# PBS_Kan_Plate - Measure OD & GFP
# Incubate for 1hr - may be able to keep overnight and run flow in the morning
# Prepare RNAprotect plate (RNAlater)
# Spin down plates, aspirate supernatant, and resuspend pellet in 1mL of PBS in order to transfer to RNA protect plate
# store RNA plate in -80C freezer for downstream processing

needs "Standard Libs/Debug"
needs "YG_Harmonization/Upload_PlateReader_Data"
needs "YG_Harmonization/PlateReaderMethods"
needs "Tissue Culture Libs/CollectionDisplay"
needs "Induction - High Throughput/NovelChassisLib" # Temporary EL
needs "Plate Reader/PlateReaderHelper"
needs "Induction - High Throughput/HighThroughputHelper"

class Protocol
    
    include Debug
    include Upload_PlateReader_Data
    include PlateReaderMethods
    include CollectionDisplay
    include NovelChassisLib
    include PlateReaderHelper
    include HighThroughputHelper
    
    #I/O
    INPUT = "24 Deep Wells"
    OUT_FC_PLT = "Flow Cytometry Plate"
    OUT_PLT_RDR_PLT = "Plate Reader Plate"
    OUT_RNA_PLT = "RNA Prep Plate"
    
    # Constants
    FC_PLT_TRANSFER_VOL = 20#µl
    PLT_RDR_PLT_TRANSERFER_VOL = 300#µl


    def main
        
        operations.make # Creates output plates
        
        intro()
        
        operations.each { |op|
            gather_materials(op)
            
            # Piecing together matricies that were previously sliced up and associate to 24 Wells
            if debug
                
                p1 = Item.find(136641)
                p2 = Item.find(136642)
                p3 = Item.find(136643)
                p4 = Item.find(136644)
                input_item_arr = [p1,p2,p3,p4]
            else
                input_item_arr = op.input_array(INPUT).items
            end
            
            # from the associated matricies of the input 24 Wells piece together a new 96 Well matrix
            transfer_coordinates, experimental_media_matrix_96, sample_id_matrix_out = transferring_24s_to_96_matricies(input_item_arr)
            
            # Prep FC Plate - returns collection
            out_fc_plt = prepare_flow_cytometry_plate(op, transfer_coordinates, experimental_media_matrix_96, sample_id_matrix_out)
            
            # Prepare Plate Reader Plate - returns collection
            plate_reader_plate = prepare_plate_reader_plate(op, transfer_coordinates, experimental_media_matrix_96, sample_id_matrix_out)
            
            # Prepare RNA Plate - returns collection
            rna_plate = prepare_rna_plate(op, transfer_coordinates, experimental_media_matrix_96, sample_id_matrix_out)
            
            # Grab 24 Deep Wells from Incubator shaker
            take input_item_arr, interactive: true
            
            # Transfer cultures from 24 Deep wells to FC flat bottom plate & plate reader plate
            coordinates_96 = ('A'..'H').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}} # 96 Well coordinate map
            count = 0
            spin_down_plates = []
            input_item_arr.each do |plt|
                # find the rc_list from where the deep well transfer coords match the coordinates_96
                display_rc_list = []
                deep_well_transfer_coords = plt.get('deep_well_transfer_coords') # Contains coords like: "A1", "A2"...
                deep_well_transfer_coords.flatten.each do |coord|
                    coordinates_96.map.each_with_index do |row, r_idx|
                        col_idx = row.each_index.select {|well| row[well] == coord}
                        col_idx.each {|c_idx| display_rc_list.push([r_idx, c_idx])}
                    end
                end
                
                show do
                    title "Transferring Culture to Output Plates"
                    separator
                    note "Follow the table below to transfer culture <b>from the 24 Deep Well Plate #{plt.id}</b> to Plate #{out_fc_plt.id} & Plate #{plate_reader_plate.id}"
                    check "To plate <b>#{out_fc_plt.id}</b> transfer <b>#{FC_PLT_TRANSFER_VOL}µl</b>"
                    check "To plate <b>#{plate_reader_plate.id}</b> transfer <b>#{PLT_RDR_PLT_TRANSERFER_VOL}µl</b>"
                    if debug
                        container = ObjectType.find_by_name('96 U-bottom Well Plate')
                        collection = produce new_collection container.name
                    else
                        collection = out_fc_plt # This is just for displaying both out_fc_plt and plate_reader_plate should have the same matricies associated in the same layout
                    end
                    bullet "<b>Coordinates correspond to the wells in plate #{plt.id}</b>"
                    table highlight_rc(collection, display_rc_list) {|r,c| "#{coordinates_24(r, c)}"}
                end
                count += 1
                spin_down_plates.push(plt.id)
                if count % 2 == 0 # Spin down every pair of 24DW plates in order to balance centrifuge
                    show {
                        title "Spin Down 24 Deep Well Plates"
                        separator
                        note "Use the large centrifuge to spin down deep well plates"
                        check "Centrifuge plates <b>#{spin_down_plates.flatten}</b> at <b>4°C, 4000rpm, for 10 mins</b>"
                        note "Once plates are finished being centrifuged aspirate supernatant without disturbing the cell pellets."
                        bullet "Continue on to the next step while plates are being centrifuged."
                    }
                    spin_down_plates = []
                end
            end
            
            # Once 24 Deep wells have been spun down and supernatant has been removed
            input_item_arr.each do |plt|
                # find the rc_list from where the deep well transfer coords match the coordinates_96
                display_rc_list = []
                deep_well_transfer_coords = plt.get('deep_well_transfer_coords') # Contains coords like: "A1", "A2"...
                deep_well_transfer_coords.flatten.each do |coord|
                    coordinates_96.map.each_with_index do |row, r_idx|
                        col_idx = row.each_index.select {|well| row[well] == coord}
                        col_idx.each {|c_idx| display_rc_list.push([r_idx, c_idx])}
                    end
                end
                
                show do
                    title "Resuspending Cell Pellets"
                    separator
                    check "To each well in Plate <b>#{plt.id}</b> resuspend cell pellet in <b>0.5mL</b> of <b>RNAlater Soln</b>"
                    note "Next, transfer resuspended cell pellet from Plate <b>#{plt.id}</b> to Plate <b>#{rna_plate.id}</b>"
                    note "Follow the table below to transfer culture from the 24 Deep Well plate to Plate #{rna_plate.id}"
                    if debug
                        # collection = Collection.find(271292)
                        container = ObjectType.find_by_name('96 U-bottom Well Plate') # used for debug display
                        collection = produce new_collection container.name
                    else
                        collection = out_fc_plt # This is just for displaying
                    end
                    bullet "<b>Coordinates correspond to the wells in plate #{plt.id}</b>"
                    table highlight_rc(collection, display_rc_list) {|r,c| "#{coordinates_24(r, c)}"}
                end
            end            
            # Once RNA plate has been filled, centrifuge once more to remove supernatant
            show {
                title "Collecting Cell Pellets"
                separator
                note "Once all cell pellets have been resuspended and collected on to Plate #{rna_plate.id}"
                check "Centrifuge Plate <b>#{rna_plate.id}</b> at <b>4°C, 4000rpm, for 10 mins</b>"
                check "Once done, remove supernatant, seal with aluminumn foil cover, and place in the -80°C freezer."
                rna_plate.location = " -80°C freezer"
                rna_plate.save
            }
        }
        
        cleaning_up()
        
    end # Main


    def intro()
        show {
            title "Introduction - Novel Chassis Sampling & Harvesting"
            separator
            note "In this protocol you will be sampling and harvesting cultures for measurements and downstream processing."
            note "<b>1.</b> Sample each culture and arrest ribosomal function with Kanamycin"
            note "<b>2.</b> Measure OD & GFP"
            note "<b>3.</b> Harvest cells for RNA Sequencing."
        }
    end
    
    def gather_materials(op)
        show {
            title "Gather Materials"
            separator
            check "Set large centrifuge to 4°C"
            check "In an appropriate container, aliquot <b>12.8mL</b> of PBS & label: <b>PBS+Kan</b>"
            bullet "To the PBS add <b>3.2mL</b> of Kan Stock Solution (10mg/mL)"
            check "Gather <b>2</b> 96 Well Flat Bottom (black) plate(s)"
            check "Gather <b>1</b> 96 Deep Well plate(s)"
            check "In an appropriate container, aliquot <b>15mL</b> of <b>M9</b> media & label: <b>RNAlater Soln</b>"
            bullet "To that media, add <b>30mL</b> of <b>RNAlater</b>"
        }
    end
    def cleaning_up()
        show{
            title "Cleaning Up..."
            separator
            check "Before ending the protocol, clean up bench and other instruments used"
            check "Make sure that the centrifuge temperature is placed back to room temperature"
        }
    end
    
    def prepare_flow_cytometry_plate(op, transfer_coordinates, experimental_media_matrix_96, sample_id_matrix_out)
        if debug
            container = ObjectType.find_by_name('96 U-bottom Well Plate')
            out_fc_plt = produce new_collection container.name
        else
            out_fc_plt = op.output(OUT_FC_PLT).collection
        end
        # Associate to output FC plate
        out_fc_plt.matrix = sample_id_matrix_out
        out_fc_plt.save
        associate_to_item(out_fc_plt, 'experimental_media_mat', experimental_media_matrix_96)
        associate_to_item(out_fc_plt, 'transfer_coordinates', transfer_coordinates)
        
        show {
            title "Preparing Flow Cytometry Measurement Plate"
            separator
            check "Gather a 96 Flat Bottom (black) plate"
            check "Label Plate <b>#{out_fc_plt.id}</b>"
            bullet "Continue to the next step when ready"
        }
        show {
            title "Preparing Flow Cytometry Measurement Plate"
            separator
            note "The PBS+Kan Solution will arrest ribosomal transcription"
            check "Gather a multichannel resivior for <b>PBS+Kan Solution</b>"
            note "Follow the table below to fill <b>Plate #{out_fc_plt.id}</b> the appropriate wells with <b>PBS+Kan</b>"
            table highlight_non_empty(out_fc_plt) {|r,c| '180µl'}
        }
        return out_fc_plt
    end
    
    def prepare_plate_reader_plate(op, transfer_coordinates, experimental_media_matrix_96, sample_id_matrix_out)
        if debug 
            container = ObjectType.find_by_name('96 U-bottom Well Plate')
            plate_reader_plate = produce new_collection container.name
        else
            plate_reader_plate = op.output(OUT_PLT_RDR_PLT).collection
        end
        # Associate to output plate reader plate
        plate_reader_plate.matrix = sample_id_matrix_out
        plate_reader_plate.save
        associate_to_item(plate_reader_plate, 'experimental_media_mat', experimental_media_matrix_96)
        associate_to_item(plate_reader_plate, 'transfer_coordinates', transfer_coordinates)
        show {
            title "Preparing Plate Reader Measurement Plate"
            separator
            check "Gather a 96 Flat Bottom (black) plate"
            check "Label Plate <b>#{plate_reader_plate.id}</b>"
            bullet "Continue on the the next step to fill with culture."
        }
        return plate_reader_plate
    end
    
    def prepare_rna_plate(op, transfer_coordinates, experimental_media_matrix_96, sample_id_matrix_out)
        if debug
            container = ObjectType.find_by_name('96 U-bottom Well Plate')
            rna_plate = produce new_collection container.name
        else
            rna_plate = op.output(OUT_RNA_PLT).collection
        end
        
        # Associate to output RNA plate
        rna_plate.matrix = sample_id_matrix_out
        rna_plate.save
        associate_to_item(rna_plate, 'experimental_media_mat', experimental_media_matrix_96)
        associate_to_item(rna_plate, 'transfer_coordinates', transfer_coordinates)
        
        show {
            title "Preparing RNA Prep Plate"
            separator
            check "Gather a 96 Deep Well plate"
            check "Label Plate <b>#{rna_plate.id}</b>"
            bullet "Continue on to the next step to fill with culture."
        }
        return rna_plate
    end
    
    def coordinates_24(row, col)
        r = transfer_24_to_96_row(row)
        c = transfer_24_to_96_col(col)
        coordinates_24 = ('A'..'D').to_a.map {|row| (1..6).to_a.map {|col| row + col.to_s}} # 96 Well coordinate map
        return coordinates_24[r][c]
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
    
    def transferring_24s_to_96_matricies(input_arr)
        # Empty 96 well dimesion matricies
        transfer_coordinates = (0..7).to_a.map {|row| (0..11).to_a.map {|col| -1}}
        experimental_media_matrix_96 = (0..7).to_a.map {|row| (0..11).to_a.map {|col| -1}}
        sample_id_matrix_out = (0..7).to_a.map {|row| (0..11).to_a.map {|col| -1}}
        
        # 96 Well coordinate map
        coordinates_96 = ('A'..'H').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}}
        
        # For each input plate get its associate matricies and place into appropriate empty 96 well matrix
        input_arr.each do |plt|
            
            # find the rc_list from where the deep well transfer coords match the coordinates_96
            display_rc_list = []
            deep_well_transfer_coords = plt.get('deep_well_transfer_coords') # Contains coords like: "A1", "A2"...
            deep_well_transfer_coords.flatten.each do |coord|
                coordinates_96.map.each_with_index do |row, r_idx|
                    col_idx = row.each_index.select {|well| row[well] == coord}
                    col_idx.each {|c_idx| display_rc_list.push([r_idx, c_idx])}
                end
            end
            
            # Find associated matricies
            experimental_media_mat = plt.get('experimental_media_mat')
            sample_id_mat = Collection.find(plt.id).matrix
            
            # Use display_rc_list to place information into the appropriate well
            deep_well_transfer_coords.flatten.each_with_index do |coord, idx|
                r, c = display_rc_list[idx]
                transfer_coordinates[r][c] = coord
            end
            
            # Use display_rc_list to place correct experimental media info into the correct well
            experimental_media_mat.flatten.each_with_index do |coord, idx|
                r, c = display_rc_list[idx]
                (coord.nil?) ? experimental_media_matrix_96[r][c] = -1 : experimental_media_matrix_96[r][c] = coord
            end
            
            # Use display_rc_list to place correct sample_id/strain info into the correct well
            sample_id_mat.flatten.each_with_index do |coord, idx|
                r, c = display_rc_list[idx]
                (coord.nil?) ? sample_id_matrix_out[r][c] = -1 : sample_id_matrix_out[r][c] = coord
            end
        end
        return transfer_coordinates, experimental_media_matrix_96, sample_id_matrix_out
    end

    
    
end # Class

