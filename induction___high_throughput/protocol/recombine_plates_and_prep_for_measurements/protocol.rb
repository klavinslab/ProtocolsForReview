# By: Eriberto Lopez
# elopez3@uw.edu
# 05/30/18
# C l

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
# needs "Plate Reader Lib/PlateReaderHelper"
needs "Induction - High Throughput/HighThroughputHelper"
needs "Standard Libs/MatrixTools"
needs "Standard Libs/AssociationManagement"

class Protocol
    
    include Debug
    include Upload_PlateReader_Data
    include PlateReaderMethods
    include CollectionDisplay
    include NovelChassisLib
    # include PlateReaderHelper
    include HighThroughputHelper
    include MatrixTools
    include AssociationManagement
    include PartProvenance
    
    #I/O
    INPUT = "24 Deep Wells"
    OUT_FC_PLT = "Flow Cytometry Plate"
    OUT_PLT_RDR_PLT = "Plate Reader Plate"
    OUT_RNA_PLT = "RNA Prep Plate"
    
    # Constants
    FC_PLT_TRANSFER_VOL = 20#l
    PLT_RDR_PLT_TRANSERFER_VOL = 300#l


    def main
        
        operations.make # Creates output plates
        
        intro()
        
        operations.each { |op|
            # gather_materials(op)
            
            input_item_arr = op.input_array(INPUT).collections
            
            # from the associated matricies of the input 24 Wells piece together a new 96 Well matrix
            experimental_anti_matrix_96, media_type_matrix_96, inducer_matrix_96, sample_id_matrix_out, overnight_anti_matrix_96, ctag_matrix_96 = transferring_24s_to_96_matricies(input_item_arr)
            
            # pass plate data along from recombined input plates onto each output plate
            op.outputs.each do |out|
                out_plate = out.collection
                
                out_plate.matrix = sample_id_matrix_out
                out_plate.save
        
                # out_plate.set_data_matrix("deep_well_transfer_coords",transfer_coordinates)
                out_plate.set_data_matrix("Overnight Antibiotic",overnight_anti_matrix_96)
                out_plate.set_data_matrix("Experimental Antibiotic",experimental_anti_matrix_96)
                out_plate.set_data_matrix("Type of Media",media_type_matrix_96)
                out_plate.set_data_matrix("Inducers",inducer_matrix_96)
                out_plate.set_data_matrix("Control Tag", ctag_matrix_96)
            end
            
            
            
            out_fc_plt = op.output(OUT_FC_PLT).collection
            plate_reader_plate = op.output(OUT_PLT_RDR_PLT).collection
            rna_plate = op.output(OUT_RNA_PLT).collection
            
            prepare_flow_cytometry_plate(out_fc_plt)
            prepare_plate_reader_plate(plate_reader_plate)
            prepare_rna_plate(rna_plate)
            
            # Grab 24 Deep Wells from Incubator shaker
            take input_item_arr, interactive: true
            
            # Transfer cultures from 24 Deep wells to FC flat bottom plate & plate reader plate
            coordinates_96 = ('A'..'H').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}} # 96 Well coordinate map
            count = 0
            spin_down_plates = []
            input_item_arr.each do |plt|
                # find the rc_list from where the deep well transfer coords match the coordinates_96
                display_rc_list = []
                deep_well_transfer_coords = plt.data_matrix_values('deep_well_transfer_coords') # Contains coords like: "A1", "A2"...
                deep_well_transfer_coords.flatten.each do |coord|
                    coordinates_96.map.each_with_index do |row, r_idx|
                        col_idx = row.each_index.select {|well| row[well] == coord}
                        col_idx.each {|c_idx| display_rc_list.push([r_idx, c_idx])}
                    end
                end
                
                # Add provenance between input plates and output plates using the deep_well_transfer_coords of this output plate
                op.outputs.each do |output|
                    out_plate = output.collection
                    in_plate = plt
                    out_plate_associations = AssociationMap.new(out_plate)
                    in_plate_associations = AssociationMap.new(in_plate)
                    in_plate.dimensions[0].times do |r_idx|
                      in_plate.dimensions[1].times do |c_idx|
                        to_coord = WellMatrix.numeric_coordinate(deep_well_transfer_coords[r_idx][c_idx])
                        if (in_plate.matrix[r_idx][c_idx] != -1)
                          add_provenance({
                              from: in_plate, 
                              from_map: in_plate_associations,
                              from_coord: [r_idx, c_idx],
                              to: out_plate,
                              to_coord: to_coord,
                              to_map: out_plate_associations
                          })
                        end
                      end
                    end
                    out_plate_associations.save
                    in_plate_associations.save
                end
                
                show do
                    title "Transferring Culture to Output Plates"
                    separator
                    note "Follow the table below to transfer culture from the 24 Deep Well Plate #{plt.id} to Plate #{out_fc_plt.id} & Plate #{plate_reader_plate.id}"
                    check "To plate <b>#{out_fc_plt.id}</b> transfer <b>#{FC_PLT_TRANSFER_VOL}l</b>"
                    check "To plate <b>#{plate_reader_plate.id}</b> transfer <b>#{PLT_RDR_PLT_TRANSERFER_VOL}l</b>"
                    collection = out_fc_plt # This is just for displaying both out_fc_plt and plate_reader_plate should have the same matricies associated in the same layout
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
                        check "Centrifuge plates <b>#{spin_down_plates.flatten}</b> at <b>4C, 4000rpm, for 10 mins</b>"
                        note "Once plates are finished being centrifuged aspirate supernatant without disturbing the cell pellets."
                        bullet "Continue on to the next step once plates are being centrifuged."
                    }
                    spin_down_plates = []
                end
            end
            
            # Once 24 Deep wells have been spun down and supernatant has been removed
            input_item_arr.each do |plt|
                # find the rc_list from where the deep well transfer coords match the coordinates_96
                display_rc_list = []
                deep_well_transfer_coords = plt.data_matrix_values('deep_well_transfer_coords') # Contains coords like: "A1", "A2"...
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
                    collection = out_fc_plt # This is just for displaying
                    bullet "<b>Coordinates correspond to the wells in plate #{plt.id}</b>"
                    table highlight_rc(collection, display_rc_list) {|r,c| "#{coordinates_24(r, c)}"}
                end
            end            
            # Once RNA plate has been filled, centrifuge once more to remove supernatant
            show {
                title "Collecting Cell Pellets"
                separator
                note "Once all cell pellets have been resuspended and collected on to Plate #{rna_plate.id}"
                check "Centrifuge Plate <b>#{rna_plate.id}</b> at <b>4C, 4000rpm, for 10 mins</b>"
                check "Once done, remove supernatant, seal with aluminumn foil cover, and place in the -80C freezer."
                rna_plate.location = " -80C freezer"
                rna_plate.save
            }
        }
        
        cleaning_up()
        
    end # Main


    def intro()
        show {
            title "Introduction - High Throughput Sampling & Harvesting"
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
            check "Set large centrifuge to 4C"
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
    
    def prepare_flow_cytometry_plate(plt)
        show {
            title "Preparing Flow Cytometry Measurement Plate"
            separator
            check "Gather a 96 Flat Bottom (black) plate"
            check "Label Plate <b>#{plt.id}</b>"
            bullet "Continue to the next step when ready"
        }
        show {
            title "Preparing Flow Cytometry Measurement Plate"
            separator
            note "The PBS+Kan Solution will arrest ribosomal transcription"
            check "Gather a multichannel resivior for <b>PBS+Kan Solution</b>"
            note "Follow the table below to fill plate the appropriate wells with <b>PBS+Kan</b>"
            table highlight_non_empty(plt) {|r,c| '180l'}
        }
    end
    
    def prepare_plate_reader_plate(plt)
        show {
            title "Preparing Plate Reader Measurement Plate"
            separator
            check "Gather a 96 Flat Bottom (black) plate"
            check "Label Plate <b>#{plt.id}</b>"
            bullet "Continue on the the next step to fill with culture."
        }
    end
    
    def prepare_rna_plate(plt)
        show {
            title "Preparing RNA Prep Plate"
            separator
            check "Gather a eppendorf 96 deep well plate"
            check "Label plate <b>#{plt.id}</b>"
            bullet "Continue on to the next step to fill with culture."
        }
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
    
    # bad bad redundant method
    def transferring_24s_to_96_matricies(input_arr)
        # Empty 96 well dimesion matricies
        transfer_coordinates = (0..7).to_a.map {|row| (0..11).to_a.map {|col| -1}}
        overnight_anti_matrix_96 = (0..7).to_a.map {|row| (0..11).to_a.map {|col| -1}}
        experimental_anti_matrix_96 = (0..7).to_a.map {|row| (0..11).to_a.map {|col| -1}}
        media_type_matrix_96 = (0..7).to_a.map {|row| (0..11).to_a.map {|col| -1}}
        inducer_matrix_96 = (0..7).to_a.map {|row| (0..11).to_a.map {|col| -1}}
        ctag_matrix_96 = (0..7).to_a.map {|row| (0..11).to_a.map {|col| -1}}
        sample_id_matrix_out = (0..7).to_a.map {|row| (0..11).to_a.map {|col| -1}}
        
        # 96 Well coordinate map
        coordinates_96 = ('A'..'H').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}}
        
        # For each input plate get its associate matricies and place into appropriate empty 96 well matrix
        input_arr.each do |plt|
            
            # find the rc_list from where the deep well transfer coords match the coordinates_96
            display_rc_list = []
            deep_well_transfer_coords = plt.data_matrix_values('deep_well_transfer_coords') # Contains coords like: "A1", "A2"...
            
            deep_well_transfer_coords.flatten.each do |coord|
                coordinates_96.map.each_with_index do |row, r_idx|
                    col_idx = row.each_index.select {|well| row[well] == coord}
                    col_idx.each {|c_idx| display_rc_list.push([r_idx, c_idx])}
                end
            end
            
            
            # Use display_rc_list to place information into the appropriate well
            # build_96_matrix(plt.matrix, display_rc_list, transfer_coordinates)
            
            # Use display_rc_list to place correct media info into the correct well
            overnight_anti_mat       = plt.data_matrix_values('Overnight Antibiotics')
            build_96_matrix(overnight_anti_mat, display_rc_list, overnight_anti_matrix_96)

            
            # Use display_rc_list to place correct media info into the correct well
            experimental_anti_mat       = plt.data_matrix_values('Experimental Antibiotics')
            build_96_matrix(experimental_anti_mat, display_rc_list, experimental_anti_matrix_96)
            
            media_type_mat              = plt.data_matrix_values("Type of Media")
            build_96_matrix(media_type_mat, display_rc_list, media_type_matrix_96)
            
            inducer_mat                 = plt.data_matrix_values("Inducers")
            build_96_matrix(inducer_mat, display_rc_list, inducer_matrix_96)
            
            ctag_mat                 = plt.data_matrix_values("Control Tag")
            build_96_matrix(ctag_mat, display_rc_list, ctag_matrix_96)
            
            # Use display_rc_list to place correct sample_id/strain info into the correct well
            sample_id_mat = Collection.find(plt.id).matrix
            build_96_matrix(sample_id_mat, display_rc_list, sample_id_matrix_out)
        end
        return [experimental_anti_matrix_96, media_type_matrix_96, inducer_matrix_96, sample_id_matrix_out, overnight_anti_matrix_96, ctag_matrix_96]
    end

    def build_96_matrix(in_matrix, rc_list, matrix_96)
        in_matrix.flatten.each_with_index { |coord, idx|
            r, c = rc_list[idx]
            (coord.nil?) ? matrix_96[r][c] = -1 : matrix_96[r][c] = coord
        }
        return matrix_96
    end

end # Class

