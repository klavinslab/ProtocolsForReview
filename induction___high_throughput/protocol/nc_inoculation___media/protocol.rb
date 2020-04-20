# By: Eriberto Lopez
# elopez3@uw.edu
# 05/11/18
# °C µl


# Protocol Outline
# Create new container
# Read csv with glycerol plate layout - should generate a new object/container with data matrix filled with sample ids
# Thaw, aliquot media, and set in incubator (specific temp)


needs "Standard Libs/Debug"
needs "YG_Harmonization/Upload_PlateReader_Data"
needs "Tissue Culture Libs/CollectionDisplay"

class Protocol
    
    include Debug
    include Upload_PlateReader_Data
    include CollectionDisplay
    
    EXPERIMENTAL_FILENAME = "Experimental_Plan"
    OUTPUT = "96 Deep Well Plate"
    
    # Antibiotic Parameters
    STOCK_KAN_CONC = 10#mg/mL
    FINAL_KAN_CONC = "Kanamycin Concentration (µg/mL)"
    STOCK_CHLOR_CONC = 25#mg/mL
    FINAL_CHLOR_CONC = "Chloramphenicol Concentration (µg/mL)"
    
    # Temperature
    INCUB_TEMP = "Temperature (°C)"
    
    # Media
    ECOLI_MEDIA = 'M9'
    
    
    def main
        intro()
        # Create output container 
        operations.make 
        operations.each do |op|
            
            # Name of experimental plan as a parameter
            filename = op.input(EXPERIMENTAL_FILENAME).val.to_s
            
            # Upload experimental plan .csv
            up_show, up_sym = upload_experimental_plan(filename)
            
            if debug
                upload = Upload.find(23959) # Test upload v2
                log_info 'EXPERIMENTAL UPLOAD', 'upload', upload, upload.id, upload.url
            else
                while (up_show[up_sym].nil?) do
                    show {note "<b>No upload found!!! Please try again.</b>"}
                    up_show, up_sym = upload_experimental_plan(filename)
                end
                upload = find_upload_from_show(up_show, up_sym)
            end
            
            # matrix contains multiple types of information
            matrix = read_url(upload)
            
            # 96 well layout from the experimental plan csv
            # sample_id_mat => a 2-D array that contains the layout of the strains in the experiment
            sample_id_mat = experimental_layout('sample_id_mat', matrix)
            
            # overnight_antibiotic_mat => would be useful to know which wells will get which media and count up how much media to make for each condition
            overnight_antibiotic_mat = experimental_layout('overnight_antibiotic_mat', matrix)
            
            # inducer_mat => would be useful to know how much media with inducer to make for each desired condition
            inducer_mat = experimental_layout('inducer_mat', matrix)
            
            # experimental_antibiotic_mat => would be useful to know which wells will get which media and count up how much media to make for each condition
            experimental_antibiotic_mat = experimental_layout('experimental_antibiotic_mat', matrix)
            
            # Associate matricies to the output collection
            out_collection = op.output(OUTPUT).collection
            out_collection.matrix = sample_id_mat
            out_collection.save
            associate_to_item(out_collection, 'overnight_antibiotic_mat', overnight_antibiotic_mat)
            associate_to_item(out_collection, 'inducer_mat', inducer_mat)
            associate_to_item(out_collection, 'experimental_antibiotic_mat', experimental_antibiotic_mat)
            
            
            ### Using media_hashes to calculate how much media is needed for overnight and experimental parts of protocol ### 
            
            # Media for overnights - 200µl/well
            overnight_media_hash = condition_hash(overnight_antibiotic_mat) 
            # log_info 'overnight_media_hash', overnight_media_hash
            
            ### Media for NC_Inoculation  ###
            overnight_media_hash.each do |anti, quant|
                overnight_media_hash[anti] = quant * 200#µl
            end
            # log_info 'overnight_media_hash', overnight_media_hash
            
            ### Experimental Media: NC_Recovery, NC_Plate Reader, & NC_Large vol induction ###
            experimental_antibiotic_hash = condition_hash(experimental_antibiotic_mat)
            # log_info 'experimetnal media hash', experimental_antibiotic_hash
            
            experimental_antibiotic_hash.each do |anti, quant|
                experimental_antibiotic_hash[anti] = quant * (160  + 1000 + 200 + 200 + 3000)#ul # NC_R_vol_for_flat_96_1 + NC_R_vol_for_deep_96_2 + NC_PR_flat_96_3 + NC_PR_flat_96_4 + NC_Lrg_Vol_culture_plates_5h
            end
            # log_info 'experimetnal media hash', experimental_antibiotic_hash
            
            # Total media needed for whole workflow - could make total media function
            total_media_hash = Hash.new(0)
            overnight_media_hash.each do |anti, quant|
                if !total_media_hash.include? anti
                    total_media_hash[anti] = quant
                    if !experimental_antibiotic_hash[anti].nil?
                        total_media_hash[anti] += experimental_antibiotic_hash[anti]
                    end
                else
                    total_media_hash[anti] += quant
                    if !experimental_antibiotic_hash[anti].nil?
                        total_media_hash[anti] += experimental_antibiotic_hash[anti]
                    end
                end
            end
            
            # Direct tech to remove glycerol plate from freezer
            thawing_glycerol_stk_plate
            
            # Direct tech to aliquot and create antibiotic media
            total_media_hash.each { |anti, quant|
                kan_stk_vol = 0
                chlor_stk_vol = 0
                (anti.include? 'Kan') ? kan_stk_vol = (op.input(FINAL_KAN_CONC).val.to_f * (quant))/(STOCK_KAN_CONC*1000) : 0
                (anti.include? 'Chlor') ? chlor_stk_vol = (op.input(FINAL_CHLOR_CONC).val.to_f * (quant))/(STOCK_CHLOR_CONC*1000) : 0
                show {
                    if anti == 'None'
                        title "Aliquoting #{ECOLI_MEDIA} Media"
                        separator
                        check "In the appropriate container aliquot: <b>#{quant.to_f/1000}mL</b> of <b>#{ECOLI_MEDIA} Media</b>"
                        check "Label, date, & initial the container: <b>#{ECOLI_MEDIA} Media</b>"
                    else
                        title "Creating Antibiotic Media: #{ECOLI_MEDIA + ' + ' + anti}"
                        separator
                        check "In the appropriate container aliquot: <b>#{quant.to_f/1000}mL</b> of <b>#{ECOLI_MEDIA} Media</b>"
                        (kan_stk_vol > 0) ? (check "To that aliquot, add <b>#{kan_stk_vol}µl</b> of <b>Kanamycin Stock (#{STOCK_KAN_CONC}mg/mL)</b>") : nil
                        (chlor_stk_vol > 0) ? (check "To that aliquot, add <b>#{chlor_stk_vol}µl</b> of <b>Chloramphenicol Stock (#{STOCK_CHLOR_CONC}mg/mL)</b>") : nil
                        check "Label, date, & initial the container: <b>NC_#{ECOLI_MEDIA + ' + ' + anti}</b>"
                    end
                }
            }
        
            
            # Creates rc_lists of plate by media in order to display certain parts of the plate that will be inoculated
            overnight_media_rclist = overnight_media_rclist(out_collection, overnight_antibiotic_mat)
            
            # Filling out_collection plate wells with appropriate types of media
            fill_plate_with_media(out_collection, overnight_media_rclist) # Needs to be automated to fit other conditions
            
            inoculating_deep_well(out_collection)
            
            incubation_temp = op.input(INCUB_TEMP).val.to_i
            # Change location of output collection and direct tech to set at 37C for ~16 hours
            out_collection.location = "#{incubation_temp}°C incubator on 800rpm shaker"
            out_collection.save
            release [out_collection], interactive: true
        end
        show {
            title "Clean Up"
            separator
            check "Clean up bench before ending protocol :D"
        }
        
    end # main
    
    
    def intro()
        show do
            title "Introduction - Novel Chassis Inoculation"
            separator
            note "In this experiment you will be growing cultures that contain synthetic genetic circuits."
            note "<b>1.</b> Upload Experimental Plan"
            note "<b>2.</b> Create media"
            note "<b>3.</b> Thaw and resuspend 96 Well Glycerol Stock Plate"
            note "<b>4.</b> Incubate Plate"
        end
    end

        
    def condition_hash(condition_mat)
        cond_hash = Hash.new(0)
        condition_mat.each do |row|
            row.each do |well|
                if well != "-1"
                    if !cond_hash.include? well
                        cond_hash[well] = 1
                    else
                        cond_hash[well] += 1
                    end
                end
            end
        end
        return cond_hash
    end
    
    # This function is used for parsing out the matrix that is read from the experimental plan csv
    #
    # @params string [string] is the string used to identify the portion of the matrix that is read from the experimental plan csv
    # @params matrix [2-D Array] is the complete matrix that is read from the experimental plan csv
    # 
    # @returns arr [2-D Array] is the 2-D array in 96 Well format which maps a desired condition based on the string
    def experimental_layout(string, matrix)
        matrix.each_with_index do |row, idx|
            if row.include? string
                matrix = matrix[idx..(idx + 8)] 
                # Removing rows and columns from 96 well format
                arr = matrix[1..matrix.length].map do |row|
                    if string == 'sample_id_mat'
                        row[1..row.length].map {|i| i.to_i}
                    else
                        row[1..row.length].map {|i| i}
                    end
                end
                return arr
            end
        end
    end
    
    
    # Provides a upload button in a showblock in order to upload a single file
    #
    # @params upload_filename [string] can be the name of the file that you want tech to upload
    # @return up_show [hash] is the upload hash created in the upload show block
    # @return up_sym [symbol] is the symbol created in upload show block that will be used to access upload
    def upload_experimental_plan(upload_filename)
        upload_var = "experimental_plan"
        up_sym = upload_var.to_sym
        up_show = show do
            title "Upload Your Experimental Plan"
            separator
            note "Select and Upload: #{upload_filename}"
            upload var: "#{upload_var}"
        end
        return up_show, up_sym
    end

    # Creating rc_lists to direct tech to fill 96 Deep Well plate with appropriate media type
    def overnight_media_rclist(out_collection, overnight_antibiotic_mat)
        coordinates = out_collection.get_non_empty.each_slice(11).to_a # 11 comes from the known number of samples in each row
        kan_media_coordinates = []
        kan_chlor_coordinates = []
        no_anti_media_coordinates = []
        overnight_antibiotic_mat.each_with_index do |row, r_idx|
            row.each_with_index do |col, c_idx|
                if col == 'Kan'
                    kan_media_coordinates.push(coordinates[r_idx][c_idx])
                elsif col == 'Kan_Chlor'
                    kan_chlor_coordinates.push(coordinates[r_idx][c_idx])
                elsif col == 'None'
                    no_anti_media_coordinates.push(coordinates[r_idx][c_idx])
                end
            end
        end
        return [[no_anti_media_coordinates,'M9'], [kan_media_coordinates,'M9 + Kan'], [kan_chlor_coordinates, 'M9 + Kan + Chlor']]
    end

    # Filling out_collection plate with media
    def fill_plate_with_media(collection, rc_list)
        count = 0
        rc_list.each do |media_coords, med_type|
            media_vol = (media_coords.length + 2) * 0.2#mL
            show do
                title "Filling 96 Deep Well <b>#{collection.id}</b>"
                separator
                if count == 0
                    check "Obtain a <b>96 Deep Well plate</b> and label with #<b>#{collection.id}</b>"
                end
                check "Aliquot <b>#{media_vol.round(2)}mL</b> of <b>#{med_type}</b> into a clean reservoir."
                note "Follow the table below to fill Deep Well plate with <b>180µl</b> the appropriate media:"
                table highlight_rc(collection, media_coords) {|r,c| med_type}
            end
            count += 1
        end
    end
    
    def thawing_glycerol_stk_plate()            
        show do
            title "Thawing 96 Well Glycerol Stock Plate"
            separator
            note "Before inoculation we must thaw out our glycerol stocks."
            check "From the -80°C freezer, obtain a sealed 96 Well Glycerol Plate - Ask EL if needed."
            check "With the foil seal still on, place on bench to thaw."
            bullet "Continue to the next step while plate is thawing."
        end
    end
    def inoculating_deep_well(collection)
        show do
            title "Inoculate 96 Deep Well #{collection.id}"
            separator
            check "Make sure that the glycerol plate has thawed."
            check "Transfer <b>20µl</b> of glycerol stock to the 96 Deep Well Plate filled with media."
            bullet "Inoculate from the glycerol stock plate to the 96 Deep Well Plate in the same layout."
            note "Move #{collection.id} to the #{operations.first.input(INCUB_TEMP).val.to_i}°C incubator and place on shaker - 800rpm."
        end
    end
    
end # Class