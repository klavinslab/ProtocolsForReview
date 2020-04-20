# Transformation confirmation protocol, determines if a transformed well is isogenic

class Protocol
  
  def main

    operations.retrieve(interactive: false)
    
    # gather Hydra data by well
    operations.each do |op|
      num_hydra = get_hydra_count(op.input("Hydra").item)
      cell_counts = get_cell_counts(op.input("Hydra").item, num_hydra)
      upload_ids = get_image(op.input("Hydra").item)
      total_cells = 0
      transgenic_hydra = 0
      cell_counts.each { |cell| total_cells += cell
                        (cell > 0) ? transgenic_hydra+=1: transgenic_hydra}

      # associate data
    #   op.input("Hydra").item.associate(:avg_cells, (transgenic_hydra>0) ? total_cells/transgenic_hydra : 0)
    #   op.input("Hydra").item.associate(:num_hydra, num_hydra)
    #   op.input("Hydra").item.associate(:cell_counts, cell_counts)
    #   op.input("Hydra").item.associate(:transgenic_cells, total_cells)
    #   if upload_ids
    #     upload = Upload.find_by_id(upload_ids.first[:id])
    #     op.input("Hydra").item.associate :upload, "image for well #{op.input("Hydra").item.id}", upload
    #   end
    
      # associate data
      dataset = {}
      dataset[:avg_cells] = (transgenic_hydra>0) ? total_cells/transgenic_hydra : 0
      dataset[:num_hydra] = num_hydra
      dataset[:cell_counts] = cell_counts
      dataset[:transgenic_cells] = total_cells
      if upload_ids
        upload = Upload.find_by_id(upload_ids.first[:id])
        dataset[:upload] = upload
      end
      
      timekey = "Verification " + Time.now.strftime("%d/%m/%Y %H:%M")
      op.input("Hydra").item.associate(timekey, dataset)
      
      # determine if the well should be verified
      isogenic = is_isogenic(op.input("Hydra").item)
      op.input("Hydra").item.associate(:is_isogenic, isogenic)
    end
    
    # successful operations
    trans_ops = operations.select { |op| op.input("Hydra").item.get(:is_isogenic) == 'yes' }
    trans_ops.make
    
    return {}
    
  end
  
  ######~~~~~~~~~~~Operations~~~~~~~~~~~######
  # Get the total number of hydra
  def get_hydra_count(op_num)
    data = show do
      title "Input the total number of transgenic hydra in well #{op_num}"
      get "number", var: :hydra_count, label: "Total number of hydra", default: 0
    end
    return data[:hydra_count]
  end
  
  # Gets the array of cell counts per hydra
  def get_cell_counts(op_num, num_hydra)
    data = show do
      title "Cell counts for each hydra in well #{op_num}"
      
      num_hydra.times do |idx|
        get "number", var: "hydra#{idx}", label: "Cell count for hydra #{idx + 1}", default: debug ? 0 : nil
      end
    end
    
    return data.select { |k, v| k.to_s.include? "hydra" }.values
  end
  
  # Gets the file for an individual hydra imaging
  def get_image(op_num)
    data = show do
      title "Upload the imaging file for this well"
      upload var: :my_uploads
    end
    return data[:my_uploads]
  end
  
  # determines if the given well is isogenic
  def is_isogenic(op_num)
    data = show do
      title "Are the hydra in well #{op_num} isogenic?"
      select [ "yes", "no" ], var: "isogenic", label: "isogenic line?", default: 1
    end
    return data[:isogenic]
  end
end
