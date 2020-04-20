
needs "Standard Libs/Debug"
needs "Standard Libs/UploadHelper"
needs "Plate Reader/PlateReaderHelper"
needs "Tissue Culture Libs/CollectionDisplay"
needs 'YG_Harmonization/Upload_PlateReader_Data'
needs "Standard Libs/Feedback"

class Protocol

    require 'date'
    
    # Standard Libs
    include Debug, UploadHelper, Feedback
    
    
    # Other Libs
    include CollectionDisplay
    include PlateReaderHelper
    # include Upload_PlateReader_Data
    
    # I/O
    INPUT = "Cells"
    OUTPUT = "96 Well Flat Bottom Plate"
    
    # Parameters
    MEASUREMENT_TYPE = 'Type of Measurement(s)'
    MEDIA_TYPE = 'Type of Media'
    DILUTION_FACTOR = "Dilution Factor"
    
    # Constants
    TEMPLATE_FILENAME = {'OD'=>'OD600_GFP_measurement', 'OD_GFP'=>'OD600_GFP_measurement', 'CAL_OD_GFP'=>'calibration_template_v1'} # always collect both OD & GFP and decide which to export
    MEASUREMENTS = {'OD'=>['od'], 'OD_GFP'=>['od','gfp'], 'CAL_OD_GFP'=>['cal_od', 'cal_gfp']}
    PLATES = ['24 Deep Well Plate', '96 U-bottom Well Plate', '96 Well Flat Bottom (black)']
    MAX_CUVETTE_VOLUME = 1000
    MAX_BWP_VOLUME = 300
    MAX_CUVETTES = 12
    NANODROP_2000 = "Actions/Yeast_Gates/spectrophotometerImages/open_spec_workspace.PNG"
    MEASURE = "Actions/Yeast_Gates/spectrophotometerImages/measure_od.PNG"
    BLANK = "Actions/Yeast_Gates/spectrophotometerImages/blank_workspace.PNG"
    OPTICAL_MEASUREMENTS = "Actions/Yeast_Gates/spectrophotometerImages/optical_density_measurement_report.PNG"
    CUVETTE1 = "Actions/Yeast_Gates/spectrophotometerImages/cuvette1.jpg"
    CUVETTE2 = "Actions/Yeast_Gates/spectrophotometerImages/cuvette2.jpg"
    SPEC1 = "Actions/Yeast_Gates/spectrophotometerImages/spec1.jpg"
    SPEC2 = "Actions/Yeast_Gates/spectrophotometerImages/spec2.jpg"

    # CUVETTE_CONTAINERS = ['Overnight suspension', 'Transformed overnight suspension', 'Overnight suspension culture', 'Yeast Overnight Suspension', 'TB Overnight of Plasmid', 'TB Overnight (400 mL) of Plasmid', 'Yeast Overnight for Antibiotic Plate', 'Agro overnight culture', 'TB Overnight of Plasmid (Large)', 'Adjusted Overnight']

    def main
      
      # This protocol will accept plates and an array of overnights as inputs.
      # Depending on the input type, different steps will be shown to the user.

      input_object_type = operations.first.input_array(INPUT).first.item.object_type.name
      type_of_measurement = operations.first.input(MEASUREMENT_TYPE).val.to_s
      
      log_info 'input_object_type', input_object_type
      log_info 'type_of_measurement', type_of_measurement
      
      # # Make output collection if the input is not a 96 Well Flat Bottom (black) && input is a collection
      # #if (input_object_type != '96 Well Flat Bottom (black)' && input_object_type != 'Plastic Cuvette')
      # operations.make
      
      # Show measurement introduction for both plate reader or spectrophotometer
      if(operations.first.input_array(INPUT).length == 1 || operations.first.input_array(INPUT).length > MAX_CUVETTES)
        pr_intro
      else
        spec_intro
      end
      
      operations.each do |op|
        
        # Determines how much media and culture to add.
        dilution_factor = op.input(DILUTION_FACTOR).val.to_f
      
        # Do this for collections
        if !PLATES.include?(op.input_array(INPUT).first.item.object_type.name) &&  op.input_array(INPUT).length <= MAX_CUVETTES
           # This is the case where the user is using plastic cuvettes for cells.
          
          # Calculate Culture volume and media volume.
          cult_vol = MAX_CUVETTE_VOLUME / dilution_factor
          media_vol = MAX_CUVETTE_VOLUME - cult_vol
          
          # Get array of items from operation
          items = op.input_array(INPUT).items
          
          # Take array of overnights
          take items, interactive: true, method: 'boxes'
          
          # Gather cuvettes and container
          gather_cuvettes items  
          
          # Creates table of how much culture and media volume to add to each
          # cuvette. This then is displayed to the lab tech.
          display_volume_table items, cult_vol, media_vol
          
          # Return the overnight tubes
          release items, interactive: true, method: 'boxes'
          
          # Go to Seelig lab
          go_to_lab
          
          # Prepare spectrophotometer
          use_spectrophotometer
          
          show do
            title "Measure Blank Cuvette"
            
            check "check 'Use cuvettte' on the left side of the screen."
            check "Load blank solution into spectrophotometer. The triangle on the cuvette should align with the arrow on the spectrophotometer."
            check "Click blank."
            image BLANK
            check "Remove cuvette from spectrophotometer after blanking."
          end
          
          show do
            title "Measure Culture Cuvettes"
            
            check "Measure each culture cuvette. Press measure after loading a culture into the spectrophotometer."
            image OPTICAL_MEASUREMENTS
            check "Press cancel after measuring each cuvette."
            # add picture.
          end
          
            
          # Enter the measured OD for each item
          data_od = get_measured_ods items
          
          # Associates ODs for each overnight
          associate_overnights items, dilution_factor, data_od
          
          # Display a table for final ODs
            
            
            
    
          # Clean up
          cleanup
            
        else
                
          # Make an output collection in the case we need it.
          op_collection = Collection.new_collection('96 Well Flat Bottom (black)')
          
          # Calculate culture and media volume required based on the dilution factor
          cult_vol = MAX_BWP_VOLUME / dilution_factor
          media_vol = MAX_BWP_VOLUME - cult_vol
          
          # Set this if the input item is a plate. If it is a plate,
          # then define the in_collection variable for later use.
          if PLATES.include?(op.input_array(INPUT).first.item.object_type.name)
            in_collection = op.input_array(INPUT).first.collection
            if debug
              in_collection = Collection.find(394053)
            end
          end
          
          coordinate_matrix = []
          item_coordinate_hash = {}
          # If the inputs are overnights, and if there are more than MAX_CUVETTES.
          if !PLATES.include?(op.input_array(INPUT).first.item.object_type.name) && op.input_array(INPUT).length > MAX_CUVETTES
            
            # Take array of overnights
            take op.input_array(INPUT).items, interactive: true, method: 'boxes'
            
            show do
              note "You need to transfer overnights into plate"
              note "#{op.input_array(INPUT).items}"
            end
            
            log_info "overnights array", op.input_array(INPUT).items
            
            # make an array of sample ids for each item
            items = op.input_array(INPUT).items
            
            item_sample_ids = []
            items.each do |item|
              item_sample_ids.push(item.sample_id)
            end
            
            final_matrix = []
    
            # Transfers each item's sample id to the output collection
            out_collection = op_collection #op.output(OUTPUT).collection
            
            item_sample_ids.each_slice(out_collection.dimensions[1]) do |slice|
              final_matrix.push(slice)
            end
            
            out_collection.matrix = final_matrix
            out_collection.save
              
            log_info "overnights array in plate", out_collection.matrix

            out_collection.get_non_empty.each_with_index do |tuple, index|
              item_coordinate_hash[items[index].id] = tuple
            end
            
            # Prefills output plate with parameter vol media.
            prefill_media_cuvettes op, media_vol, op_collection
            
            # Transfers cultures from input plate to output plate reader plate that has been prefilled with media
            transfer_culture_cuvettes op, item_coordinate_hash, cult_vol, op_collection
            
            # Release overnights
            release items, interactive: true, method: 'boxes'

          # This is when there is only one element in the input array, 
          # and the element is a plate thats not a black flat bottom
          elsif input_object_type != '96 Well Flat Bottom (black)'
            out_collection = op_collection #op.output(OUTPUT).collection
       
            # Transfer the sample id matrix from the input collection to the 96 Well Flat Bottom (black)
            in_coll_matrix = in_collection.matrix.flatten
            final_matrix = []
            in_coll_matrix.each_slice(out_collection.dimensions[1]) do |slice|
              final_matrix.push(slice)
            end
            out_collection.matrix = final_matrix   
            out_collection.save
            
            log_info "in_collection matrix", in_collection.matrix
            log_info "out_collection matrix", out_collection.matrix
            
            # Makes coordinate matrix to tell the tech how to transfer from the input collection to output collection.
            coordinate_matrix = make_coordinate_matrix in_collection, out_collection
            
            # Tells the tech to get the input collection
            take [Item.find(op.input(INPUT).collection.id)], interactive: true
            
            # Prefills output plate with parameter vol media.
            prefill_media op, coordinate_matrix, media_vol, op_collection
            
            # Transfers cultures from input plate to output plate reader plate that has been prefilled with media
            transfer_culture op, coordinate_matrix, cult_vol, op_collection
            
            # Returns 96 deep well plate to incubator right after it has been sampled
            release [Item.find(op.input(INPUT).collection.id)], interactive: true
          end
      
          # Finds wells that are empty and fills them with blank slected media OR one can specify which wells they would like to use for media
          if (input_object_type != '96 Well Flat Bottom (black)')
            add_blanks(collection=out_collection, type_of_media=op.input(MEDIA_TYPE).val.to_s, tot_vol=MAX_BWP_VOLUME, blank_wells=nil)
          else
            add_blanks(collection=in_collection, type_of_media=op.input(MEDIA_TYPE).val.to_s, tot_vol=MAX_BWP_VOLUME, blank_wells=nil)
          end
          
          # Setup BioTek HT PlateReader workspace to collect measurement
          if (input_object_type != '96 Well Flat Bottom (black)')
            filename = set_up_plate_reader(out_collection, TEMPLATE_FILENAME[type_of_measurement])
          else
            filename = set_up_plate_reader(in_collection, TEMPLATE_FILENAME[type_of_measurement])
          end
          
          # Export measurements taken, upload, and associate data
          MEASUREMENTS[type_of_measurement].each do |method|
            
            # Set the file name
            if (input_object_type != '96 Well Flat Bottom (black)')
              filename = export_filename(out_collection, method, timepoint=nil)
            else
              filename = export_filename(in_collection, method, timepoint=nil)
            end
         
            # Directs tech how to save and export plate reader data from the BioTek HT
            export_plate_reader_data(filename, method) 
          
            # Show block upload button and retrieval of file uploaded
            up_show, up_sym = upload_show(filename)
            if (up_show[up_sym].nil?)
              show {warning "No upload found for #{method} measurements. Try again!!!"}
              up_show, up_sym = upload_show(filename)
            else
              time = Time.now
              
              # Retrieve the user-uploaded upload
              if debug
                upload = Upload.find(11187)
              else
                upload = find_upload_from_show(up_show, up_sym)
              end
              
              # Set the plan key
              if (input_object_type != '96 Well Flat Bottom (black)')
                plan_key = "Item_#{out_collection.id}_#{method.upcase}_#{time.strftime "%Y%m%d_%H_%M"}"
              else
                plan_key = "Item_#{in_collection.id}_#{method.upcase}_#{time.strftime "%Y%m%d_%H_%M"}"
              end
              
              # Associates upload to plan
              # associate_to_plans(key, upload) # For some reason, this associates the upload object to the plan, but as an object and not as a clickable link to download
              associate_to_plan(upload, plan_key)
              
              # If the input is a plate, then this associates the OD matrix to both
              # the input plate and output plate. The data is stored as a 2D matrix.
              if PLATES.include?(op.input_array(INPUT).first.item.object_type.name)
                # Account for dilution and associate plate reader data to item data associations as a matrix
                # dilution_factor = (op.input(CULT_VOL).val.to_f + op.input(MEDIA_VOL).val.to_f)/op.input(CULT_VOL).val.to_f
                
                # Associates data hash of measurements to item/collection
                associate_PlateReader_measurements(upload, in_collection, method, dilution_factor)
                in_collection.associate "was_recently_measured", true
                in_collection_item = Item.find(in_collection.id)
                in_collection_od_hash = in_collection_item.get("optical_density")
                log_info "in_collection_od_hash", in_collection_od_hash
                if (input_object_type != '96 Well Flat Bottom (black)')
                  associate_PlateReader_measurements(upload, out_collection, method, dilution_factor)
                  out_collection.associate "was_recently_measured", true
                end
                
              # If the input isn't a plate, then the ODs must be associated with each input item.  
              else
                matrix = (extract_measurement_matrix_from_csv(upload)).to_a
                items_flattened = matrix.flatten
             
                # get the current time
                time = Time.now
                
                # associates 
                items.each_with_index do |item, index|
                  actual_od = (dilution_factor.to_f * items_flattened[index]).round(3)
                  if item.get("optical_density").nil?
                    item.associate "optical_density", Hash.new
                  end
                  od_hash = item.get("optical_density")
                  # note "actual_od: #{actual_od}"
                  od_hash["#{time.strftime "%Y%m%d_%H_%M"}"] = actual_od
                  item.associate "optical_density", od_hash
                end
                
                if (input_object_type != '96 Well Flat Bottom (black)')
                  associate_PlateReader_measurements(upload, out_collection, method, dilution_factor)
                  out_collection.associate "was_recently_measured", true
                end
                
                # print out associations
                show do
                  op.input_array(INPUT).items.each do |item|
                    note "#{item.id}: #{item.get('optical_density')}"
                  end
                end
              end
             end    
          end
          
          if input_object_type != '96 Well Flat Bottom (black)'
            op_collection.mark_as_deleted
            op_collection.save
          end

        end
      end
      
      get_protocol_feedback()
      
      return {}
        
    end # Main
    
    # Tells the technician the overview of the protocol if they need to use the plate reader.
    def pr_intro
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
    
    # Tells the technician the overview of the protocol if they need to use the Seelig spectrophotometer
    def spec_intro
      show do
        title "Spectrophotometer Measurements"
        
        note "This protocol will instruct you on how to take measurements on the Seelig Lab Spectrophotometer."
        note "ODs are a quick and easy way to measure the growth rate of your culture."
        note "GFP measurements help researchers assess a response to a biological condition <i>in vivo</i>."
        note "<b>1.</b> Transfer cultures to cuvettes and make blank."
        note "<b>2.</b> Setup spectrophotometer workspace."
        note "<b>3.</b> Take and enter OD measurements."
      end
      
    end
    
    # Tells the technician to clean up.
    def cleaning_up item
      show do 
        title "Cleaning Up..."
        separator
        note "Before finishing up, rinse out plate <b>#{item}</b> with diluted bleach & H2O."
        note "Then rinse once more with EtOH"
      end
    end
    
    # Instructs the technician to transfer cultures to plate
    #
    # @param op [Operation] the operation that is currently being run
    # @param coordinate_matrix [2D-Array] a matrix representing the coordinates of the input plate to the operation
    # @param cult_vol [Integer] the volume of the culture to transfer
    # @param op_collection [Collection] the collection to transfer cultures into
    def transfer_culture op, coordinate_matrix, cult_vol, op_collection
      input_plate = "#{op.input(INPUT).item.object_type.name} #{op.input(INPUT).item.id}"
      output_plate = "#{op_collection} #{Item.find(op_collection.id).id}"
      show {
        title "Transfer Culture Aliquots to Plate for Reader" 
        check "If transferring from a plate, use a multi-channel pipettor to transfer <b>#{cult_vol}µl</b> from <b>#{input_plate}</b> to the <b>#{output_plate}</b>."
        check "Follow the below table:"
        #table coordinate_matrix
        table highlight_alpha_rc(op_collection, op_collection.get_non_empty){|r,c| coordinate_matrix[r][c]}
      }
    end
    
    # Instructs the technician to transfer media into plate
    #
    # @param op [Operation] the operation that is currently being run
    # @param coordinate_matrix [2D-Array] a matrix representing the coordinates of the input plate to the operation
    # @param media_vol [Integer] the volume of the media to transfer
    # @param op_collection [Collection] the collection to transfer cultures into
    def prefill_media op, coordinate_matrix, media_vol, op_collection
      op_collection_item = Item.find(op_collection.id)
      output_obj_type = op_collection_item.object_type.name
      type_of_media = op.input(MEDIA_TYPE).val
      in_collection = op.input_array(INPUT).first.collection
      
      log_info "final display matrix", coordinate_matrix
      
      # volume of media to grab.
      total_media_vol = (op_collection.get_non_empty.length * media_vol) + ((op_collection.get_non_empty.length * media_vol)* 0.1)
      
      show do
        title "Fill #{output_obj_type} with #{type_of_media} Media"
        
        check "Grab a clean <b>#{output_obj_type}</b>."
        check "Grab #{total_media_vol} uL of #{type_of_media}."
        check "Label the #{output_obj_type} => <b>#{op_collection_item.id}</b>."
        if media_vol != 0
          # note "Follow the table to transfer the samples from the input collection to the output collection."
          note "The coordinates in the following table are coordinates from the input collection"
          note "Fill each well with #{media_vol} uL of #{type_of_media}"
          #table highlight_matrix(coordinate_matrix)
          table highlight_alpha_rc(op_collection, op_collection.get_non_empty){|r,c| coordinate_matrix[r][c]}

        end
      end
    end
    
    # Makes a matrix that displays the coordinate
    #
    # @param collection1 [Collection] the collection whose coordinates we are making
    # @param collection2 [Collection] the collection whose dimensions we will use
    # @return matrix_for_display [2D-Array] the matrix that displays collection1's coordinates
    def make_coordinate_matrix collection1, collection2
      #in_collection = op.input(INPUT).collection
      if debug
        collection1 = Collection.find(394053)
      end
      #out_collection = op.output(OUTPUT).collection
      input_coordinate_matrix = []
      collection1_coordinate_matrix = []
      curr_char = 'A'
      curr_char_ascii = 0
      log_info "in_collection.matrix inside method", collection1.matrix
      collection1.matrix.each do |row|
        curr_row = []
        curr_num = 1
        row.each do |col|
          curr_coordinate = curr_char + (curr_num.to_s)
          if col != -1
            curr_row.push(curr_coordinate)
          end
          curr_num += 1
        end
        curr_char_ascii = curr_char.ord
        curr_char_ascii += 1
        curr_char = curr_char_ascii.chr
        curr_num = 0
        collection1_coordinate_matrix.push(curr_row)
      end
      log_info "coordinate matrix", collection1_coordinate_matrix
      collection1_matrix = collection1_coordinate_matrix.flatten
      matrix_for_display = []
      collection1_matrix.each_slice(collection2.dimensions[1]) do |slice|
        matrix_for_display.push(slice)
      end
      
      matrix_for_display # return
    end
    
    # Instructs the technician to transfer media from overnights into plate
    #
    # @param op [Operation] the operation that is currently being run
    # @param media_vol [Integer] the volume of the media to transfer
    # @param op_collection [Collection] the collection to transfer cultures into
    def prefill_media_cuvettes op, media_vol, op_collection
      op_collection_item = Item.find(op_collection.id)
      output_obj_type = op_collection_item.object_type.name
      type_of_media = op.input(MEDIA_TYPE).val
      display_matrix = []
      matrix = op_collection.matrix
      show do
        note "matrix: #{matrix}"
      end
      
      flattened_matrix = matrix.flatten
      flattened_matrix.each_slice(op_collection.dimensions[1]) do |slice|#matrix.each_slice(collection.dimensions[1]).map{|slice| Array.new(op_collection.dimensions[1]) { |i| media_vol}}.each do |slice| 
        display_matrix.push(slice)
      end
      
      op_collection.get_non_empty.each do |tuple|
        display_matrix[tuple[0]][tuple[1]] = media_vol
      end
      
      display_matrix.each do |row|
        row.reject! do |cell|
          cell == -1
        end
      end
      
      # Tells the technician to fill with media.
      show do
        title "Fill #{output_obj_type} with #{type_of_media} Media"
        
        check "Grab a clean <b>#{output_obj_type}</b>."
        check "Label the #{output_obj_type} => <b>#{op_collection_item.id}</b>."
        if media_vol != 0
          # note "Follow the table to transfer the samples from the input collection to the output collection."
          note "The coordinates in the following table are coordinates from the input collection"
          note "Fill each well with #{media_vol} uL of #{type_of_media}"
          table highlight_matrix display_matrix
        end
      end

    end
    
    # Instructs the technician to transfer culture from overnights into plate
    #
    # @param op [Operation] the operation that is currently being run
    # @param cult_vol [Integer] the volume of the culture to transfer
    # @param op_collection [Collection] the collection to transfer cultures into
    def transfer_culture_cuvettes op, hash, cult_vol, op_collection
      op_collection_item = Item.find(op_collection.id)
      display_matrix = []
      matrix = op_collection.matrix
      flattened_matrix = matrix.flatten
      flattened_matrix.each_slice(op_collection.dimensions[1]) do |slice|#matrix.each_slice(collection.dimensions[1]).map{|slice| Array.new(collection.dimensions[1]) { |i| media_vol}}.each do |slice| 
        display_matrix.push(slice)
      end
      
      hash.each do |key, value|
        display_matrix[value[0]][value[1]] = key
      end
      
      display_matrix.each do |row|
        row.reject! do |cell|
          cell == -1
        end
      end
      output_plate = "#{op_collection_item.object_type.name} #{op_collection_item.id}"
      
      show do
        title "Transfer Culture Aliquots to Plate for Reader" 
        check "Transfer <b>#{cult_vol}µl</b> from overnight tubes to the <b>#{output_plate}</b>."
        check "Follow the below table:"
        table highlight_matrix display_matrix
      end
    end
    
    # Tells the technician to gather cuvettes and container
    #
    # @param items [Array] list of input items
    def gather_cuvettes items  
      show do
        title "Gather Plastic Cuvettes"
        
        check "Go to the shelf under the plate reader."
        check "Gather #{items.length + 1} cuvettes."
        check  "Gather the following plastic cuvette container for easy containment."
        image CUVETTE1
      end
    end
    
    # Displays a media and culture volume table to the technician
    #
    # @param items [Array] list of overnight items
    # @param cult_vol [Integer] volume of culture to transfer
    # @param media_vol [Integer] volume of media to transfer
    def display_volume_table items, cult_vol, media_vol
      volume_table = [["Cuvette Number", "Item ID", "Culture Volume to add (uL)", "#{MEDIA_TYPE} Media Volume to add (uL)"]]
      
      first_row = ["0", "N/A", "0", "#{MAX_CUVETTE_VOLUME}"]
      volume_table.push(first_row)
      
      i = 1
      items.each do |item|
        curr_row = []
        curr_row.push(i.to_s)
        curr_row.push(item.id.to_s)
        curr_row.push(cult_vol)
        curr_row.push(media_vol)
        volume_table.push(curr_row)
        i += 1
      end
      
      # Displays volume table
      show do
        title "Fill Plastic Cuvettes"
        
        note "Follow the table below to label each cuvette a number for each item id."
        table volume_table
      end 
    
    end
    
    # Tells the technician to go to the Seelig lab
    def go_to_lab
      show do
        warning "Go to Seelig Lab in order to use the spectrophotometer."
        
      end
    end
    
    # Instructs the technician on how to use the spectrophotometer
    def use_spectrophotometer
      show do
        title "Prepare Spectrophotometer"
        
        note "On the Spectrophotometer laptop, if the program isn't open, click on nanodrop 2000."
        image NANODROP_2000
        note "Click on Cell Cultures."
        note "Click on 'no' when prompted to load last workbook and append new data to it."
        note "Click ok."
      end
    end
    
    # Gets the ODS entered by the technician for each overnight
    #
    # @param items [Array] list of overnights to be measured
    # @return data_od [Hash] hash of overnights => OD
    def get_measured_ods items
      i = 1
    #   get_measured_ods_table = Table.new()
    #   cuvette_numbers = []
    #   default_measured_ods = []
    #   items.each do |item|
    #     cuvette_numbers.push(i)
    #     default_measured_ods.push(0)
    #     i += 1
    #   end
    #   get_measured_ods_table.add_column("Cuvette Number", cuvette_numbers)
    #   get_measured_ods_table.add_response_column("Measured ODs", default_measured_ods)
    #   show do
    #     title "testing table"
    #     table get_measured_ods_table.all.render
    #   end
       data_od = show do
         title "Enter your measured ODS for each spectrophotometer"
        
         items.each do |item|
           get "number", var: "OD#{i}", label: "Enter the OD for plastic cuvette ##{i}", default: 0
           i += 1            
         end
       end
    end
    
    # Associates ODs to each overnight item
    #
    # @param items [Array] list of overnight items
    # @param dilution_factor [Integer] the dilution_factor that tells the ratio of media to culture
    # @data_od [Hash] hash that contains a mapping of overnights to ODs
    def associate_overnights items, dilution_factor, data_od
      final_table = [["Cuvette", "Item", "Association Key", "OD"]]
      time = Time.now
      items.each_with_index do |item, index|
        final_table_curr = []
        #note "#{index}"
        # note "#{data_od["OD#{index + 1}".to_sym]}"
        measured_od = data_od["OD#{index + 1}".to_sym].to_f
        # note "measured_od: #{measured_od}"
        # dilution_factor = (op.input(CULT_VOL).val.to_f) / (op.input(CULT_VOL).val.to_i + op.input(MEDIA_VOL).val.to_f)
        actual_od = (dilution_factor.to_f * measured_od).round(3)
        if item.get("optical_density").nil?
          item.associate "optical_density", Hash.new
        end
        od_hash = item.get("optical_density")
        # note "actual_od: #{actual_od}"
        od_hash["#{time.strftime "%Y%m%d_%H_%M"}"] = actual_od
        item.associate "optical_density", od_hash
        final_table_curr.push(index + 1)
        final_table_curr.push(item.id)
        final_table_curr.push("#{time.strftime "%Y%m%d_%H_%M"}")
        final_table_curr.push(actual_od)
        final_table.push(final_table_curr)
      end
      
      # Displays items and OD table
      show do
        title "Items and OD table"
        
        table final_table
      end
    end
    
    # Tells the technician to cleanup
    def cleanup
      show do
        title "Clean Up"
        
        note "Clean up whatever else you may have used."
      end
    end
    
end # Class