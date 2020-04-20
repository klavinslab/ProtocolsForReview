needs "Tissue Culture Libs/TissueCulture"

# TODO: Add specific media
# TODO: Add requestor code to Freeze Cell Line
class Protocol
    include TissueCulture
    
    INPUT = "Cell Suspension"
    OUTPUT = "Temp Cryostock"
    MIN_CELL_DENSITY = 1E6 # cells/mL
    MAX_CELL_DENSITY = 1E7
    CRYOSTOCK_VOL = 1.0 # mL
    
    def output_associations ops
        ops.each do |op|
            i = op.output(OUTPUT).item
            i.passage = op.temporary[:passage]
            i.volume = CRYOSTOCK_VOL
            i.cell_density = op.temporary[:cell_density]
            i.from = op.input(INPUT).item
        end
    end
    
    def volume_calculations ops
        # TODO: Error out if cell line doesn't match active cell line
        # TODO: Save :from
        # TODO: If they're the same active cell line, pool together
        
        ops.each do |op|
            suspension = op.input(INPUT).item
            max_cell_vol = plate.cell_number/MIN_CELL_DENSITY
            min_cell_vol = plate.cell_number/MAX_CELL_DENSITY
            max_tubes = max_cell_vol / CRYOSTOCK_VOL
            min_tubes = min_cell_vol / CRYOSTOCK_VOL
            if max_tubes < 1.0
                add_error not_enough_cells: "There is not enough cells to make a cryostock."
            end
            num_tubes = ((max_tubes + min_tubes) / 2.0).ceil
            
            
            op.temporary[:num_tubes] ||= num_tubes
            op.temporary[:tube_vol] = CRYOSTOCK_VOL
            op.temporary[:cell_density] = plate.cell_number / (num_tubes * CRYOSTOCK_VOL)
            op.temporary[:resuspension_vol] = CRYOSTOCK_VOL * op.temporary[:num_tubes]
            
            sample_properties = op.input(INPUT).sample.properties
            
            basemedia = sample_properties[GROWTH_MEDIA]
            basemedia_name = basemedia.name if basemedia
            basemedia_name ||= "?"
            op.temporary[:basemedia] = basemedia_name
        
            cryomedia = sample_properties[CRYOMEDIA]
            cryomedia_name = cryomedia.name if cryomedia
            cryomedia_name ||= "?"
            op.temporary[:cryomedia] = cryomedia_name
            
            op.temporary[:media] = basemedia_name + " " + cryomedia_name
            current_passage = op.input(INPUT).item.passage || 1
            op.temporary[:passage] = current_passage + 1
        end
    end

  def main

    operations.retrieve
    
    if debug
        operations.running.each do |op|
            op.set_output OUTPUT, [op.input(INPUT).sample] * 2, aft=op.input(INPUT).allowable_field_type
        end
    end
    
    volume_calculations operations
    create_table = Proc.new { |ops|
        ops.start_table
            .custom_column(heading: "Active Cell Line (input)") { |op| op.input(INPUT).sample.name }
            .custom_column(heading: "Growth Media") { |op| op.temporary[:basemedia] }
            .custom_column(heading: "Freezing Media") { |op| op.temporary[:cryomedia] }
            .custom_input(:num_tubes, heading: "Num Cryovials", type: "number") { |op| op.temporary[:num_tubes] || op.temporary[:default_tubes] }
            .validate(:num_tubes) { |op, val| val.between?(1,10) }
            .validation_message(:num_tubes) { |op, k, v| "Needs to be between 1 and 10" }
            .custom_column(heading: "Cryovial vol (mL)") { |op| op.temporary[:tube_vol] }
            .custom_column(heading: CELL_DENSITY) { |op| to_scinote(op.temporary[:cell_density]) }
            .end_table.all
    }
    continue = true
    counter = 0
    while counter < 5 and continue
        counter += 1
        confirm = show_with_input_table(operations.running, create_table) do
          title "Determine number of cryotubes"
          note "[#{to_scinote(MIN_CELL_DENSITY)} to #{to_scinote(MAX_CELL_DENSITY)}]"
          select ["No", "Yes"], var: :confirm, label: "Confirm your selections?", default: 0
        end
        
        if confirm[:confirm] == "No"
            continue = true
        else
            continue = false
        end
        
        volume_calculations operations.running
    end
    
    operations.running.each do |op|
        op.expand_output_array OUTPUT, op.temporary[:num_tubes]
    end
    
    group_by_media = operations.group_by { |op| op.temporary[:media] }
    media_vol_hash = Hash.new
    group_by_media.each do |media, ops|
         total_vol = ops.inject(0) { |sum, op| sum + op.temporary[:resuspension_vol] }
         media_vol_hash[media] = total_vol
    end
    
    show do
        title "Prepare media"
        
        media_vol_hash.each do |media, vol|
            check "#{media}: #{vol} mL"
        end
    end
    
    show do
        title "Trypsinize plates"
        
        table operations.running.start_table
            .input_item(INPUT)
            .end_table
    end
    
    show do
        title "Spin down cells 200xg for 5 min at RT"
        warning "Make sure to label tubes"
    end
    
    show do
        title "Aspirate off media"
    end
    
    show do
        title "Resuspend cell pellet"
        
        table operations.running.start_table
            .input_item(INPUT)
            .custom_column(heading: "Media") { |op| op.temporary[:media] }
            .custom_column(heading: "Volume (ml)") { |op| op.temporary[:resuspension_vol] }
            .end_table
    end
    
    operations.make
    
    cryostocks = operations.running.map { |op| op.output_array(OUTPUT).map { |fv| fv.item } }.flatten
    
    operations.running.each do |op|
        show do 
            title "Place cryotubes into rack"
            
            check "Place each cryotube firmly into the eppie tube holder"
            check "Stagger tubes in rack."
            
            t = Table.new
            t.add_column("Item id", op.output_array(OUTPUT).map { |fv| fv.item.id } )
            t.add_column("Sample Name", op.output_array(OUTPUT).map { |fv| fv.sample.name } )
            t.add_column("Passage", op.output_array(OUTPUT).map { |fv| op.temporary[:passage] } )
            t.add_column("Date", op.output_array(OUTPUT).map { |fv| Time.now.strftime("%m/%d/%y") })
            table t
        end
        
        show do
            title "Arrange hood"
            
            note "<b>Media</b>: #{op.temporary[:media]}"
            note "<b>Plate</b>: #{op.input(INPUT).item}"
            
            check "Gently loosen cryotube caps"
        end
        
        show do
            title "Pipette #{op.temporary[:tube_vol]} mL into each tube."
            
            t = Table.new
            t.add_column("Item id", op.output_array(OUTPUT).map { |fv| fv.item.id } )
            t.add_column("Sample Name", op.output_array(OUTPUT).map { |fv| fv.sample.name } )
            t.add_column("Passage", op.output_array(OUTPUT).map { |fv| op.temporary[:passage] } )
            t.add_column("Date", op.output_array(OUTPUT).map { |fv| Time.now.strftime("%m/%d/%y") })
        end
    end
    
    show do
        title "Place all tubes into -80C"
        
        check "Place tubes in order into styrofoam rack."
        check "Place rack into insulated container."
        check "Place entire container into -80C."
        
        outputs = operations.running.map { |op| op.output_array(OUTPUT).map { |fv| fv.item } }.flatten.uniq
        outputs.each do |i|
            i.move "-80C"
        end
    end
    
    output_associations operations.running
     
    # operations.running.each do |op|
    #     op.input(INPUT).item.mark_as_deleted
    # end
    
    operations.store io: "output"
    # release_tc_plates operations.running.map { |op| op.input(INPUT).item }
    
    
    
    # Add successor
    # TODO: Ignore if wire already exists
    # show do
    #     title "Creating new operations for plan"
    #     operations.running.each do |op|
    #         op.output_array(OUTPUT).each do |ofv|
                
    #             is_wired = false
    #             ofv.wires_as_source.each do |wire|
    #                 fv = FieldValue.find_by_id(wire.to_id)
    #                 succ = Operation.find_by_id(fv.parent_id)
    #                 if succ.operation_type.name == "Move Cryostock"
    #                     is_wired = true
    #                 end
    #             end
    #             if not is_wired
    #                 routing = [{symbol: "C", sample: ofv.sample}]
    #                 op.add_successor type: "Move Cryostock", from: OUTPUT, to: "Temp Cryostock", routing: routing
    #                 note "New Operation for #{ofv.item} created"
    #             else
    #                 note "Operation for #{ofv.item} already created"
    #             end
    #         end
    #     end
    # end if debug
    
    return {}
    
  end
end
