needs 'Tissue Culture Libs/DNA'
needs 'Tissue Culture Libs/CollectionDisplay'

class Protocol
  include DNA
  include CollectionDisplay

  # IO
  DONOR = "Donor DNAs"
  YEAST = "Yeast"
  GRNA = "gRNA Cassettes"
  BB = "gRNA Cassette Backbone"
  OUTPUT = "Transformed Well"
  RATIOS = "Molar Ratios"
  TOTAL = "Total DNA"

  # IO Parameters
  GRNA_AMT = "gRNA amounts (ng)"
  BB_AMT = "Backbone amount (ng)"
  DONOR_AMT = "Donor DNA amounts (ng)"

  # static input names
  SSDNA = "Salmon Sperm DNA (boiled)"
  LIOAC = "1.0 M LiOAc"
  PEG = "50 percent PEG 3350"

  # volumes
  LIOAC_VOL = 36 #uL
  SSDNA_VOL = 25 #uL
  PEG_VOL = 240 #uL

  def main

    if debug
      debug_setup(operations)
    end

    validate(operations)

    if operations.running.length == 0
        show do
            title "There are no operations to run"
            
            note "#{operations.errored.length}/#{operations.length} operations have errored."
        end
        return {}
    end
    

    add_static_inputs(operations)

    # op.add_input name, sample, container
    # op.input(name).set item: sample.in(container.name).first
    #
    # peg = find(:item, object_type: { name: "50 percent PEG 3350" })[-1]
    # lioac = find(:item, object_type: { name: "1.0 M LiOAc" })[-1]
    # ssDNA = find(:item, object_type: { name: "Salmon Sperm DNA (boiled)" })[-1]
    # reagents = [peg] + [lioac] + [ssDNA]
    # take reagents, interactive: true

    operations.retrieve.make

    volume_calculations(operations.running)

    # Yeast transformation preparation
    yeast_transformation

    # Re-label all comp cell tubes
    # relabel_comp_cell_tubes(operations.running)

    # Load comp cell aliquots with plasmid, full plamid, or fragment
    load_comp_cell_aliquots(operations.running)

    operations.running.each do |op|
      op.input(YEAST).item.mark_as_deleted
    end

    # Vortex strongly and heat shock
    vortex_and_heat

    gather_plates(operations.running)

    # Retrive tubes and spin down
    retrieve_tubes(operations.running)

    transfer_cells(operations.running)

    operations.store

    {}

  end

  def add_static_inputs(ops)
    ops.each do |op|
      add_item_input(op, "50% PEG", SSDNA)
      add_item_input(op, "LiOAc", LIOAC)
      add_item_input(op, "Salmon Sperm DNA", PEG)
    end
  end

  def validate(operations)
    all_dnas = []
    operations.each do |op|
      errors = []
      donor_length = op.input_array(DONOR).length
      donor_amt_length = op.input(DONOR_AMT).val.length
      grna_length = op.input_array(GRNA).length
      grna_amt_length = op.input(GRNA_AMT).val.length

      if donor_length != donor_amt_length
        errors << "#{op.id} Donor DNA length '#{DONOR}' must be same length as Donor amount array '#{DONOR_AMT}'
                 (#{donor_length} vs #{donor_amt_length})"
      end

      if grna_length != grna_amt_length
        errors << "#{op.id} Donor DNA length '#{GRNA}' must be same length as gRNA cassette amount array '#{GRNA_AMT}'
                 (#{grna_length} vs #{grna_amt_length})"
      end

      if donor_length != grna_length
        errors << "#{op.id} Donor DNA length '#{DONOR}' must be same length as gRNA cassete amount array '#{GRNA}'
                 (#{donor_length} vs #{grna_length})"
      end

      if debug and errors.any?
        show do
          title 'ERRORS'
          note "#{errors}"
        end
      end

      if errors.any?
        op.error :multiple_validation_error, errors.map.with_index {|e, i| "(#{i}) - #{e}"}.join(' ')
      end

      io = [DONOR, GRNA, BB]
      dna_field_values = io.map {|fvname| op.input_array(fvname)}.flatten()
      input_dnas = dna_field_values.map {|fv| fv.item}
      all_dnas = all_dnas + input_dnas
    end

    check_concentrations(all_dnas)

    # validate_lengths(operations) { |op| op.input_array(GRNA) }
    # validate_lengths(operations) { |op| op.input_array(BB) }
    # validate_lengths(operations) { |op| op.input_array(DONOR) }
  end

  def debug_setup(operations)
    operations.each do |op|
      grna_amts = op.input_array(GRNA).map {|fv| rand(10..250)}

      grna_amt = op.input(GRNA_AMT)
      grna_amt.value = op.input_array(GRNA).map {|fv| rand(10..250)}
      grna_amt.save()

      bb_amt = op.input(BB_AMT)
      bb_amt.value = rand(30..500)
      bb_amt.save()

      donor_amt = op.input(DONOR_AMT)
      donor_amt.value = op.input_array(DONOR).map {|fv| rand(100..1000)}
      donor_amt.save()
    end
  end

  def volume_calculations(operations)
    io = [DONOR, GRNA, BB]
    io_amt = [DONOR_AMT, GRNA_AMT, BB_AMT]
    # TODO: make broader hash with sum of volumes
    operations.each do |op|
      dna_field_values = io.map {|fvname| op.input_array(fvname)}.flatten()
      amt_field_values = io_amt.map {|fvname| op.input(fvname)}.flatten()
      amts = amt_field_values.map {|fv| Array(fv.val)}.flatten()
      dnas = dna_field_values.map {|fv| fv.item}
      volumes = dnas.zip(amts).map {|d, a| a / d.get(:concentration)}
      volumes.map! {|v| v < 0.2 ? 0.2 : v.round(2)}
      op.temporary[:volumes] = dnas.map {|d| d.id}.zip(volumes).to_h # item_id to volume hash
    end
  end

  # This method tells the technician to load comp cell aliquots with plasmid or fragment.
  def load_comp_cell_aliquots(operations)

    # add backbone

    # grouped by output ... make a hash with op.id => the color to be used...
    colors = ["#FFDC50", "#75F9FF"]
    outputs = operations.map {|op| op.input(YEAST).item.id}
    output_labels = outputs.zip(colors * outputs.length).map {|o, c|
      "<div style=\"background-color:#{c};\">#{o}</div>"
    }

    output_color_hash = {}

    operations.each.with_index do |op, i|
      output_color_hash[op.input(YEAST).item.id] = output_labels[i]
    end

    show do
      title "Load backbone plasmid"
      note "<i>note: colors are just a visual guide to group different output tubes</i>"
      table operations.start_table
                .input_item(BB, heading: "Backbone DNA")
                .custom_column(heading: "Volume (uL)") {|op| op.temporary[:volumes][op.input(BB).item.id]}
                .custom_column(heading: "=> Yeast Cell", checkable: true) {|op| output_color_hash[op.input(YEAST).item.id]}
                .end_table
    end

    dna_fvs = []
    dna_items = []
    dna_volumes = []
    operations.each.with_index do |op, i|
      fvs = [op.input(GRNA), op.input_array(DONOR), op.input(BB)].flatten
      items = fvs.map {|fv| fv.item}
      dna_fvs = dna_fvs + fvs
      dna_items = dna_items + items
      dna_volumes = dna_volumes + items.map {|item| op.temporary[:volumes][item.id]}
    end

    io_table = Table.new
    io_table.add_column("Fragments", dna_fvs.map {|fv| fv.sample.name})
    io_table.add_column("Item", dna_items.map {|i| i.id})
    io_table.add_column("Volume (uL)", dna_volumes)
    io_table.add_column("=> Yeast Cell", dna_fvs.map {|fv| output_color_hash[fv.operation.input(YEAST).item.id]},)

    show do
      title "Load donor DNA and guide Cassettes"
      note "<i>note: colors are just a visual guide to group different output tubes</i>"
      table io_table
    end
  end

  # # This method tells the technician to re-label all comp cell tubes.
  # def relabel_comp_cell_tubes(operations)
  #   show do
  #     title "Re-label all the competent cell tubes"
  #
  #     table operations.start_table
  #               .input_item("Yeast", heading: "Old ID")
  #               .output_item("Transformed Yeast", heading: "New ID", checkable: true)
  #               .end_table
  #   end
  # end

  # This method tells the technician to vortex and heat.
  def vortex_and_heat
    show do
      title "Vortex strongly and heat shock"

      check "Vortex each tube on highest settings until the cells are resuspended."
      check "Place all aliquots on <b>42 C</b> heat block for <b>15 minutes</b> (Timer starts on next slide)."
    end
  end

  # This method tells the technician to retrieve tubes.
  def retrieve_tubes(operations)
    show do
      title "Retrieve tubes and spin down"

      timer initial: {hours: 0, minutes: 15, seconds: 0}

      check "After timer finishes, retrieve all #{operations.length} tubes from 42 C heat block."
    end
  end

  def gather_plates(operations)
    grouped_by_collections = operations.group_by { |op| op.output(OUTPUT).collection }
    show do
      title "Transfer cells to deep well plate"
      note "Gather #{grouped_by_collections.length} sterile deep well plates"
      note "Label plates: <b>#{grouped_by_collections.map {|collection, _| collection.id}.join(',')}</b>"
    end

    # grouped_by_collections.each do |collection, grouped_ops|
    #   show do
    #     title "Transfer 1mL YPAD into the specified wells for plate #{collection.id}"
    #     note "Plate ##{collection.id}"
    #     check "After adding media, seal plate with a breathable seal"
    #     table highlight_alpha_non_empty(collection) { |r, c| "1mL YPAD"}
    #   end
    # end
  end

  def transfer_cells(operations)
    output_by_rc = operations.map do |op|
      ["#{op.output(OUTPUT).row}-#{op.output(OUTPUT).column}", op]
    end.to_h
    grouped_by_collections = operations.group_by { |op| op.output(OUTPUT).collection }

    show do
      title "Pellet cells and resuspend in 1mL YPAD"
      check "Spin down tubes in table top centrifuge for ~20 seconds to pellet cells"
      check "Resuspend cell pellets in 1mL YPAD"
      warning "Make sure cell pellets are completely resuspended."
    end

    grouped_by_collections.each do |collection, grouped|
      show do
        title "Transfer cells into plate ##{collection}"
        check "Transfer the entire volume of each cell suspension to its corresponding well as indicated by the table"
        note "<i>Each number in the table corresponds to the id on the tube containing the cells</i>"
        table highlight_alpha_non_empty(collection) { |r,c| output_by_rc["#{r}-#{c}"].input(YEAST).item.id }
      end
    end

    show do
      title "Transfer plates to 30C shaker"

      check "Transfer each plate to a shaker in the large 30C. Shake at <b>900RPM</b>"
      note "The shaker should have 4 spots available for 96-well plates. Place the plate in its slot " +
            "using the rubber bands to hold the plates down."
      warning 'DON\'T FORGET TO TURN ON THE SHAKER!'
    end
  end

  # # This method tells the technician to resuspend in YPAD and incubate.
  # def resuspend_in_YPAD ops_to_incubate
  #   show do
  #     title "Resuspend in YPAD and incubate"
  #
  #     check "Grab #{"tube".pluralize(ops_to_incubate.length)} with id #{(ops_to_incubate.collect {|op| op.output("Transformation").item.id}).join(", ")}"
  #     check "Add 1 mL of YPAD to the each tube and vortex for 20 seconds"
  #     check "Grab #{ops_to_incubate.length} 14 mL #{"tube".pluralize(ops_to_incubate.length)}, label with #{(ops_to_incubate.collect {|op| op.output("Transformation").item.id}).join(", ")}"
  #     check "Transfer all contents from each 1.5 mL tube to corresponding 14 mL tube that has the same label number"
  #     check "Place all #{ops_to_incubate.length} 14 mL #{"tube".pluralize(ops_to_incubate.length)} into 30 C shaker incubator"
  #     check "Discard all #{ops_to_incubate.length} empty 1.5 mL #{"tube".pluralize(ops_to_incubate.length)} "
  #   end
  # end

  # This method instructs the technician to perform a yeast transformation.
  def yeast_transformation
    show do
      title "Yeast transformation preparation"

      check "Spin down all the Yeast Competent Aliquots on table top centrifuge for 20 seconds"
      check "Add <b>#{PEG_VOL} l</b> of <b>#{PEG}</b> into each competent aliquot tube."
      warning "Be careful when pipetting PEG as it is very viscous. Pipette slowly"

      check "Add <b>#{LIOAC_VOL} l</b> of <b>#{LIOAC}</b> to each tube"
      check "Add <b>#{SSDNA_VOL} l</b> of <b>#{SSDNA}</b> to each tube"
      warning "The order of reagents added is crucial for success of transformation."
    end
  end

  def add_item_input(op, field_name, container_name)
    container = ObjectType.find_by_name(container_name)
    if container.nil?
      raise "Could not find ObjectType '#{container_name}'"
    end
    items = Item.where(object_type_id: container.id).reject(&:deleted?)
    if items.empty?
      op.error(:inventory_missing, "missing inventory for #{container.name}")
    end

    item = items.last

    # add new FieldType
    ft = FieldType.new(name: field_name, ftype: 'sample',
                       parent_class: 'OperationType', parent_id: nil
    )
    ft.save

    # add and set new FieldValue
    fv = FieldValue.new(name: field_name, child_item_id: item.id,
                        child_sample_id: nil, role: 'input',
                        parent_class: 'Operation', parent_id: op.id,
                        field_type_id: ft.id
    )
    fv.save
  end

  def molar_mix(total_dna, concentrations, lengths, molar_ratios, max_vol = nil, min_pipette_vol = 0.2, round = 2)
    length = concentrations.length
    total_dna_arr = [0.0] * length
    total_dna_arr[0] = total_dna.to_f
    total_vol_matrix = Matrix.column_vector(total_dna_arr)

    x = concentrations.zip(lengths, molar_ratios).map {|c, l, r|
      -1.0 * c / (r * l)
    }

    first_row = Matrix.row_vector(concentrations)
    first_col = Matrix.column_vector([-1.0 * x[0]] * (length - 1))
    m = Matrix.diagonal(*x.slice(1..x.length))
    m = first_row.vstack(first_col.hstack(m))
    f_vol = m.inv * total_vol_matrix
    vol_arr = f_vol.to_a.flatten

    vol_arr = vol_arr.map {|v| v < min_pipette_vol ? min_pipette_vol : v}
    if max_vol
      total_vol = vol_arr.inject(:+)
      if total_vol > max_vol
        scale = total_vol / max_vol.to_f
        vol_arr.map! {|v| v / scale}
      end
    end

    return vol_arr.map {|v| v.round(round)}
  end
end
