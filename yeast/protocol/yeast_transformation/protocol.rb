needs "Cloning Libs/Cloning"
needs "Standard Libs/Feedback"
class Protocol
    include Cloning
    include Feedback
    def main

      prevent_comp_cell_duplicates
      
      operations.select! { |op| op.status != "error" }
      
      operations.make only: ["Transformation"]
    # operations.retrieve
    # replaces operations.retrieve with grouped inputs for clarity
      comp_retrieve = {}
      plasmid_retrieve = {}
      operations.each do |op|
          comp_retrieve["Item #{op.input("Parent").item} (#{op.input("Parent").item.object_type.name})"] = "#{op.input("Parent").item.location}"
          plasmid_retrieve["Item #{op.input("Genetic Material").item} (#{op.input("Genetic Material").item.object_type.name})"] = "#{op.input("Genetic Material").item.location}"
      end
      
      show do
          title "Gather the Following Item(s)"
          plasmid_retrieve.each do |k,v|
              check "#{k} at #{v}"
          end
          separator
          comp_retrieve.each do |k,v|
              check "#{k} at #{v}"
          end
      end
      
      operations.each do |op|
        plate = op.output("Transformation").item
        if plate.object_type.name == "Yeast Plate"
          op.plan.associate "yeast_plate_#{plate.sample.id}", plate.id
        else
          start_make_antibiotic_plate op
        end
      end

      peg = find(:item, object_type: { name: "50 percent PEG 3350" })[-1]
      lioac = find(:item, object_type: { name: "1.0 M LiOAc" })[-1]
      ssDNA = find(:item, object_type: { name: "Salmon Sperm DNA (boiled)" })[-1]
      reagents = [peg] + [lioac] + [ssDNA]
      take reagents, interactive: true
      
      # process by marker
      # pass the plasmid marker to the sample properties of the yeast sample
      # set the genetic material input as the integrant for the yeast sample.
      ops_to_plate = operations.select { |op| op.output("Transformation").item.object_type == ObjectType.find_by_name("Yeast Plate") }
      ops_to_plate.each do |op| 
        marker = op.input("Genetic Material").sample.properties["Yeast Marker"].downcase[0,3]
        yeast_marker_fv = FieldValue.where(parent_id: op.output("Transformation").sample.id, parent_class: "Sample", name: "Integrated Marker(s)").first
        yeast_marker_fv.value = marker
        yeast_marker_fv.save
        op.temporary[:marker] = marker
        
        yeast_integrant_fv = FieldValue.where(parent_id: op.output("Transformation").sample.id, parent_class: "Sample", name: "Integrant").first
        yeast_integrant_fv.value = op.input("Genetic Material").sample
        yeast_integrant_fv.save
          
      end
      
      ops_by_marker = Hash.new { |h, k| h[k] = [] }
      ops_to_plate.each do |op|
        ops_by_marker[op.temporary[:marker]].push op
      end

      grab_plate_tab = [["Plate type","Quantity","Id to label"]]
      plating_info_tab = [["1.5 mL tube id","Plate id"]]
      overall_batches = find(:item, object_type: { name: "Agar Plate Batch" }).map{|b| collection_from b}
        
      plate_batch_ids = Array.new
  
      ops_by_marker.each do |marker, ops|
        if  !(["nat","kan","hyg","ble"].include? marker)
          if marker == "foa"
            grab_plate_tab.push(["5-#{marker.upcase}", ops.length, ops.collect { |op| op.output("Transformation").item.id }.join(", ")])
          else
            grab_plate_tab.push(["-#{marker.upcase}", ops.length, ops.collect { |op| op.output("Transformation").item.id }.join(", ")])
            
            plate_batch = overall_batches.find{ |b| !b.num_samples.zero? && find(:sample, id: b.matrix[0][0])[0].name == "SDO -#{marker.capitalize}" }
            plate_batch_id = "none" 
            num = ops.length
            if plate_batch.present?
              plate_batch_id = "#{plate_batch.id}"
              num_plates = plate_batch.num_samples
              update_batch_matrix plate_batch, num_plates - num, "SDO -#{marker.capitalize}"
              if num_plates == num
                plate_batch.mark_as_deleted
              end
              if num_plates < num 
                num_left = num - num_plates
                plate_batch_two = overall_batches.find{ |b| !b.num_samples.zero? && find(:sample, id: b.matrix[0][0])[0].name == "SDO -#{marker.capitalize}" }
                update_batch_matrix plate_batch_two, plate_batch_two.num_samples - num_left, "SDO -#{marker.capitalize}" if plate_batch_two.present?
                plate_batch_id = plate_batch_id + ", #{plate_batch_two.id}" if plate_batch_two.present?
              end
            end
            plate_batch_ids.push(plate_batch_id)
          end
        end
      end

      # Yeast transformation preparation
      yeast_transformation

      # Load comp cell aliquots with plasmid, full plamid, or fragment
      load_comp_cell_aliquots
    
      # Re-label all comp cell tubes
      relabel_comp_cell_tubes

      # Vortex strongly and heat shock
      vortex_and_heat
      
      # Grab plate
      grab_plate plate_batch_ids, grab_plate_tab if ops_to_plate.length > 0

      # Retrive tubes and spin down
      retrieve_tubes

      ops_to_incubate = operations.select { |op| op.output("Transformation").item.object_type == ObjectType.find_by_name("Yeast Overnight for Antibiotic Plate") }
      if ops_to_incubate.any?
        # Resuspend in YPAD and incubate
        resuspend_in_YPAD ops_to_incubate

        ops_to_incubate.each do |op|
          op.output("Transformation").item.move "30 C shaker incubator"
        end
          
      end
      
      if ops_to_plate.length > 0
          
        # Resuspend in water and plate
        resuspend ops_to_plate
        
        # Shake and incubate
        shake_and_incubate ops_to_plate

        ops_to_plate.each do |op|
          op.output("Transformation").item.move "30 C incubator"
        end
      end
      

      operations.each do |op|
        # NOT WORKING

        op.input("Parent").item.mark_as_deleted
        if op.input("Genetic Material").object_type.name == "0.6mL tube of Digested Plasmid"
          op.input("Genetic Material").item.mark_as_deleted
       end
      end
      operations.store

    
      release reagents, interactive: true
      get_protocol_feedback
      return {}
    end
    
    #Requires: op.output("Transformation").object_type.name == "Yeast Overnight for Antibiotic Plate"
    #spins out an operation to make an antibiotic plate that will be used for plating this op's strain
    #associates the operation id of the new operation to the Antibiotic plating operation that comes after this one
    def start_make_antibiotic_plate op
      #getting the media sample required to plate this yeast strain
      antibiotic_hash = { "nat" => "clonNAT", "kan" => "G418", "hyg" => "Hygro", "ble" => "Bleo", "5fo" => "5-FOA" }
      full_marker = op.input("Genetic Material").sample.properties["Yeast Marker"]
      marker = full_marker.downcase[0,3]
      marker = "kan" if marker == "g41"
      media = Sample.find_by_name("YPAD + #{antibiotic_hash[marker]}") 
      
      #create new operation and set to pending
      ot = OperationType.find_by_name("Make Antibiotic Plate")
      new_op = ot.operations.create(
        status: "pending",
        user_id: op.user_id
      )
      op.plan.plan_associations.create operation_id: new_op.id
      
      #add correct media sample as the output of the new op
      aft = ot.field_types.find { |ft| ft.name == "Plate" }.allowable_field_types[0]
      new_op.set_property "Plate", media, "output", false, aft
      
      #associate the new op with the item that will be the input of Yeast antibiotic plating
      #This way Antibiotic Plating can retrieve the correct plate for the yeast strain
      op.output("Transformation").item.associate :spin_off, new_op.id

      op.plan.reload
      new_op.reload
    end

    # This method helps prevent comp cell duplicates. It will automatically distribute all inputs of operations to availabe comp cells within a sample
    def prevent_comp_cell_duplicates
        
        operations.each do |op| 
            op.associate :original_item_number, "The item number that was assigned in designer before the redistribution is #{op.input("Parent").item.id}"
        end
    
        # arr that stores operations that take an unavailable comp cell
        errored_op_arr = []
    
        # group all operations by item  
        item_group = operations.group_by{ |op| op.input("Parent").sample }
        
        # go through each operation and change it to an item within that sample
        item_group.each do |sample, op_arr|
            # find items where the sample is the same and container is a comp cell
            sample_list = Item.where(sample_id: Sample.find_by(name: sample.name)).where(object_type_id: ObjectType.find_by(name: 'Yeast Competent Cell')).where.not(location: 'deleted').to_a
            # get the available comp cells and replace them in the operatoin
            first_in_sample_list = sample_list.first
            op_arr.each do |op|
                if op.input("Parent").item != first_in_sample_list
                    sample_list.delete(op.input("Parent").item)
                    
                end
            end
            op_arr.each do |op|
                if (op.input("Parent").item == first_in_sample_list)
                    # get comp cells starting from oldest to newest
                    next_item = sample_list.shift()
                    # if there are more operations using a sample than there are items using a sample
                    if next_item.nil?
                        op.error :not_enough_items, "There are not enough items with this sample to evenly distribute between all operations"
                        errored_op_arr.push(op)
                    end
                    op.input("Parent").set item: next_item
                end
            end
        end
        
        # if there are errored ops, tell technician about em
        if errored_op_arr.length > 0 
            show do
                title "Errored operations due to not enough items to distribute"
                warning "These operations were errored out because there were not enough items with this sample to evenly distribute"
                warning "Notify a lab manager about this situation"
                errored_op_arr.each do |op|
                    note "Operation id: #{op.id}"
                end
            end
        end
    end
    
    # This method returns an array filled with a value
    def fill_array rows, cols, num, val
      num = 0 if num < 0
      array = Array.new(rows) { Array.new(cols) { -1 } }
      (0...num).each { |i|
        row = (i / cols).floor
        col = i % cols
        array[row][col] = val
      }
      array
    end # fill_array
    
    # This method updates the batch matrix.
    def update_batch_matrix batch, num_samples, plate_type
      rows = batch.matrix.length
      columns = batch.matrix[0].length
      batch.matrix = fill_array rows, columns, num_samples, find(:sample, name: "#{plate_type}")[0].id
      batch.save
    end
    
    # This method instructs the technician to perform a yeast transformation.
    def yeast_transformation
      show do
        title "Yeast transformation preparation"
        
        check "Spin down all the Yeast Competent Aliquots on table top centrifuge for 20 seconds"
        check "Add 240 µl of 50 percent PEG 3350 into each competent aliquot tube."
        warning "Be careful when pipetting PEG as it is very viscous. Pipette slowly"
        
        check "Add 36 µl of 1M LiOAc to each tube"
        check "Add 25 µl of Salmon Sperm DNA (boiled) to each tube"
        warning "The order of reagents added is crucial for suceess of transformation."
        end
    end
    
    # This method tells the technician to load comp cell aliquots with plasmid or fragment.
    def load_comp_cell_aliquots
      show do
        title "Load competent cell aliquots with 50µl Digested Plasmid, Full Plasmid, or Fragment"
        
        operations.each do |op|
            if op.input("Genetic Material").object_type.name == "Plasmid Stock"
                check "Make a dilution of 1 µl stock and 49 µl water for aliquot #{op.input("Parent").item.id}"
            end
        end
            
        table operations.start_table
          .input_item("Genetic Material", heading: "Plasmid/Fragment ID")
          .input_item("Parent", heading: "Yeast Competent Aliquot", checkable: true)
          .custom_column(heading: "Dilution") { |op| op.input("Genetic Material").object_type.name == "Plasmid Stock" ? "Y" : "N"}
        .end_table
      end
    end
    
    # This method tells the technician to re-label all comp cell tubes.
    def relabel_comp_cell_tubes
      show do
        title "Re-label all the competent cell tubes"
       
        table operations.start_table
          .input_item("Parent", heading: "Old ID")
          .output_item("Transformation", heading: "New ID", checkable: true)
        .end_table
      end
    end
    
    # This method tells the technician to vortex and heat.
    def vortex_and_heat
      show do
        title "Vortex strongly and heat shock"
        
        check "Vortex each tube on highest settings until the cells are resuspended."
        check "Place all aliquots on 42 C heat block for 15 minutes (Timer starts on next slide)."
      end
    end
    
    # This method tells the technician to retrieve tubes.
    def retrieve_tubes
      show do
        title "Retrieve tubes and spin down"
        
        timer initial: { hours: 0, minutes: 15, seconds: 0}
        
        check "After timer finishes, retrieve all #{operations.length} tubes from 42 C heat block."
        check "Spin the tube down for 20 seconds on a small tabletop centrifuge."
        check "Remove all the supernatant carefully with a 1000 µl pipettor (~400 L total)"
      end
    end
    
    # This method tells the technician to resuspend in YPAD and incubate.
    def resuspend_in_YPAD ops_to_incubate
      show do
        title "Resuspend in YPAD and incubate"
        
        check "Grab #{"tube".pluralize(ops_to_incubate.length)} with id #{(ops_to_incubate.collect { |op| op.output("Transformation").item.id }).join(", ")}"
        check "Add 1 mL of YPAD to the each tube and vortex for 20 seconds"
        check "Grab #{ops_to_incubate.length} 14 mL #{"tube".pluralize(ops_to_incubate.length)}, label with #{(ops_to_incubate.collect { |op| op.output("Transformation").item.id }).join(", ")}"
        check "Transfer all contents from each 1.5 mL tube to corresponding 14 mL tube that has the same label number"
        check "Place all #{ops_to_incubate.length} 14 mL #{"tube".pluralize(ops_to_incubate.length)} into 30 C shaker incubator"
        check "Discard all #{ops_to_incubate.length} empty 1.5 mL #{"tube".pluralize(ops_to_incubate.length)} "
      end
    end
    
    # This method tells the technician to grab plates.
    def grab_plate plate_batch_ids, grab_plate_tab
      show do
        title "Grab plate"
        
        note "Grab the following plates from batches #{plate_batch_ids.join(", ")} and label with your initials, the date, and the following ids on the top and side of each plate."
        table grab_plate_tab
      end
    end
    
    # This method tells the technician to resuspend in water and plate.
    def resuspend ops_to_plate
      show do
        title "Resuspend in water and plate"
        
        check "Add 200 µl of MG water to the following mixtures: #{ops_to_plate.map { |op| op.output("Transformation").item.id}.to_sentence}."
        check "Vortex each tube to fully resuspend cells."
        check "Flip the plates and add 4-5 glass beads to it, add 200 µl of mixtures on each plate."
        warning "Add each volume of mixture to the plate with the matching ID."
      end
    end
    
    # This method tells the technician to shake and incubate.
    def shake_and_incubate ops_to_plate
      show do
        title "Shake and incubate"
        
        check "Shake the plates in all directions to evenly spread the culture over its surface till dry."
        check "Discard the beads in a used beads container."
        check "Throw away the following 1.5 mL tubes."
        note ops_to_plate.collect { |op| op.output("Transformation").item.id }
        check "Incubate all the plates with agar side up shown in the next page."
      end
    end
end