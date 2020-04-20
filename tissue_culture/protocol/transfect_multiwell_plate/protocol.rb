needs "Tissue Culture Library/TransfectionLibrary"

class Protocol
  include TransfectionLibrary
  # io
  CELLS = "Cells"
  JSON = "Transfection_JSON"
  
  def main

    operations.retrieve

    operations.each do |op|
        op.set_input JSON, test_json(op)
    end
    
    if debug 
        show do
            title "Debug JSON input"
            
            operations.each do |op|
                x = op.input(JSON).val
                note "#{x.class}"
                note "#{x.to_s}"
            end
        end
    end
    
    # Create virtual operations for each transfection
    all_vops = []
    operations.each do |op|
        transfections = op.input(JSON).val 
        transfections.each do |t|
            vop = VirtualOperation.new
            insert_operation operations.size, vop
            vop.temporary.merge! t
            vop.temporary[:send_error_to] = op
            all_vops << vop
        end
    end
    all_vops.extend(OperationList)
    
    # Validate there is a sample for each transfection in the plate
    
    # Assign row, col to each virtual operation
    
    # Find plasmids
    all_vops.each do |op|
        op.temporary[:plasmids] = op.temporary[:plasmids].map { |p| Item.find_by_id(p[:id]) }
    end
    
    # Get the transfection container size
    all_vops.each do |op|
        op.temporary[:transfection_containers] = get_transfection_containers op.temporary[:send_error_to], CELLS 
    end
    
    # Validate molar ratio
    validate_molar_ratio all_vops.running
    
    # Prepare DNA complexes
    temp_hash = prepare_transfection_mix all_vops.running
    return {} if not temp_hash
    reassign_temporary_hash all_vops.running, temp_hash
    # Create a table of what plasmids exist where for the collection and associate
    ## Basically associate the temporary hash as a matrix
    
    
    operations.store

    # # :molar_ratio, :reagent, :transfection_containers
    # operations.running.each do |op|
    #   op.temporary[:molar_ratio] = [1, 3]
    #   op.temporary[:reagent] = PEI
    #   op.temporary[:transfection_containers] = get_transfection_containers op, CELLS
    # end

    # operations.running.retrieve

    # # Get the plasmids for each operation
    # operations.running.each do |op|
    #   op.temporary[:plasmids] = [144696, 144695].map { |i| Item.find_by_id(i) }
    # end

    # # Ensure molar ratio is of sample size as plasmids
    # validate_molar_ratio operations.running

    # plasmids = operations.running.map { |op| op.temporary[:plasmids] }.flatten.uniq
    
    # # check_concentrations plasmids

    # # Instructions to prepare DNA complexes
    # # requires :reagent, :plasmids, :transfection_containers, :molar_ratio to be defined
    # successful = prepare_transfection_mix operations.running
    # return {} if not successful
    
    # operations.running.make

    # # output associations

    # operations.store

    return {}

  end
  
  def reformat_table_to_json str
      
  end
  
  def test_json op
    transfections = []
    t = Hash.new
    t[:cell_sample] = op.input(CELLS).sample.id
    t[:label] = "Well1"
    t[:plasmids] = [
        {id: 144696},
        {id: 144695},
    ]
    t[:molar_ratio] = [1, 2]
    t[:reagent] = "PEI"
    t[:reagent_to_dna] = 3
    t[:dna_ng_per_ul] = 10.0
    
    transfections << t
    transfections.to_json
  end
  

end