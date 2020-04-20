needs "Tissue Culture Libs/TissueCulture"
# TODO: Add specific media

class Protocol
    include TissueCulture
  
    INPUT = CELL_LINE
    OUTPUT = "Culture Plate"
    MEDIA = "Growth Media"
    RESUSPENSION_VOL = 10.0 # mL
    SPIN_SPEED = 200 # x g
    SPIN_TIME = 5 # min
    AUTO = "Automatically select output plate?"
    
    def output_associations ops
        ops.each do |op|
            out_plate = op.output(OUTPUT).item
            cryostock = op.input(INPUT).item
            passage = cryostock.passage || 1
            cell_num = cryostock.cell_number || 5e6
            conf = (cell_num / out_plate.max_cell_number * MAX_CONFLUENCY).round(0)
            if conf > 100.0
                op.associate :over_cell_density_warning, "The plate was plated at #{conf}% cell density. This may be fine if the cryostock viability is low."
                conf = 100.0
            end
            out_plate.update_seed conf, passage + 1
        end
    end
    
    def main

        operations.retrieve interactive: false
        
        operations.running.make
        
        if debug
            operations.running.each do |op|
                c = op.input(INPUT).item
                c.cell_density = rand(1e6..1e7) if c.cell_density.nil?
                c.volume = 1.0 if c.volume.nil?
            end
        end
        
        # Determine appropriate output plate only if plate request
        operations.running.each do |op|
            cryostock = op.input(INPUT).item
            op.temporary[:cell_num] = cryostock.cell_number
            default_cell_number = 5e6
            if cryostock.cell_number.nil?
                op.associate :cell_number_unknown, "The cell density of the cryostock is unknown. Assuming #{to_scinote(default_cell_number)}/mL."
            end
        end
        
        # Create labels
        operations.running.zip(('A'..'Z')).each { |op, l| op.temporary[:temp_label] = l }
        
        # Required materials
        group_by_ot = operations.running.group_by { |op| op.output(OUTPUT).object_type }
        group_by_media = operations.running.group_by { |op| op.input(MEDIA).item }
        
        show do
            title "Begin warming media and water bath"
            
            check "Prepare a 37C water bath"
            separator
            note "Warm the following media bottles"
            operations.running.each do |op|
                media = op.input(MEDIA).item
                media_name = "#{media.id} #{media.sample.name}"
                check "#{media_name}"
            end
        end
        
        show do
            title "Wait for media and water bath to reach 37C"
            
            note "A make shift water bath can be created using the sink faucet and a medium sized beaker. An infrared thermometer \
            can be used to measure the temperature of the water bath."
        end
        
        required_ppe STANDARD_PPE
        
        show do
            title "Gather plates"
            
            containers = group_by_ot.keys
            quantity = group_by_ot.map { |c, ops| ops.size }
            
            t = Table.new
            t.add_column( "Container", containers.map { |c| c.name } )
            t.add_column( "Quantity", quantity )
            table t
        end
        
        output_associations operations.running
        
        def create_plate_label plate, temp_label
            "<table style=\"width:100%\">
                    <tr><td>#{temp_label} #{plate.id}</td></tr>
                    <tr><td>#{plate.sample.name}</td></tr>
                    <tr><td>#{today_string}</td></tr>
                    <tr><td>P: #{ plate.passage }</td></tr>
                    <tr><td>Seed: #{ plate.seed }%</td></tr>
            </table>"
        end
        
        operations.running.each do |op|
            label = create_plate_label op.output(OUTPUT).item, op.temporary[:temp_label]
            container = op.output(OUTPUT).item.object_type.name
            show do
                title "Label #{container} as #{op.output(OUTPUT).item}"
                
                check "Label the top of the plate as indicated by the table."
               
                t = Table.new
                t.add_column("Container", [container])
                t.add_column("Label", [label])
                table t
            end
        end
        
        show do
            title "Label 15mL conical tubes"
            
            labels = operations.running.map { |op| op.temporary[:temp_label] }.join(', ')
            check "Label the #{operations.running.size} conical tubes with the labels #{labels}."
        end
        
        show do
            title "Gather materials"
        
            note "Sterilize and move the following into the #{HOOD}"
            check "Eppie tube rack"
            check "2 X centrifuge buckets (located in main lab)"
            check "2 X brown 15mL conical tube adapters for centrifuge buckets"
            check "2 X biosafety seals for centrifuge buckets"
            check "#{operations.running.size} labeled conical tubes."
        end
        
        show do
            title "Prepare to retrieve samples from the cryogenic freezer"
            
            warning "Ensure you are properly trained."
            warning "Always wear a face shield. Samples can undergo rapid decompression."
            warning "Liquid Nitrogen can cause severe freezer burn. Always wear skin protection."
        end
        
        required_ppe CRYOSTOCK_PPE
        
        show do
            title "Quickly retrieve the following items and place in styrofoam rack."
            
            check "After retrieval, immediately thaw them in 37C water bath until just a little ice remains."
            check "Spray down sample with #{ETOH} and move into hood."
            check "Remove face shield"
            check "Arrange tubes in eppie tube rack, pressing firmly into the rack."
            
            table operations.running.start_table
                .input_item(INPUT)
                .custom_column(heading: "Location") { |op| op.input(INPUT).item.location }
                .end_table
        end
        
        operations.running.each do |op|
            op.input(INPUT).item.mark_as_deleted
        end
        
        show do
            title "Resuspend"
            
            check "Using a 1mL serological pipette transfer cells into appropriate conical tubes."
            check "Slowly add #{RESUSPENSION_VOL} mL of media to cells drop-by-drop"
            check "Place tubes into centrifuge buckets for centrifugation"
            
            table operations.running.start_table
                .input_item(INPUT)
                .custom_column(heading: "Conical tube") { |op| op.temporary[:temp_label] }
                .custom_column(heading: "Media") { |op| "#{op.input(MEDIA).item.id} #{op.input(MEDIA).sample.name}" }
                .end_table
        end
        
        show do
            title "Assemble centrifuge buckets"
            
            check "Add adapter to bucket"
            check "Ensure tubes are balanced (use water tube if needed)"
            warning "Attach biosafety lid and be sure it is sealed! If not, you'll risk the safety of others!"
        end
        
        show do
            title "Centrifuge cells at #{SPIN_SPEED} for #{SPIN_TIME} min"
            
            check "Remove <b>ALL</b> PPE before leaving room."
            check "Take centrifuge buckets + cells to the main lab"
            check "Centrifuge cells at #{SPIN_SPEED} for #{SPIN_TIME} min"
            check "Return the centrifuge bucket + cells to the BSL2 room."
            warning "NEVER open buckets + cells outside of the #{HOOD}. You can release dangerous aerosols."
        end
        
        required_ppe STANDARD_PPE
        
        show do
            title "Return to BSL2"
            
            check "Sterilize the outside of the buckets with #{ETOH}"
            check "Place buckets in #{HOOD}"
            check "Open buckets and place tubes in a rack."
            check "Place buckets off to the side."
        end
        
        show do
            title "Aspirate media"
            
            check "For each tube, carefully aspirate off the media without disturbing the cell pellet."
        end
        
        operations.each do |op|
            v = op.output(OUTPUT).item.working_volume
            op.temporary[:resuspend_vol] = [v, RESUSPENSION_VOL].min
            op.temporary[:media_vol] = v  - op.temporary[:resuspend_vol]
        end
        
        show do
            title "Resuspend cells"
            
            note "For each tube, resuspend cells with media and plate entire volume of cells onto designated plate"
            table operations.running.start_table
                .output_item(OUTPUT, heading: "Plate id")
                .custom_column(heading: "Media") { |op| "#{op.input(MEDIA).item.id} #{op.input(MEDIA).sample.name}" }
                .custom_column(heading: "Vol (mL)") { |op| op.temporary[:resuspend_vol] }
                .end_table
        end
            
        show do
            title "Plate cells"
                
            check "Pipette all of the cells into the plate."
                
            table operations.running.start_table
                    .custom_column(heading: "Conical Tube") { |op| op.temporary[:temp_label] }
                    .custom_column(heading: "Plate Label") { |op| op.temporary[:temp_label] }
                    .output_item(OUTPUT, heading: "Plate id")
                    .custom_column(heading: "Plate Type") { |op| op.output(OUTPUT).item.object_type.name }
                    .end_table
        end
        
        needs_more_media = operations.running.select { |op| op.temporary[:media_vol] > 0 }
        if needs_more_media.any?
            show do
                title "Add media to plates"
                
                table needs_more_media.start_table
                    .output_item(OUTPUT, heading: "Plate id")
                    .custom_column(heading: "Vol (mL)") { |op| op.temporary[:media_vol] }
                    .end_table
            end
        end
        
        operations.store
        return {}
    end
end
