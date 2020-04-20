# methods for extracting information from the PEI complex collection
module PlateTransfectionLib
    
  FAKE_DNA_COMPLEX_DATA = [[{"molar_ratio" => [1, 1, 1], "reagent" => "Lipofectamine 3000", "transfection_containers" => [{"cleanup" => "No cleanup information", "columns" => nil, "cost" => 0.01, "created_at" => "2017-03-30T13:19:45-07:00", "data" => "{\"growth_area\": 25.0, \"working_volume\": 5.0}", "description" => "25 cm^2 growth area; filtered caps", "handler" => "sample_container", "id" => 570, "image" => "T25Flask", "max" => 1, "min" => 0, "name" => "T25", "prefix" => "C37", "release_description" => "", "release_method" => "return", "rows" => nil, "safety" => "No safety information", "sample_type_id" => 24, "unit" => "Active Cell Line", "updated_at" => "2017-03-30T14:34:44-07:00", "vendor" => "No vendor information"}], "plasmids" => [{"created_at" => "2017-08-14T19:28:31-07:00", "data" => nil, "id" => 163048, "inuse" => 0, "object_type_id" => 647, "quantity" => 1, "sample_id" => 5087, "updated_at" => "2017-08-14T19:28:31-07:00"}, {"created_at" => "2017-08-14T19:28:31-07:00", "data" => nil, "id" => 163049, "inuse" => 0, "object_type_id" => 647, "quantity" => 1, "sample_id" => 9203, "updated_at" => "2017-08-14T19:28:31-07:00"}, {"created_at" => "2017-08-14T19:28:31-07:00", "data" => nil, "id" => 163050, "inuse" => 0, "object_type_id" => 647, "quantity" => 1, "sample_id" => 6839, "updated_at" => "2017-08-14T19:28:31-07:00"}], "total_vol" => 500.0, "dna_amount" => 5.0, "reagent_vol" => 7.5, "tube_vol" => 250.0, "dna_vols" => [6.963788300835654, 5.486177758011282, 12.913618415011175], "optimem_vol_A" => 224.6364155261419, "optimem_vol_B" => 242.5, "reagent_conc" => 0.03, "dna_conc" => [0.027855153203342618, 0.021944711032045126, 0.0516544736600447], "A_tube" => "A0", "B_tube" => "B0", "C_tube" => "A0"}]]
  
  # Gets hash at the of the fv.collection at the fv.row,fv.column
  # fv.item.part_associations = [
  #   [{...}, {...}, ...], 
  #   [{...}, {...}, ...],
  #   ...
  # ]
  def get_part_association fv
    x = fv.item.get(:part_associations)
    r = x[fv.row] if x
    c = r[fv.column] if r
    c
  end

  # Gets value of key for a fv.row,fv.column
      # fv.item.part_associations = [
      #   [{key: value}, {key: value}, ...], 
      #   [{key: value}, {key: value}, ...],
      #   ...
      # ]
  def get_data fv, key
    get_part_association(fv)[key]
  end

  # Moves all of the data located at fv.row,fv.column to the op.temporary
  # e.g
  # transfer_data_to_temporary(ops, { |op| op.input("INPUT") })
  def transfer_data_to_temporary ops, &fv_block
    ops.each do |op|
      fv = yield(op)
      x = get_part_association(fv)
      y = x.map {|k, v|
        [k.to_sym, v]
      }.to_h if x
      op.temporary.merge!(y) if y
    end
  end
end