needs "Cloning Libs/Cloning"

class Protocol

    include Cloning

    def prevent_comp_cell_duplicates
        used_aliquots = []
        operations.each do |op|
            aliquot = op.input("Parent").item
            
            if used_aliquots.include? aliquot
                op.error :aliquot_spoken_for, "Your comp cell aliquot #{aliquot.id} is being used for another transformation. Please replan using a different aliquot."
            else
                used_aliquots.push aliquot
            end
        end
    end

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

    def update_batch_matrix batch, num_samples, plate_type
        rows = batch.matrix.length
        columns = batch.matrix[0].length
        batch.matrix = fill_array rows, columns, num_samples, find(:sample, name: "#{plate_type}")[0].id
        batch.save
    end

    def plasmid_digest_steps ops
        # ensure_stock_concentration sample_stocks
    
        # Take Cut Smart and PmeI
        cut_smart = Sample.find_by_name("Cut Smart").in("Enzyme Buffer Stock")[0]
        pmeI = Sample.find_by_name("PmeI").in("Enzyme Stock")[0]
        
        take [cut_smart], interactive: true
    
        show do
          title "Grab an ice block"
          
          warning "In the following step you will take PmeI enzyme out of the freezer. Make sure the enzyme is kept on ice for the duration of the protocol."
        end
        
        take [pmeI], interactive: true
    
        # Master Mix
        make_master_mix = ops.length > 1
    
        water_volume = 42
        buffer_volume = 5
        enzyme_volume = 1
        if make_master_mix
          if ops.length < 5
            water_volume = water_volume * ops.length + 21
            buffer_volume = buffer_volume * ops.length + 2.5
            enzyme_volume = enzyme_volume * ops.length + 0.5
          elsif ops.length < 8
            water_volume = water_volume * ops.length + 42
            buffer_volume = buffer_volume * ops.length + 5
            enzyme_volume = enzyme_volume * ops.length + 1
          else
            water_volume = water_volume * ops.length + 63
            buffer_volume = buffer_volume * ops.length + 7.5
            enzyme_volume = enzyme_volume * ops.length + 1.5
          end
    
          show do
            title "Make Master Mix"
            
            check "Label a new eppendorf tube MM."
            check "Add #{water_volume.round(1)} uL of water to the tube."
            check "Add #{buffer_volume.round(1)} uL of the cutsmart buffer to the tube."
            check "Add #{enzyme_volume.round(1)} uL of the PmeI to the tube."
            check "Vortex for 5-10 seconds."
            warning "Keep the master mix in an ice block while doing the next steps".upcase
          end
          
          release [pmeI, cut_smart], interactive: true
        end
    
        # make stripwells
        ops.make only: ["Digested Plasmid"]

        show do
          title "Prepare Stripwell Tubes"
          
          ops.output_collections["Digested Plasmid"].each_with_index do |sw, idx|
            check "Label a new stripwell with the id #{sw.id}. Write on enough wells to transcribe the full id number."
            
            # Make well index arrays for water (fragments) and MM (plasmids)
            water_wells = sw.matrix[0].reject { |sid| sid == -1 }.map.with_index { |sid, idx| (find(:sample, id: sid)[0].sample_type.name == "Fragment") ? idx + 1 : nil }.compact
            mm_wells = sw.matrix[0].reject { |sid| sid == -1 }.map.with_index { |sid, idx| (find(:sample, id: sid)[0].sample_type.name == "Plasmid") ? idx + 1 : nil }.compact
            
            # Water for fragments
            check "Pipette 48 uL of water into wells " + water_wells.join(", ") if water_wells.any?
            
            if make_master_mix
              check "Pipette 48 uL from tube MM into wells " + mm_wells.join(", ") if mm_wells.any?
            else
              check "Pipette #{water_volume.round(1)} uL of water, #{buffer_volume.round(1)} uL of the cutsmart buffer, and #{enzyme_volume.round(1)} uL of the PmeI into the well." if mm_wells
              check "Carefully flick the well a couple of times to ensure thorough mixing."
            end
          end
        end
        
        release [pmeI] + [cut_smart], interactive: true if !make_master_mix
    
        # Calculate plasmid volumes
        check_concentration ops, "DNA Integrant"
        ops.each do |op|
          conc = op.input("DNA Integrant").item.get(:concentration).to_i
          conc = rand(100..1000) if debug
          
          vol = 0
          if conc > 300 && conc < 500
            vol = 2
          else
            vol = (1000.0 / conc).round(1)
            if vol < 0.5
              vol = 0.5
            elsif vol > 15
              vol = 15
            end
          end
          
          op.temporary[:vol] = vol
        end
        
        # Pipette plasmids into stripwells
        show do
          title "Load stripwells"
          
          note "Add volume of each sample stock into the stripwell indicated."
          warning "Use a fresh pipette tip for each transfer."
          
          table ops.start_table
            .input_item("DNA Integrant")
            .output_collection("Digested Plasmid")
            .custom_column(heading: "Well") { |op| op.output("Digested Plasmid").column + 1 }
            .custom_column(heading: "Volume (uL)", checkable: true) { |op| op.temporary[:vol] }
            .end_table
        end
    
        # Move stripwells to 37 C incubator
        show do
          title "Incubate"
          
          check "Put the cap on each stripwell. Press each one very hard to make sure it is sealed."
          check "Place the stripwells into a small green tube holder and then place in 37 C incubator."
          image "put_green_tube_holder_to_incubator"
        end
    
        ops.output_collections["Digested Plasmid"].each do |sw|
          sw.move "37 C incubator"
        end
        
        show do
          title "Start 1-hour timer"
          
          timer_link = 'https://www.google.com/search?q=timer+for+1+hour&oq=timer+for+1+hour&aqs=chrome..69i57j0l5.2200j0j7&sourceid=chrome&ie=UTF-8'
          note "Start a <a href=#{timer_link} target='_blank'>one-hour timer on Google</a>, and sit tight."
        end
        
        show do
          title "Retrieve stripwells for Yeast Transformation"
          
          note "Retrieve stripwell(s) #{ops.output_collections["Digested Plasmid"].map { |sw| sw.id }} from the 37 C incubator"
        end
    end

    def main

        # TODO: Properly address aquarium-bugs issue #76
        operations.retrieve interactive: false
        prevent_comp_cell_duplicates
        operations.retrieve only: ["DNA Integrant"]

        operations.select! { |op| op.status != "error" }
        
        #####          ----- PLASMID DIGEST -----          #####
    
        # determine plasmids to digest (non-integrant & not fragments)
        operations.each do |op|
            op.temporary[:digest] = (op.input("DNA Integrant").sample.sample_type.name != "Fragment" &&
                                     op.output("Transformation").sample.properties["Plasmid"] != op.input("DNA Integrant").sample)
        end
        ops_to_digest = operations.select { |op| op.temporary[:digest] }
        
        plasmid_digest_steps ops_to_digest
        
        #####          ----- YEAST TRANSFORMATION -----          #####
        
        operations.make only: ["Transformation"]
        operations.retrieve only: ["Parent"]
        operations.each do |op|
            plate = op.output("Transformation").item
            if plate.object_type.name == "Yeast Plate"
                op.plan.associate "yeast_plate_#{plate.sample.id}", plate.id
            end
        end
        # operations.store
    
        peg = find(:item, object_type: { name: "50 percent PEG 3350" })[-1]
        lioac = find(:item, object_type: { name: "1.0 M LiOAc" })[-1]
        ssDNA = find(:item, object_type: { name: "Salmon Sperm DNA (boiled)" })[-1]
        reagents = [peg] + [lioac] + [ssDNA]
        take reagents, interactive: true
    
        show do
            title "Yeast transformation preparation"
            
            check "Spin down all the Yeast Competent Aliquots on table top centrifuge for 20 seconds"
            check "Add 240 uL of 50 percent PEG 3350 into each competent aliquot tube."
            warning "Be careful when pipetting PEG as it is very viscous. Pipette slowly"
            
            check "Add 36 uL of 1M LiOAc to each tube"
            check "Add 25 uL of Salmon Sperm DNA (boiled) to each tube"
            warning "The order of reagents added is super important for suceess of transformation."
        end
    
        ops_to_digest.output_collections["Digested Plasmid"].each do |sw|
            ops_in_sw = ops_to_digest.select { |op| op.output("Digested Plasmid").collection == sw }
            tab = [["Location", "Yeast Competent Aliquot"]].concat(
                ops_in_sw.map { |op| op.output("Digested Plasmid").column + 1 }.zip(
                    ops_in_sw.map { |op| { content: op.input("Parent").item.id, check: true} }
                    )
                )
            
            show do
                title "Load competent cell aliquots from Stripwell #{sw.id}"
                        
                table tab
                
                note "Pipette 50 uL from each well into corresponding yeast aliquot"
                note "Discard the stripwell into waste bin."
            end
            
            sw.mark_as_deleted
            sw.save
        end
        
        ops_not_digested = (operations - ops_to_digest).extend(OperationList)
        show do
            title "Load competent cell aliquots from stocks"
            
            table ops_not_digested.start_table
                .input_item("DNA Integrant", heading: "Plasmid/Fragment Stock ID")
                .input_item("Parent", heading: "Yeast Competent Aliquot", checkable: true)
            .end_table
        end if ops_not_digested.any?
    
        show do
            title "Re-label all the competent cell tubes"
           
            table operations.start_table
                .input_item("Parent", heading: "Old ID")
                .output_item("Transformation", heading: "New ID", checkable: true)
            .end_table
        end
    
        show do
            title "Vortex strongly and heat shock"
            
            check "Vortex each tube on highest settings until the cells are resuspended."
            check "Place all aliquots on 42 C heat block for 15 minutes."
        end

        show do
            title "Retrieve tubes and spin down"
            
            timer initial: { hours: 0, minutes: 15, seconds: 0}
            
            check "Retrieve all #{operations.length} tubes from 42 C heat block."
            check "Spin the tube down for 20 seconds on a small tabletop centrifuge."
            check "Remove all the supernatant carefully with a 1000 uL pipettor (~400 uL total)"
        end

        # process by marker
        ops_to_plate = operations.select { |op| op.output("Transformation").item.object_type == ObjectType.find_by_name("Yeast Plate") }
        ops_to_plate.each do |op| 
            marker = op.input("DNA Integrant").sample.properties["Yeast Marker"].downcase[0,3]
            op.temporary[:marker] = marker
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

        ops_to_incubate = operations.select { |op| op.output("Transformation").item.object_type == ObjectType.find_by_name("Yeast Overnight for Antibiotic Plate") }
        if ops_to_incubate.any?
            show do
                title "Resuspend in YPAD and incubate"
                
                check "Grab #{"tube".pluralize(ops_to_incubate.length)} with id #{(ops_to_incubate.collect { |op| op.output("Transformation").item.id }).join(", ")}"
                check "Add 1 mL of YPAD to the each tube and vortex for 20 seconds"
                check "Grab #{ops_to_incubate.length} 14 mL #{"tube".pluralize(ops_to_incubate.length)}, label with #{(ops_to_incubate.collect { |op| op.output("Transformation").item.id }).join(", ")}"
                check "Transfer all contents from each 1.5 mL tube to corresponding 14 mL tube that has the same label number"
                check "Place all #{ops_to_incubate.length} 14 mL #{"tube".pluralize(ops_to_incubate.length)} into 30 C shaker incubator"
                check "Discard all #{ops_to_incubate.length} empty 1.5 mL #{"tube".pluralize(ops_to_incubate.length)} "
            end
            
            ops_to_incubate.each do |op|
                op.output("Transformation").item.move "30 C shaker incubator"
            end
            
            ops_to_incubate.store interactive: true
        end

        if ops_to_plate.length > 0
            show do
                title "Grab plate"
                
                note "Grab the following plates from batches #{plate_batch_ids.join(", ")} and label with your initials, the date, and the following ids on the top and side of each plate."
                table grab_plate_tab
            end
            
            show do
                title "Resuspend in water and plate"
                
                check "Add 200 uL of MG water to the following mixtures shown in the table and resuspend."
                check "Flip the plate and add 4-5 glass beads to it, add 200 uL of mixtures on each plate."
                warning "Add each volume of mixture to the plate with the matching ID."
            end
        
            show do
                title "Shake and incubate"
                
                check "Shake the plates in all directions to evenly spread the culture over its surface till dry."
                check "Discard the beads in a used beads container."
                check "Throw away the following 1.5 mL tubes."
                note ops_to_plate.collect { |op| op.output("Transformation").item.id }
                check "Incubate all the plates with agar side up shown in the next page."
            end
            
            show do
                title "Move antibiotic plates to the media fridge (if applicable)"
                
                warning "If any antibiotic plates were made, label the foil TOXIC with red sharpie, and move them to the side of the door in the media fridge."
            end
        
            ops_to_plate.each do |op|
                op.output("Transformation").item.move "30 C incubator"
            end
            ops_to_plate.store interactive: true
        end

        operations.each do |op|
            op.input("Parent").item.mark_as_deleted
            op.input("Parent").item.save
        end
      
        release reagents, interactive: true
        
        return {}
    end
end