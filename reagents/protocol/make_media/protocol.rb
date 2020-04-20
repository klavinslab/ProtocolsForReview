# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!
needs "Standard Libs/UploadHelper"
needs "Standard Libs/Debug"
class Protocol
    include Debug
    include UploadHelper
  # the uploaded file must have this name
  FILENAME = "media_protocols.csv"
  
  # Hash containing the physical container type for the container
  CONTAINERS = {"800 mL Liquid" => "1 L bottle", "800 mL Agar" => "1 L bottle", "400 mL Liquid" => "500 mL bottle", "400 mL Agar" => "500 mL bottle",
                "200 mL Liquid" => "250 mL bottle", "200 mL Agar" => "250 mL bottle", "200 mL Reagent Bottle" => "250 mL bottle"
  }

  def main
    operations.retrieve.make
    
    files = Upload.where(upload_file_name: FILENAME)
    files_sorted = files.sort {|f1, f2| f1.id <=> f2.id}
    
    # Finding the current file that contains the right sample
    current_file = files_sorted.last #Upload.find(11154)#files_sorted.last
    log_info 'current_file', current_file
    # Reading in the spreadsheet matrix from the current file
    data = read_url(current_file)
    
    # Remove nils from the data array.
    remove_data_nils data
    
    if(data.empty?)
      show { note "no data, returning..." } 
      return
    end
    
    # Now I need to group operations by the output sample, so I can easily batch them.
    # Creating a hash:
    #   Key: Sample, Value: Grouped operations of that sample
    grouped_operations_hash = Hash.new{|hsh, key| hsh[key] = []};
    operations.each do |op|
      grouped_operations_hash[op.output("Media/Reagents").sample.name].push op
    end

    grouped_operations_hash.each do |key, value|
      grouped_operations = value
      input_name = key

      if debug
        key = "50x TAE"
      end
      
      # find sample, instruction, materials row.
      current_name = "sample: " + key
      sample_name = data.select{|x| x[0] == current_name}[0] # "sample: LB Liquid Media"
      
      if sample_name.nil?
        raise "This sample isn't in #{FILENAME}"
      end
      
      sample_name_index = data.index(sample_name)
      instructions_array = data[sample_name_index + 1]
      materials_array = data[sample_name_index + 2]
      gather_materials materials_array, grouped_operations
      show_instructions instructions_array, grouped_operations
      
    end
  
    operations.store

    {}

  end
 
  # This method calculates how many of each material is needed, and instructs
  # the technician to gather those materials.
  def gather_materials materials, grouped_operations
    show do
      # Grabbing materials
      title "Retrieve the following item(s)"
      
      materials.each do |mat|
        index = mat.index("#");
        newmat = mat
        if(!index.nil?)
          newmat = mat.slice(0, index) + "#{grouped_operations.length}"
        end
        
        # Find the item id of this material if it exists.
        # If it exists, print the name and id. if not, print name
        newmat_sample = Sample.where(name: newmat).first
        if newmat_sample
          queried_items = Item.where(sample_id: newmat_sample.id)
          queried_items_sorted = queried_items.sort {|i1, i2| i2.id <=> i1.id}
          newmat_id = queried_items_sorted.first.id
          check newmat + " (" + newmat_id + ")"
        else
          check newmat
        end
  
      end

      output_type = ""
      
      # Counts how many of each kind of bottle we want.
      containers = {}
      grouped_operations.each do |op|
          # raise op.output("Media/Reagents").inspect
          output_type = ObjectType.find(op.output("Media/Reagents").item.object_type_id).name
          if containers.key? output_type
            containers[output_type] += 1
          else
            containers[output_type] = 1
          end
      end
      
      containers.each do |container, quantity|
        check "Grab #{quantity} of #{CONTAINERS[output_type]}"
      end
    end
  end

  # This method shows instructions for all operations of 
  # the same output sample in order to create the media
  def show_instructions instructions, ops
    item_ids = []
    ops.each do |op|
      item_ids.push op.output("Media/Reagents").item.id.to_s
    end

    # Delimitter is the cell with 'title:' in it. This breaks the instructions array into
    # subarrays where each array starts with the title cell and the instruction cells that correspond
    # to that title.
    instructions.slice_before{|elt| elt.split(" ")[0] == "title:"}.each do |chunk|
      
      # this part breaks the title cell into an array, where the first element is the word "title:"
      # in order to cleanly get the actual title of this slide.
      title_array = chunk[0].partition(":")
      show do
        title "#{title_array[2]}" # the 2nd index will contain the actual title.
        
        # Loop through the cells that contain instructions, skipping the 0'th element, which is the title.
        chunk[1..-1].each do |instruction|
          id_string = item_ids.to_s
          check "#{instruction.gsub('Aq item id', id_string)}"
        end
      end
    end
  
  end
  
  # This creats a hash out of the materials row in the spredsheet. This is because
  # the materials row contains pairs of 2, so hashing is easier for access and readability.
  # INPUTS: materials_array
  # OUTPUTS: new_hash
  def make_materials_hash materials_array
    material_name_idx = 0;
    new_hash = {};
    for counter in 0...materials_array.length/2
      new_hash[materials_array[material_name_idx]] = materials_array[material_name_idx+1]
      material_name_idx += 2
    end
    new_hash #return
  end
  
  # This function removes nil cells from the data matrix.
  # INPUTS: data
  def remove_data_nils data
    data.each_index do |i|
      j = 0
      loop do
        if j >= data[i].length
          break
        end
        if data[i][j].nil?
          data[i].delete_at(j)
        end
        
        if !data[i][j].nil?
          j += 1
        end
      end
    end
  end

end