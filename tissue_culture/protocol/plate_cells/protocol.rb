needs "Tissue Culture Libs/TissueCulture"
# TODO: Media is not properly associated
# TODO: Resuspend cells if they are not re-suspended in a library
# TODO: Add specific media
# TODO: Check if plates will be used in other operations by associated operation ids to plate in the select plate protocol
class Protocol
  include TissueCulture

  # io
  INPUT = "Cell Request"
  OUTPUT = "Plate"
  SEED = "Seed Density (%)"

  # debug
  TEST_PROTOCOL_BRANCHING = true

  def main

    operations.retrieve

    ###############################
    ## Calculations
    ###############################

    # Error if plate request was never changed
    operations.running.each do |op|
      if op.input(INPUT).item.object_type.name == "Trypsinized Plate Request"
        op.error :rewiring_error, "Something went wrong with the rewiring of Request > Trypsinized Plate. \
                    Input to this operation does not physically exist."
      end
    end

    if debug and TEST_PROTOCOL_BRANCHING and operations.running.size >= 2
      operations.running[1].input(INPUT).set item: operations.first.input(INPUT).item
    end

    # Assign fake confluency, cell density and volume data
    if debug
        assign_fake_input_data(operations.running)
    end
    
    operations.running.each do |op|
      op.error :no_volume_data, "The volume of this item was not properly set." unless op.input(INPUT).item.volume
      op.error :no_cell_density_data, "The cell density of this item was not properly set." unless op.input(INPUT).item.cell_density
    end

    volume_calculations operations.running

    error_out_operations operations.running

    debug_table
    
    validate_volumes operations.running
    
    # Create temporary labels
    grouped_by_input = operations.running.group_by { |op| op.input(INPUT).item }
    
    grouped_by_input.keys.zip(('A'..'Z').to_a).each { |input_plate, label|
      input_plate.associate :temporary_label, label if not input_plate.get :temporary_label
    } if debug

    grouped_by_input.each do |i, ops|
      input_label = i.get(:temporary_label)
      input_label ||= i.get(:from)
      ops.each.with_index do |op, index|
        op.temporary[:input_label] = "#{input_label}"
        op.temporary[:output_label] = "#{input_label}-#{index}"
      end
    end

    # Retrieve empty plates
    grouped_by_object_type = operations.running.group_by { |op| op.output(OUTPUT).object_type }
    show do
      title "Retrieve the following plates and place them in the #{HOOD}"
      t = Table.new
      t.add_column("Plate Type", grouped_by_object_type.keys.map { |o| o.name })
      t.add_column("Quantity", grouped_by_object_type.map { |o, ops| ops.size })
      table t
    end

    # Label plates
    create_top_labels operations.running
    label_tabel = operations.running.start_table
                      .custom_column(heading: "Container") { |op| op.output(OUTPUT).object_type.name }
                      .custom_column(heading: "Large Label (Top)") { |op| op.temporary[:top_label] }
                      .end_table
    operations.running.each.with_index do |op, i|
      show do
        title "Label empty #{op.output(OUTPUT).object_type.name} plate/flask"

        note "Image of labeled plate"

        table label_tabel.from(i).to(i+1)
      end
    end

    # Transfer media
    gbymedia = operations.running.group_by { |op| op.input(INPUT).item.get :media }
    gbymedia.each do |media_id, ops|
        media = Item.find_by_id(media_id)
        identifier = "#{media.sample.name if media} #{media_id}"
        show do
          title "Transfer media #{identifier} to labeled empty plates"
          note "Use media: #{identifier}"
          table operations.running.start_table
                    .custom_column(heading: "Label") { |op| op.temporary[:output_label] }
                    .custom_column(heading: "Vol (mL)") { |op| op.temporary[:media_vol].round(1) }
                    .end_table
        end
    end

    # Transfer cells
    # TODO: Group single operations into one big table
    # TODO: Separate steps for protocol branching
    grouped_by_input.each do |input_plate, ops|
      input_plate_name = "#{input_plate} (#{ops.first.temporary[:input_label]}) #{input_plate.object_type.name}"
      show do
        title "Move plates to workspace (central) position"
        
        plates = ["#{ops.first.temporary[:input_label]} (#{input_plate.id})"]
        plates += ops.map { |op| op.temporary[:output_label] }
        t = Table.new
        t.add_column("Plates", plates)
        table t
      end

      show do
        title "Transfer cells from #{input_plate_name} to plates #{ops.map { |op| op.temporary[:output_label] }.join(', ')}"

        note "Transfer listed volume from old plate to new plate."

        table ops.start_table
                  .custom_column(heading: "Transfer") { |op| "#{op.temporary[:input_label]} <span>&#10230;</span> #{op.temporary[:output_label]}" }
                  .custom_column(heading: "Vol (mL)") { |op| op.temporary[:cell_vol].round(1) }
                  .end_table
      end
    end



    operations.running.each do |op|
      op.input(INPUT).item.volume = op.input(INPUT).item.volume - op.temporary[:cell_vol]
    end

    operations.running.make
    
      operations.running.each do |op|
        fv = op.input(INPUT)
        cell_suspension = fv.collection
        cell_suspension.set fv.row, fv.column, -1
        cell_suspension.mark_as_deleted if cell_suspension.empty?
    end
    
    show do
        title "Label Plates"
        check "Cross out temporary label"
        check "Add new label"
        table operations.running.start_table
            .custom_column(heading: "Temporary Label") { |op| op.temporary[:output_label] }
            .output_item(OUTPUT, heading: "New Label")
            .end_table
    end        

    output_associations operations.running

    show do
      title "Mix cells"

      note "For each plate, mix cells in North-South & East-West fasion."
      separator
      bullet "North-South 5 times"
      bullet "East-West 5 times"
      bullet "Repeat above steps 3 times"
    end

    gbysuspension = operations.running.group_by { |op| op.input(INPUT).collection }
    suspensions = gbysuspension.keys
    non_empty_suspensions = suspensions.select { |s| !s.empty? }
    empty_suspensions = suspensions.select { |s| s.empty? }
    if non_empty_suspensions.any?
        show do
          title "Move trypsinized plates aside in #{HOOD}"
          
          note "The following cell suspensions will be used in other protocols. Set them aside in the #{HOOD}."
    
          suspensions.select { |s, _| !s.empty? }.each do |s|
              note "#{s.id}"
          end
        end
    end
    
    release_tc_plates empty_suspensions if empty_suspensions.any?
    operations.store
    
    if debug
      show do
        title "DEBUG: Output item associations"

        operations.running.each do |op|
          out = op.output(OUTPUT).item
          if out
            note "#{out} #{out.associations}"
          end
        end
      end
    end

    return {}

  end # main

  # Creates a nicely formated top label table for the technician
  def create_top_labels ops
    now = Time.now
    ops.each do |op|
      item = op.output(OUTPUT).item
      temporary_label = op.temporary[:output_label]
      item_label = ""
      if item
        temporary_label = temporary_label.strike.add_tag("font", color: "red")
        item_label = " " + op.output(OUTPUT).item.id.to_s.bold.add_tag("font", color: "green")
      end

      op.temporary[:top_label] = \
                "<table style=\"width:100%\">
                    <tr><td>#{temporary_label}#{item_label}</td></tr>
                    <tr><td>#{op.output(OUTPUT).sample.name}</td></tr>
                    <tr><td>#{now.strftime("%a %m/%d/%y") }</td></tr>
                    <tr><td>P: #{ op.temporary[:passage] }</td></tr>
                    <tr><td>Seed: #{ op.input(SEED).val }%</td></tr>
                </table>"
    end
  end

  def output_associations ops
    operations.running.each do |op|
      out_plate = op.output(OUTPUT).item
      from_plate = op.temporary[:from_plate]
      out_plate.split_from from_plate, op.input(SEED).val.to_f.round(0)
      out_plate.volume = op.temporary[:volume]
    end
  end

  # Calculates volumes required for plating cells
  def volume_calculations ops
    ops.each do |op|
      p = op.input(INPUT).item.get :passage
      op.temporary[:passage] = p + 1 if p
      op.temporary[:passage] ||= 1
      op.temporary[:req_cells] = op.required_cells
      op.temporary[:cell_vol] = (op.temporary[:req_cells] / op.input(INPUT).item.cell_density)
      op.temporary[:media_vol] = working_volume_of(op.output(OUTPUT).object_type) - op.temporary[:cell_vol] || 0.0
      op.temporary[:media_vol] = 0 if op.temporary[:media_vol] < 0
      op.temporary[:volume] = op.temporary[:cell_vol] + op.temporary[:media_vol]

      in_plate = op.input(INPUT).item
      from_plate_id = in_plate.get :from

      op.error :from_plate_id_not_defined, ":from not defined" if from_plate_id.nil?
      from_plate = Item.find_by_id(from_plate_id)
      op.error :cannot_find_original_plate, "Could not find original plate with id #{from_plate_id}." if from_plate.nil?
      op.temporary[:from_plate] = from_plate if from_plate
    end
  end

  def error_out_operations ops
    # Error out operations that have too much volume
    ops.each do |op|
      if op.temporary[:volume] > 1.5 * op.output(OUTPUT).extend(CellCulture).working_volume
        op.error :over_volume, "There was too much volume in well to proceed."
      end
    end

    # Error out operations that don't have enough cells
    ops.each do |op|
      if op.temporary[:cell_vol] > op.input(INPUT).item.get(:volume)
        op.error :not_enough_cells, "There is not enough cells"
      end
    end
  end
  
  def assign_fake_input_data ops
    all_plates = get_plates()
      operations.running.each do |op|
        cells = op.input(INPUT).item
        if debug
            cells.volume = rand(5..30) if not cells.volume
            cells.cell_density = rand(1e6..1e7) if not cells.cell_density
        end
          
        from = all_plates.sample
        if from
            op.input(INPUT).item.from = from
            from.confluency = rand(50..100) if from.confluency.nil?
        else
            # cells.associate :from, rand(1000..10000) if from.nil?
        end
      end
  end
  
  def validate_volumes ops
    gbyitem = ops.group_by { |op| op.input(INPUT).item } 
    gbyitem.each do |item, gops|
        remaining_cells = item.volume
        gops.each do |op|
            remaining_cells = remaining_cells - op.temporary[:cell_vol] 
            if remaining_cells < 0
                op.error :not_enough_cells, "There were not enough cells in this batch to complete the operation (needs #{-remaining_cells.round(2)} mL)."
            end
        end
    end
  end
  
  def debug_table
          show do
              title "Calculations"
        
              table operations.running.start_table
                        .input_item(INPUT)
                        .custom_column(heading: "Input Label") { |op| op.temporary[:input_label] }
                        .custom_column(heading: "Input Type") { |op| op.input(INPUT).item.object_type.name }
                        .custom_column(heading: "Output Label") { |op| op.temporary[:output_label] }
                        .custom_column(heading: "Output Type") { |op| op.output(OUTPUT).object_type.name }
                        .custom_column(heading: SEED) { |op| op.input(SEED).val }
                        .custom_column(heading: "Cell density") { |op| op.input(INPUT).item.cell_density }
                        .custom_column(heading: "From") { |op| op.input(INPUT).item.get :from }
                        .custom_column(heading: "Req Cells") { |op| to_scinote(op.required_cells) }
                        .custom_column(heading: "Cell Vol") { |op| op.temporary[:cell_vol] }
                        .custom_column(heading: "Available Vol") { |op| op.input(INPUT).item.volume }
                        .end_table
            end if debug
    end


end
