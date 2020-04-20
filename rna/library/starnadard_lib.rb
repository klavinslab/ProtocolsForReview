# Eriberto Lopez
# elopez3@uw.edu
# 08/24/18
# A module for commonly used functions in the RNA operation type catagory.
# °C µl
module StaRNAdard_Lib
    ICE_LOC = 'Seelig Lab'
    require 'csv'
    require 'open-uri'


    def show_multichannel_stripwell(collection, reagent_name, rxn_vol)
        sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(collection)
        show do
            title "Aliquot #{reagent_name} into Multichannel Stripwell"
            separator
            check "Gather <b>#{reagent_name}</b>"
            note "Follow the table below to aliquot #{reagent_name} the for a multichannel pipette:"
            table highlight_alpha_rc(sw, rc_list) {|r,c| "#{sw_vol_mat[r][c]*rxn_vol}µl"}
            bullet "If this buffer has an enzyme keep stripwell on ice (ie: qPCR Master Mix)"
        end
        # Delete temporary stripwell that was created for multichannel pipetting
        sw.mark_as_deleted
        sw.save
    end


    
    # Used for multichannel pipetting, creates a stripwell to display with the number of aliquots of the desired reagents
    #
    # @params collection [colleciton obj] is the collection that you be aliquoting reagent to
    # @returns sw [collection obj] the stripwell obj that will be used to display
    # @returns sw_vol_mat [2D-Array] is the matrix that contains the information of how many aliquots of reagents go in each well
    # @returns rc_list [Array] is a list of [r,c] tuples that will be used to display which wells are to be used for aliquots
    def multichannel_vol_stripwell(collection)
        # Create a stripwell to display
        sw_obj_type = ObjectType.find_by_name('stripwell')
        sw = Collection.new()
        sw.object_type_id = sw_obj_type.id
        sw.apportion(sw_obj_type.rows, sw_obj_type.columns)
        sw.quantity = 1
        
        # Create a matrix the size of the stripwell
        sw_vol_mat = Array.new(sw_obj_type.rows) { Array.new(sw_obj_type.columns) {0} }
        
        # For the non empty wells in the collection that you are aliquoting add 1 to the sw_vol_mat in the appropriate col
        non_empty_rc_list = collection.get_non_empty
        
        # Edited - 092518 EL
        #.first
        # starting_r, starting_c = 7, 0 #non_empty_rc_list[0]#.first
        # rc_list = []
        # matrix = []
        # non_empty_rc_list.each {|rc|
        #     row, col = rc
        #     if row == starting_r
        #         rc_list.push(rc)
        #     else
        #         (12 - rc_list.length).times do
        #             rc_list.push(-1)
        #         end
        #         matrix.push(rc_list)
        #         rc_list = [rc]
        #         starting_r = row
        #     end
        # }
        # log_info 'non_empty_rc_list', non_empty_rc_list
        # log_info "starting_r, starting_c", starting_r, starting_c
        # log_info 'rc_list', rc_list
        # log_info "matrix", matrix
        # matrix.each_with_index {|row, r_idx|
        #     row.each_with_index {|col, c_idx|
        #         if col != -1
        #             sw_vol_mat[0][c_idx] += 1
        #         end
        #     }
        # }

        
        non_empty_rc_list.each {|r, c| sw_vol_mat[0][c] += 1}
        
        # Collect tuples [r,c] for the wells that have master mix/reagent aliquoted 
        rc_list = sw_vol_mat[0].each_with_index.map {|well, w_idx| (well == 0) ? nil : [0, w_idx] }.select {|rc| rc != nil}
        return sw, sw_vol_mat, rc_list
    end    
    
    
    
    # Finds where an alpha_coordinate is in a 96 Well plate
    #
    # @params alpha_coord [array or string] can be a single alpha_coordinate or a list of alpha_coordinate strings ie: 'A1' or ['A1','H7']
    # @return rc_list [Array] a list of [r,c] coordinates that describe where the alpha_coord(s) are in a 96 well matrix
    def find_rc_from_alpha_coord(alpha_coord)
        # look for where alpha coord is 2-D array coord
        coordinates_96 = ('A'..'H').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}} 
        rc_list = []
        if alpha_coord.instance_of? Array
            # alpha_coord = alpha_coord.map {|a| a.upcase}
            alpha_coord.each {|a_coord|
                coordinates_96.map.each_with_index { |row, r_idx| row.each_index.select {|col| row[col] == a_coord.upcase}.each { |c_idx| rc_list.push([r_idx, c_idx]) } } 
            }
        else
            coordinates_96.map.each_with_index { |row, r_idx| row.each_index.select {|col| row[col] == alpha_coord.upcase}.each { |c_idx| rc_list.push([r_idx, c_idx]) } }
        end
        return rc_list
    end
    
    def get_alpha_coord(rc_tup)
        r, c = rc_tup
        coordinates_96 = ('A'..'H').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}} 
        return coordinates_96[r][c]
    end
    
    
    def find_alpha_coord_from_rc(r, c)
        coordinates_96 = ('A'..'H').to_a.map {|row| (1..12).to_a.map {|col| row + col.to_s}} 
        return coordinates_96[r][c]
    end

    # Caluclates reagent volume plus 10%
    #
    # @params num_ops [int] the number of operations/rxns/sample
    # @params single_samp_vol [int] the vol of the reagent for a single sample/rxn
    def reagent_vol_with_extra(num_ops, single_samp_vol)
        # Includes 10% extra volume
        return ((num_ops * single_samp_vol) + (num_ops * single_samp_vol)*0.10).round(2)  
    end

    def general_sanitize()
        show do
            title "Sanitize Working Bench"
            separator
            note "This assay is sensitive to contamination from multiple sources."
            bullet "Adhere to good molecular biology practices."
            check "Before starting, clean bench and all equiptment you will be using with 10% Bleach."
            check "Then, wipe down with 70% Ethanol."
        end
    end
    
    # Rounds value to the nearest whole ten
    #
    # @params value [int] the value that is to be rounded
    # @returns nearest [int] the rounded value
    def round_to_nearest_ten(value)
        nearest = (value/ 10).round * 10
        return nearest
    end
    
    # Rounds value to the nearest whole five
    #
    # @params value [int] the value that is to be rounded
    # @returns nearest [int] the rounded value
    def round_to_nearest_five(value)
        nearest = (value/5).round * 5
        return nearest
    end
    # Directs tech to get ice and lower centrifuge temp
    def get_ice(cool_centrifuge=true)
        show do
            title "Get Ice"
            separator
            note "<b>Keeping samples and reagents cold is important to slow down enzymes that may diminish nucleic acid integrity.</b>"
            check "Grab a foam bucket from underneath the sink."
            check "Go to the #{ICE_LOC} ice machine and fill up your bucket."
            # check "Fill a foam ice bucket, located underneath sink."
            if cool_centrifuge
                check "Set a benchtop and large centrifuge to 4°C"
            end
        end
    end

    def create_stripwell_collection()
        # Create a stripwell to display
        sw_obj_type = ObjectType.find_by_name('Sequencing Stripwell')
        sw = Collection.new()
        sw.object_type_id = sw_obj_type.id
        sw.apportion(sw_obj_type.rows, sw_obj_type.columns)
        sw.quantity = 1
        return sw 
    end
    
    # Allows for the operation to pass the the collection/item with the same item_id
    def collections_pass(op, input_name, output_name = nil)
        
        output_name ||= input_name
        fv_in = op.input(input_name)
        fv_out = op.output(output_name)
        raise "Could not find input '#{input_name}' in pass" unless fv_in
        raise "Could not find input '#{output_name}' in pass" unless fv_out
        
        fv_out.child_sample_id = fv_in.child_sample_id
        fv_out.child_item_id = fv_in.child_item_id
        fv_out.row = fv_in.row
        fv_out.column = fv_in.column

        fv_out.save
        
        self
    end
    
    # Provides a upload button in a showblock in order to upload a single file
    #
    # @params upload_filename [string] can be the name of the file that you want tech to upload
    # @return up_show [hash] is the upload hash created in the upload show block
    # @return up_sym [symbol] is the symbol created in upload show block that will be used to access upload
    def upload_show(upload_path, upload_filename)
        upload_var = "file"
        up_sym = upload_var.to_sym
        up_show = show do
            title "Upload Your Measurements"
            separator
            note "Select and Upload: #{upload_filename}"
            bullet "Find the file in the <b>#{upload_path}</b> directory"
            upload var: "#{upload_var}"
        end
        return up_show, up_sym
    end
    
    # Retrieves the upload object from upload show block
    #
    # @params up_show [hash] is the hash that is created in the upload show block
    # @params up_sym [symbol] is the symbol created in the upload show block and used to access file uploaded
    # @return upload [upload_object] is the file that was uploaded in the upload show block
    def find_upload_from_show(up_show, up_sym)
        # Makes a query to find the uploaded file by its default :id
        upload = up_show[up_sym].map {|up_hash| Upload.find(up_hash[:id])}.shift 
        return upload
    end
    
    # Opens file using its url and stores it line by line in a matrix
    #
    # @params upload [upload_obj] the file that you wish to read from
    # @return matrix [2D-Array] is the array of arrays of the rows read from file, if csv
    def read_url(upload)
        url = upload.url
        matrix = []
        CSV.new(open(url)).each {|line| matrix.push(line)}
        # open(url).each {|line| matrix.push(line.split(',')}
        return matrix
    end
end # Module StaRNAdard_Lib
