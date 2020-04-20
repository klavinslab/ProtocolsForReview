needs "Tissue Culture Libs/TransfectionLibrary"

class Protocol
  include TransfectionLibrary

  # io
  TRANSFER = "Transfer Plasmid"
  REV = "Packaging Plasmid (REV)"
  GAG = "Packaging Plasmid (GAG/POL)"
  ENV = "Envelope Plasmid"
  CELLS = "Packaging Cell Line"
  OUTPUT = "Lentivirus DNA Complex"
  PLASMIDS = [TRANSFER, REV, GAG, ENV]
  MOLAR_RATIO = {
      TRANSFER=>4,
      REV=>1,
      GAG=>2,
      ENV=>1
  }
  
  # debug
  TEST_WITHOUT_LENGTH_VALIDATION = true

  def main
    
    # Get the plasmids from operation inputs
    debug_plasmids()
    get_plasmids_from_inputs()
    
    # Validate that the length of all the plasmids exists
    validate_lengths_of_plasmids()
    debug_molar_ratio()
    
    # Assign :molar_ratio, :reagent, :transfection_containers to operations
    assign_transfection_data()
    
    # Get items
    operations.running.retrieve
    
    # Validate the molar ratio matches the number of plasmids
    validate_molar_ratio operations.running
    
    # Instruct technician to prepare the transfection mix
    prep_transfection_mix()
    debug_temporary_hash()
    
    # Create output collection and associate data to output collection
    make_and_assign_transfection_mix()
    debug_output_associations()
    
    # Ask to schedule the downstream 
    show_schedule_other_ops()
    
    operations.store
    return {}

  end
  
  def make_and_assign_transfection_mix
    # TODO: Add ability to branch wires from launcher
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
  end
  
  def prep_transfection_mix
    temp_hash = prepare_transfection_mix operations.running
    return {} if not temp_hash
    reassign_temporary_hash operations.running, temp_hash # Not sure why temporary hash gets deleted, but you need to call this...
  end
  
  def get_plasmids_from_inputs
    operations.running.each do |op|
      op.temporary[:plasmids] = get_plasmids op, PLASMIDS
    end
  end
  
  def debug_output_associations
    show do
      title "debug output associations"

      operations.running.each do |op|
        note "#{op.output(OUTPUT).item.associations}"
      end
    end if debug
  end
  
  def debug_plasmids
    show do
        title "Debug plasmids"
        
        operations.each do |op|
            note "#{op.temporary[:plasmids]}"
        end
    end if debug
  end
  
  def debug_molar_ratio
    # Debug init of molar ratio
    if debug
      operations.running.each do |op|
        op.set_input MOLAR_RATIO, ""
      end
    end
  end
  
  def debug_temporary_hash
    if debug
      show do
        title "debug: Operation temporary hashes"
        operations.running.each do |op|
          note "#{op.temporary}"
        end
      end
    end
  end
  
  def validate_lengths_of_plasmids
    # Validate plasmid lengths
    unless debug and TEST_WITHOUT_LENGTH_VALIDATION
      validate_lengths(operations.running) {|op| op.temporary[:plasmids]}
    end
  end
  
  def assign_transfection_data
    # Assign :molar_ratio, :reagent, :transfection_containers
    operations.running.each do |op|
      op.temporary[:molar_ratio] = PLASMIDS.map { |name| MOLAR_RATIO[name] }
     
      op.temporary[:reagent] = PEI
      if debug
        op.temporary[:transfection_containers] ||= [ObjectType.find_by_name("T25")]
      else
        op.temporary[:transfection_containers] = get_transfection_containers op, CELLS
      end
    end
  end
  
  def show_schedule_other_ops
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
  end

end