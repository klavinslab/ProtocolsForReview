needs "Tissue Culture Libs/TissueCulture"
needs "Tissue Culture Libs/DNA"

require 'matrix'

module TransfectionLibrary
  include TissueCulture
  include DNA

  # debug
  TEST_C_TUBE_MIXING = true
  TEST_VALIDATE_VOLUMES = false
  TEST_WITHOUT_LENGTH_VALIDATION = true

  # Get plasmids from a field value or list of field values
  def get_plasmids op, plasmid_fv_names
    plasmid_fv_names = [plasmid_fv_names].flatten
    plasmids = plasmid_fv_names.map {|n| op.input_array(n).map {|fv| fv.item}}.flatten
    op.temporary[:plasmids] = plasmids
  end

  # Parse molar_ratio input as a csv
  def get_molar_ratio op, molar_ratio_fv_name
    val_string = op.input(molar_ratio_fv_name).val
    molar_array = val_string.strip.split(/\s*,\s*/)
    molar_array.map! { |m| m.to_i }
  end

  # allows sending error if operation is a virtual operation
  # specifically for JSON transfections
  def send_error op, key, msg
    if op.virtual?
      x = op.temporary[:send_error_to]
      x.error key, msg if x
      op.error key, msg
    else
      op.error key, msg
    end
  end

  # Get the input fv of this operation container
  # or tries to sum the input containers of the successors
  def get_transfection_containers op, cells_fv_name
    input_plate_containers = []

    # Gather plate containers from input or successors' inputs
    if op.input(cells_fv_name)
      input_plate_containers << op.input(cells_fv_name).object_type
    else
      if op.successors.empty?
        send_error op,  :unable_to_find_plate_sample, "Unable to find field value #{cells_fv_name} and operation has no successors."
      end
      op.successors.each do |suc|
        fv = suc.input(cells_fv_name)
        if fv.nil?
          send_error op,  :unable_to_find_plate_sample, "Unable to find input plate #{cells_fv_name} for #{succ.operation_type.name}."
        else
          input_plate_containers << fv.object_type
        end
      end
    end
    input_plate_containers
  end


  # Uses linear algebra to calculate the volumes of each plasmid
  def calculate_volumes_of_plasmids plasmids, dna_amount, molar_ratio
    n = plasmids.size
    c_arr = plasmids.map {|p| p.get(:concentration)/1000.0}
    m_arr = molar_ratio
    l_arr = plasmids.map {|p| p.sample.properties["Length"]}

    if debug and TEST_WITHOUT_LENGTH_VALIDATION
      l_arr = plasmids.map do |p|
        l = p.sample.properties["Length"]
        if l == 0 or l.nil?
          l = rand(1000..10000)
        end
        l
      end
    end

    # Matrices
    c = Matrix.diagonal(*c_arr)
    z = m_arr.zip(l_arr).map {|x| -1.0/(x[0]*x[1])}
    t = Matrix.build(n, 1) {|r, c| r == 0 ? dna_amount : 0}

    # Create coefficient matrix
    coeff = Matrix.diagonal(*z)
    _coeff = *coeff
    (1..n-1).each {|i| _coeff[i][0] = -1.0 * _coeff[0][0]}
    (0..n-1).each {|i| _coeff[0][i] = 1}
    coeff = Matrix[*_coeff]

    # Final calculation
    v = c.inv * coeff.inv * t
    v.to_a.flatten
  end

  # Used in cost calculation as well...
  def calculate_reagent_volumes op
    total_working_volume = op.temporary[:transfection_containers].map {|p| working_volume_of(p)}.reduce(:+)
    total_vol = total_working_volume * TRANSFECTION_VOL_TO_WORKING_VOLUME * 1000.0
    dna_ng_per_ul = op.temporary[:dna_ng_per_ul] || TRANSFECTION_DNA_NG_PER_UL
    dna_amount = total_vol * dna_ng_per_ul / 1000.0 # in ug
    reagent = op.temporary[:reagent]
    reagent_to_dna = op.temporary[:reagent_to_dna] || TRANSFECTION_REAGENT_TO_DNA_RATIO[reagent]
    reagent_to_dna = TRANSFECTION_REAGENT_TO_DNA_RATIO[reagent]

    reagent_vol = dna_amount * reagent_to_dna
    optimem_vol = total_vol / 2.0

    op.temporary[:total_vol] = total_vol
    op.temporary[:dna_amount] = dna_amount
    op.temporary[:reagent_vol] = reagent_vol
    op.temporary[:tube_vol] = optimem_vol
  end

  # Calculate volumes of materials for each
  def calculate_volumes ops
    ops.each do |op|
      calculate_reagent_volumes op
      v = calculate_volumes_of_plasmids op.temporary[:plasmids], op.temporary[:dna_amount], op.temporary[:molar_ratio]
      op.temporary[:dna_vols] = v
      op.temporary[:optimem_vol_A] = op.temporary[:tube_vol] - v.reduce(:+)
      op.temporary[:optimem_vol_B] = op.temporary[:tube_vol] - op.temporary[:reagent_vol]
      if op.temporary[:optimem_vol_A] < op.temporary[:tube_vol] * 0.5
        send_error op,  :not_enough_DNA, "The concentrations of the plasmids was too dilute to run \
        (#{op.temporary[:plasmids].map {|p| "#{p.sample.name}: #{p.get :concentration} ng/ul"}.join(', ')})."
      end

      # For grouping together tubes...
      op.temporary[:reagent_conc] = (op.temporary[:reagent_vol] / op.temporary[:tube_vol]).round(3)
      op.temporary[:dna_conc] = (op.temporary[:dna_vols].map {|v| v*1.0/op.temporary[:tube_vol]})
    end
  end

  def assign_A_tubes ops
    # Group dna tubes, if they have exactly the same concentration and plasmids
    # i.e. as in transfection reps...
    group_by_dna = ops.running.group_by {|op|
      [op.temporary[:plasmids], op.temporary[:dna_conc]]
    }

    a_tubes = group_by_dna.map.with_index do |((plasmids, dna_conc), gops), i|
      optimem = gops.map {|op| op.temporary[:optimem_vol_A]}.reduce(:+)
      new_dna_vol = plasmids.map.with_index do |p, j|
        gops.map {|op| op.temporary[:dna_vols][j]}.reduce(:+)
      end

      # Assign tube i to operations
      label = "A#{i}"
      gops.each do |op|
        op.temporary[:A_tube] = label
      end

      # Save to hash
      [label, {dna_vol: new_dna_vol, optimem: optimem, dna: plasmids}]
    end.to_h
    a_tubes
  end

  def assign_B_tubes ops
    # Group PEI tubes if they have the same PEI concentration
    show do
      title "B tube debugging"

      ops.running.each do |op|
        note "#{op.temporary}"
      end
    end if debug

    group_by_reagent = ops.running.group_by {|op| [op.temporary[:reagent_conc], op.temporary[:reagent]]}
    b_tubes = group_by_reagent.map.with_index do |((rconc, r), gops), i|
      # Sum media and pei
      optimem = gops.map {|op| op.temporary[:optimem_vol_B]}.reduce(:+)
      vol = gops.map {|op| op.temporary[:reagent_vol]}.reduce(:+)

      # Assign tube i to operations
      label = "B#{i}"
      gops.each do |op|
        op.temporary[:B_tube] = label
      end

      # Save to hash
      [label, {reagent_vol: vol, reagent: r, optimem: optimem}]
    end.to_h
    b_tubes
  end

  def assign_C_tubes o
    gbyA = o.running.group_by {|op| op.temporary[:A_tube]}
    c_index = 0
    c_tubes = Hash.new
    gbyA.each do |a, opsA|
      if opsA.size > 1
        gbyB = opsA.group_by {|op| op.temporary[:B_tube]}
        gbyB.each do |b, opsB|
          label = "C#{c_index}"
          opsB.each do |op|
            op.temporary[:C_tube] = label
            c_tubes[label] ||= {a: a, b: b, a_vol: 0, b_vol: 0}
            c_tubes[label][:a_vol] += op.temporary[:tube_vol]
            c_tubes[label][:b_vol] += op.temporary[:tube_vol]
          end
          c_index += 1
        end
      else
        opsA.each do |op|
          op.temporary[:C_tube] = op.temporary[:A_tube]
        end
      end
    end
    c_tubes
  end

  def validate_volumes ops
    volume_requirements = Hash.new
    ops.running.each do |op|
      plasmids = op.temporary[:plasmids]
      plasmid_to_vol_hash = plasmids.zip(op.temporary[:dna_vols]).to_h
      volume_requirements.merge!(plasmid_to_vol_hash) {|k, old_v, new_v| old_v + new_v}
    end
    volume_requirements.each do |item, vol|
      if item.get(:volume) < vol
        ops.running.each do |op|
          if op.temporary[:plasmids].include?(item)
            send_error op,  "not_enough_volume_for_#{item.id}".to_sym, "This batch requires #{vol.round(2)} ul but there is only #{item.get(:volume)} ul."
          end
        end
      end
    end
  end

  # Validate Molar Ratio
  def validate_molar_ratio ops
    ops.running.each do |op|
      num_plasmids = op.temporary[:plasmids].size
      molar_array = op.temporary[:molar_ratio]

      if molar_array.empty?
        molar_array = [1] * num_plasmids
      else
        if molar_array.any? { |m| m == 0 }
          send_error op,  :molar_ratio_improperly_formatted, "Molar ratio parameter \"#{molar_array}\" is improperly formatted."
        end
        if molar_array.size != num_plasmids
          send_error op,  :wrong_molar_ratio_array_size, "There are #{num_plasmids} plasmids but only #{molar_array.size} entries for molar array \"#{molar_array}\""
        end
      end

      op.temporary[:molar_ratio] = molar_array

    end
  end

  def prepare_transfection_mix(ops)

    plasmids = ops.running.map {|op| op.temporary[:plasmids] }.flatten

    check_volumes plasmids

    plasmids.select! do |p|
      v = p.get(:volume)
      if v == 0.0
        ops.select { |op| op.temporary[:plasmids].include?(p) }.each do |op|
          send_error op,  "plasmid_#{p.id}_empty".to_sym, "There is no more volume for plasmid #{p.id}."
          p.mark_as_deleted
        end
      end
      v > 0.0
    end

    if plasmids.empty?
      show do
        title "There are no plasmids to transfect"
      end
      return
    end

    check_concentrations plasmids

    calculate_volumes ops.running

    validate_volumes ops.running unless debug and !TEST_VALIDATE_VOLUMES

    # check for volumes
    a_tubes = assign_A_tubes ops.running
    b_tubes = assign_B_tubes ops.running
    c_tubes = assign_C_tubes ops.running

    put_in_hood [
        "1000uL filter tips",
        "100uL filter tips",
        "20uL filter tips",
        "sterile 1.5mL tubes",
        "OptiMem (4C Deli Fridge)",
        "tip waste"
    ] + ops.map { |op| op.temporary[:reagent] }.uniq

    # Label tubes
    show do
      title "Label Tubes"

      num_tubes = a_tubes.size + b_tubes.size + c_tubes.size

      check "Retrieve #{num_tubes} sterile eppie tubes"
      check "Label #{a_tubes.size} tubes <b>#{a_tubes.keys.join(",")}</b>"
      check "Label #{b_tubes.size} tubes <b>#{b_tubes.keys.join(",")}</b>"
      check "Label #{c_tubes.size} tubes <b>#{c_tubes.keys.join(",")}</b>" if c_tubes and c_tubes.any?
    end

    # Pipette optimem
    show do
      title "Pipette OptiMem"

      tubes = a_tubes.merge(b_tubes)
      t = Table.new
      t.add_column("Tube", tubes.keys)
      t.add_column("Optimem (ul)", tubes.map {|k, v| v[:optimem].round(1)})
      table t
    end

    # Prepare A (DNA)
    a_tubes.each do |label, a|
      show do
        title "Prepare tube #{label}"

        check "Pipette the following dna into <b>#{label}</b>."
        check "Pipette up and down to mix"
        check "Close and gently flick to mix"
        t = Table.new
        t.add_column("Item id", a[:dna].map {|d| d.id})
        t.add_column("Vol (ul)", a[:dna_vol].map {|x| x.round(1)})
        table t
      end
    end

    # Prepare B (PEI)
    by_reagent = b_tubes.group_by {|k, b| b[:reagent]}
    by_reagent.each do |reagent, bt|
      show do
        title "Prepare tubes #{bt.map {|label, h| label}.join(', ')}"

        check "Pipette #{reagent} according to the table below."
        check "Pipette up and down to mix"
        check "Close and gently flick to mix"
        t = Table.new
        t.add_column("Tube", bt.map {|label, h| label})
        t.add_column("#{reagent} (uL)", bt.map {|label, h| h[:reagent_vol].round(2)})
        table t
      end
    end

    # Prepare C (Mixed tube)
    if c_tubes and c_tubes.any?

      show do
        title "Pipette A into C Tubes"

        check "Pipette indicated tube B to indicated tube C"
        check "Pipette up and down to mix"

        t = Table.new
        t.add_column("Tube A", c_tubes.map {|_, h| h[:a]})
        t.add_column("Tube A Vol", c_tubes.map {|_, h| h[:a_vol]})

        t.add_column("Tube C", c_tubes.map {|label, _| label})
        table t
      end

      show do
        title "Pipette B into C"

        check "Pipette indicated tube B to indicated tube C"
        check "Pipette up and down to mix"

        t = Table.new
        t.add_column("Tube B", c_tubes.map {|_, h| h[:b]})
        t.add_column("Tube B Vol", c_tubes.map {|_, h| h[:b_vol]})
        t.add_column("Tube C", c_tubes.map {|label, _| label})
        table t
      end
    end

    show do
      title "Pipette B into C & A tubes"

      t = Table.new
      t.add_column("Tube B", ops.running.map {|op| op.temporary[:B_tube]})
      t.add_column("Tube B Vol", ops.running.map {|op| op.temporary[:tube_vol]})
      t.add_column("Destination Tube", ops.running.map {|op| op.temporary[:C_tube]})
      table t
    end

    show do
      title "Wait 15-30 minutes"
    end

    return ops.map { |op| [op, op.temporary] }.to_h
  end
  
  # Not sure why temporary hash gets deleted, but you need to call this...
  def reassign_temporary_hash ops, h
        ops.each do |op|
            op.temporary.merge! h[op] 
        end
  end
end