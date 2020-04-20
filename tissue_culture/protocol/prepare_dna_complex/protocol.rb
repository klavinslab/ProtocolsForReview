needs "Tissue Culture Libs/TransfectionLibrary"

class Protocol
  include TransfectionLibrary

  # io
  PLASMIDS = "Transfected Plasmids"
  MOLAR_RATIO = "Molar Ratio"
  CELLS = "Parent Cell Line"
  REAGENT = "Reagent"
  OUTPUT = "DNA Complex"

  # debug
  TEST_WITHOUT_LENGTH_VALIDATION = true

  def main
    # Validate plasmid lengths
    unless debug and TEST_WITHOUT_LENGTH_VALIDATION
      validate_lengths(operations.running) {|op| op.input_array(PLASMIDS).map {|fv| fv.item}.flatten}
    end

    # Debug init of molar ratio
    if debug
      operations.running.each do |op|
        op.set_input MOLAR_RATIO, ""
        op.set_input REAGENT, "PEI"
      end
    end

    # Assign :molar_ratio, :reagent, :transfection_containers
    operations.running.each do |op|
      op.temporary[:molar_ratio] = get_molar_ratio op, MOLAR_RATIO
      op.temporary[:reagent] = op.input(REAGENT).val.strip
      if debug
        op.temporary[:transfection_containers] ||= [ObjectType.find_by_name("T25")]
      else
        op.temporary[:transfection_containers] = get_transfection_containers op, CELLS
      end
    end

    operations.running.retrieve

    # Test C-tube branching
    if operations.running.size > 2 and debug and TEST_C_TUBE_MIXING
      op1 = operations.running[0]
      op2 = operations.running[1]

      op2.input_array(PLASMIDS).zip(op1.input_array(PLASMIDS)).each do |fv2, fv1|
        fv2.copy_inventory fv1
      end
    end

    # Get the plasmids for each operation
    operations.running.each do |op|
      op.temporary[:plasmids] = get_plasmids op, ["Maxipreps", "Midipreps", "Minipreps", "Unverified Stocks"]
    end

    # Ensure molar ratio is of sample size as plasmids
    validate_molar_ratio operations.running

    # Instructions to prepare DNA complexes
    # requires :reagent, :plasmids, :transfection_containers, :molar_ratio to be defined
    temp_hash = prepare_transfection_mix operations.running
    return {} if not temp_hash
    reassign_temporary_hash operations.running, temp_hash

    if debug
      show do
        title "debug: Operation temporary hashes"
        operations.running.each do |op|
          note "#{op.temporary}"
        end
      end
    end

    gbyC = operations.running.group_by {|op| op.temporary[:C_tube]}
    gbyC.each do |c_tube, ops|
      complex = ops.first.output(OUTPUT).make_collection
      complex.apportion 1, ops.size
      ops.each do |op|
        r, c, x = complex.add_one op.output(OUTPUT).sample
        op.output(OUTPUT).set row: r, column: c, collection: complex
      end

      # Associate data
      part_associations = complex.matrix
      ops.each do |op|
        tmp = op.temporary.clone
        tmp.delete(:transfection_containers)
        tmp[:plasmids] = tmp[:plasmids].map {|x| x.id}
        part_associations[op.output(OUTPUT).row][op.output(OUTPUT).column] = tmp
      end
      ops.each do |op|
        op.output(OUTPUT).item.associate :part_associations, part_associations
      end
      complex.move HOOD
    end

    show do
      title "debug output associations"

      operations.running.each do |op|
        note "#{op.output(OUTPUT).item.associations}"
      end
    end if debug

    show do
      title "Have the manager schedule the following operations"

      successors = operations.running.map do |op|
        op.successors.map do |succ|
          succ.operation_type.name
        end
      end.flatten.uniq
      successors.each do |s|
        bullet "#{s}"
      end
    end

    # output associations
    operations.running.each do |op|
      op.output(OUTPUT).item.associate :transfected_plasmid_item_ids, op.temporary[:plasmids].map {|p| p.id}
    end

    operations.store

    return {}

  end

end