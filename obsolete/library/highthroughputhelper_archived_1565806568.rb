# By: Eriberto Lopez
# elopez3@gmail.com
# Updated: 071519

needs "Tissue Culture Libs/CollectionDisplay"
needs "Standard Libs/Units"
needs "Plate Reader/PlateReaderHelper"

module HTCExperimentalDesign
  include Units
  include AssociationManagement
  
  def associate_controls_to_collection(cultures:, collection:)
    collection_associations = AssociationMap.new(collection)
    empty_wells = collection.get_empty
    column_samples = cultures.map {|column| Sample.find_by_name(column.first.fetch("Strain").keys.first) }
    cultures.each_with_index do |replicates, idx| 
      replicates.each do |culture| 
        r, c = empty_wells.shift()
        collection.set(r, c, column_samples[idx])
        collection.save()
        culture.keys.each do |key|
          collection_associations.putrc(row=r, column=c, key=key, data=culture[key])
        end
      end
    end
    collection_associations.save()
  end
  
  def associate_cultures_to_collection(cultures:, object_type:)
    # Now each one of the matricies is ready to be associated with a collection
    uniq_strains = {}
    new_collections = []
    format_to_collection_type(cultures: cultures, object_type: object_type).each_with_index do |formatted_matrix, idx|
      collection = new_collection object_type.name
      sname_matrix = formatted_matrix.map {|culture| (culture == EMPTY) ? culture : culture.fetch("Strain").keys.first }
      sname_matrix.to_a.flatten.uniq.reject {|sname| sname == EMPTY}.each {|sname| uniq_strains[sname] = Sample.find_by_name(sname).id unless uniq_strains.keys.include? sname} 
      sid_matrix = sname_matrix.map {|sname| uniq_strains[sname]}
      collection.matrix = sid_matrix.to_a; collection.save()
      collection_associations = AssociationMap.new(collection)
      formatted_matrix.to_a.each_with_index do |row, r_i|
        row.each_with_index do |culture, c_i|
          if culture != EMPTY
            culture.keys.each do |key|
              collection_associations.putrc(row=r_i, column=c_i, key, data=culture[key])
            end
          else
            EMPTY
          end
        end
      end
      collection_associations.save()
      new_collections.push(collection)
    end
    return new_collections
  end
  
  def format_slice(slice, columns)
    slice_width = slice.map {|s| s.length}.uniq.first
    empty_slice = slice_width.times.map {|i| EMPTY }
    while slice.length != columns do
      slice.push(empty_slice)
    end
    return slice
  end
  
  def format_cultures_to_object_type(sorted_cultures:, object_type:)
    matrix_arr = sorted_cultures.each_slice(object_type.columns).map {|slice|
      slice = format_slice(slice, object_type.columns)
      Matrix.columns(slice) 
    }
    # After the columns/reps have been sliced I want to prevent replicates from getting placed on different collections
    max_rows = object_type.rows
    stack_arr_idx = 0
    matricies_to_stack = Array.new(15) {[]} # TODO: 15 is arbitray, essentially max amount of plates per op
    
    matrix_arr.map do |m| 
      max_rows -= m.row_count
      if max_rows > 0
        matricies_to_stack[stack_arr_idx].push(m)
      else
        stack_arr_idx += 1
        matricies_to_stack[stack_arr_idx].push(m)
        max_rows = object_type.rows - m.row_count
      end
    end
    formatted_matricies = matricies_to_stack.select {|i| !i.empty? }.map {|matrix_arr| vstack_matrix_array(matrix_arr: matrix_arr) }
    return formatted_matricies
  end
  
  def format_to_collection_type(cultures:, object_type:, columnwise: false)
    sorted_cultures     = sort_culture_composition_objs(cultures: cultures) # sorts CultureComposition replicate arrays by strain and then condition
    formatted_matricies = format_cultures_to_object_type(sorted_cultures: sorted_cultures, object_type: object_type)
    return formatted_matricies
  end  
 
 # Sort replicate culture arrays by strain then by total moles of final concentration inducer 
  def sort_culture_composition_objs(cultures:)
    sorted_cultures = []
    groupby_strain_name = cultures.group_by {|rep_arr| rep_arr.first.fetch('Strain').keys.first }
    groupby_strain_name.map {|sname, rep_arrays|
      rep_arrays.sort! {|arr_a, arr_b| get_comparison(arr_a.first) <=> get_comparison(arr_b.first) }.each {|rep_array| sorted_cultures.push(rep_array) }
    }
    return sorted_cultures
  end
  
  def get_comparison(args)
    comparison = []
    if args.fetch('Inducer(s)', nil).nil?
      comparison.push(0)
    else
      args.fetch('Inducer(s)').keys.each do |inducer_name| fconc_obj = args.fetch('Inducer(s)')[inducer_name][:final_concentration]
        comparison.push( (CultureComponent.unit_conversion_hash[fconc_obj[:units]]*fconc_obj[:qty]).to_f )
      end
    end
    return comparison
  end
  
  def vstack_matrix_array(matrix_arr:)
    stacked_mat = nil
    matrix_arr.each {|m| stacked_mat.nil? ? stacked_mat = m : stacked_mat = stacked_mat.vstack(m) }
    return stacked_mat
  end
  
end # module HTCExperimentalDesign


module HighThroughputHelper
  include CollectionDisplay
  include HTCExperimentalDesign
  
  SATURATION_CULT_VOL = 300#ul
  
  def search_part_associations(collection:, data_key:, attribute:)
    part_data_matrix = collection.data_matrix_values(data_key)
    part_data_matrix.map! {|row| row.map! {|part| part.nil? ? part : part.values.first.fetch(attribute) } }
  end
  
  def inoculate_culture_plates(new_output_collections:, inoculation_prep_hash:)
    item_ids = []; media_ids = []
    inoculation_prep_hash.each {|collection_id, item_media_hash| item_media_hash.each {|item_id, media_to_rc_list| item_ids.push(item_id); media_ids.push(media_to_rc_list.keys) } }
    uniq_input_items = Item.find(item_ids.flatten.uniq); uniq_media_items = Item.find(media_ids.flatten.uniq)
    input_item_hash = Hash.new();                        input_media_hash = Hash.new()
    uniq_input_items.each {|item| input_item_hash[item.id] = item }; uniq_media_items.each {|item| input_media_hash[item.id] = item }
    
    gather_materials(empty_containers: new_output_collections, transfer_required: false, new_materials: ["P1000 Multichannel Pipette", "Media Reservoir", "Aera Breathable Seals"], take_items: uniq_media_items)
    
    uniq_input_items.group_by {|item| item.object_type.name }.each do |ot_name, items|
      case ot_name
      when 'Yeast Glycerol Stock', 'E coli Glycerol Stock'
        tubeNum_hash = prep_glycerol_stock_inoculants(inoculation_prep_hash: inoculation_prep_hash, input_item_hash: input_item_hash, input_media_hash: input_media_hash)
        inoculate_glycerol_stock_inoculates(inoculation_prep_hash: inoculation_prep_hash, tubeNum_hash: tubeNum_hash)
      when 'Yeast Plate', 'E coli Plate of Plasmid'
        # Grab plates
        take items, interactive: true
        new_output_collections.each do |collection|
          inoculate_colonies_from_agar_plates(collection: collection, input_media_hash: input_media_hash, inoculation_prep_hash: inoculation_prep_hash)
          seal_plate(collection_id=collection.id)
        end
      when '96 Well PCR Plate' # Yeast Glycerol stock plate
        #
      else
        raise "This object type  #{ot_name} is not compatable to inoculate culture plate"
      end
    end
  end
  
  def seal_plate(collection_id)
    show do 
      title "Seal Plate for Incubation"
      separator
      check "Grab a new <b>Aera Breathable Seal</b>"
      note "Label the seal with "
      bullet "Plate #{collection_id}"
      bullet "Today's date"
      bullet "Time of inoculation (ie: 3:00pm)"
      bullet "Your initials"
    end
  end
  
  def inoculate_colonies_from_agar_plates(collection:, input_media_hash:, inoculation_prep_hash:)
    media_part_matrix = search_part_associations(collection: collection, data_key: 'Media', attribute: 'item_id'); media_vol_hash = Hash.new(0)
    media_part_matrix.each {|row| row.reject {|i| i.nil? }.each {|media_id| media_vol_hash[media_id] += 1 } }
    show do
      title "Fill #{collection.object_type.name} #{collection.id} with Media"
      separator
      media_vol_hash.each do |media_id, count|
        media_vol_ml = (HighThroughputHelper.add_extra_vol(int: SATURATION_CULT_VOL*count)/1000.0).round(3)
        check "You will need <b>#{media_vol_ml}#{MILLILITERS}</b> of <b>#{input_media_hash[media_id].sample.name}</b> media"  
      end
      note "In the table, the item id of the media type is followed by the volume to dispense."
      note "Follow the table below to fill with the appropiate media type & volume:"
      table highlight_alpha_non_empty(collection) {|r,c| "#{media_part_matrix[r][c]}\n#{SATURATION_CULT_VOL}#{MICROLITERS}"} 
    end
    inoculation_prep_hash[collection.id].each do |input_item_id, media_to_rc_list|
      media_to_rc_list.each do |media_id, rc_list|
        show do
          title "Inoculate #{collection} with Single Colonies"
          separator
          note "In the table, the item id of the agar plate is displayed. If the same item is used, try to pick a different biological replicate (single colony) for each well."
          note "Follow the table below to inoculate a well with the appropriate item:"
          table highlight_alpha_rc(collection, rc_list){|r,c| "#{input_item_id}"} 
        end
        
      end
    end
  end
  
  def get_inoculation_prep_hash(new_output_collections)
    inoculation_prep_hash = nested_hash_data_structure
    new_output_collections.each do |collection|
      input_items_matrix = search_part_associations(collection: collection, data_key: 'Strain', attribute: 'item_id') 
      media_items_matrix = search_part_associations(collection: collection, data_key: 'Media', attribute: 'item_id')
      input_items_matrix.each_with_index do |row, r_i| 
        row.each_with_index do |input_item_id, c_i|
          if input_item_id.nil?
            next
          else
            media_item_id = media_items_matrix[r_i][c_i]
            if inoculation_prep_hash[collection.id].fetch(input_item_id, nil).nil?
              inoculation_prep_hash[collection.id][input_item_id][media_item_id] = [[r_i, c_i]]
            else
              if inoculation_prep_hash[collection.id][input_item_id].fetch(media_item_id, nil).nil?
                inoculation_prep_hash[collection.id][input_item_id][media_item_id] = [[r_i, c_i]]
              else
                inoculation_prep_hash[collection.id][input_item_id][media_item_id].push([r_i, c_i])
              end
            end
          end
        end
      end
    end
    return inoculation_prep_hash
  end
  
  def inoculate_glycerol_stock_inoculates(inoculation_prep_hash:, tubeNum_hash:)
    out_collections_arr = Collection.find(inoculation_prep_hash.keys)
    inoculation_prep_hash.each do |out_collection_id, inoculation_item_hash|
      collection = out_collections_arr.select {|c| c.id == out_collection_id }.first
      inoculation_item_hash.each do |input_item_id, media_rc_list_hash|
        media_rc_list_hash.each do |media_item_id, rc_list|
          show do
            title "Inoculate #{collection} with Resuspended Inoculants"
            separator
            note "Follow the table below to transfer <b>#{SATURATION_CULT_VOL}#{MICROLITERS}</b> from a resuspended inoculant to the corresponding well."
            bullet "The numbers are the table correspond to the labels on the resuspension tubes."
            table highlight_alpha_rc(collection, rc_list) {|r,c| "#{tubeNum_hash[input_item_id][media_item_id]}"} 
          end
        end
      end
      seal_plate(collection_id=out_collection_id)
    end
  end

  def prep_glycerol_stock_inoculants(inoculation_prep_hash:, input_item_hash:, input_media_hash:)
    tube_num = 1        
    tubeNum_hash = nested_hash_data_structure
    resuspension_hash = nested_hash_data_structure
    inoculation_prep_hash.each do |out_collection_id, inoculation_item_hash|
      inoculation_item_hash.each do |input_item_id, media_rc_list_hash|
        media_rc_list_hash.each do |media_item_id, rc_list|
          media_vol_ml = ((rc_list.length*SATURATION_CULT_VOL*1.1)/1000.0).round(3) # mL w/ 10%
          if (resuspension_hash[input_item_id][media_item_id]).instance_of? Hash
            resuspension_hash[input_item_id][media_item_id] = media_vol_ml 
          else 
            resuspension_hash[input_item_id][media_item_id] += media_vol_ml
            resuspension_hash[input_item_id][media_item_id].round(3)
          end
          if tubeNum_hash[input_item_id][media_item_id].instance_of? Hash
            tubeNum_hash[input_item_id][media_item_id] = tube_num
            tube_num += 1
          end
        end
      end
    end
    display_table = [['Tube Label #',"Media Type", "Media Vol (#{MILLILITERS})", 'Input Item ID','Item Location']] # Headers of table
    resuspension_hash.each do |input_item_id, media_volume_hash|
      media_volume_hash.each do |media_item_id, media_vol_ml|
        dtable_row = make_checkable(value: tubeNum_hash[input_item_id][media_item_id]).concat([input_media_hash[media_item_id].sample.name]).concat(
          make_checkable(value: media_vol_ml)).concat([input_item_id]).concat(make_checkable(value: input_item_hash[input_item_id].location)
          )
        display_table.push(dtable_row)
      end
    end
    show do
      title "Resuspend Inoculants"
      separator
      note "Use the <b>Tube Label #</b> column to determine how many inoculants to prepare."
      note "Use the <b>Media Vol (#{MILLILITERS})</b> column to determine the appropriate sized tube."
      check "Gather tubes and label with tube label number"
      check "Next, fill tubes with the appropriate amount of media."
      check "Finally, retrieve glycerol stock, take a sample using aseptic technique, then resuspend in pre-filled tube."
      note "Follow the table below to resuspend the input item into the appropriate media."
      table display_table
    end
    return tubeNum_hash
  end
  
  def make_checkable(value:)
    if value.is_a? Array
      return value.map {|i| { content: i, check: true } }
    else
      return [value].map {|i| { content: i, check: true } }
    end
  end

  def copy_sample_matrix(from_collection:, to_collection:)
    sample_matrix = from_collection.matrix
    to_collection.matrix = sample_matrix
    to_collection.save()
  end
  
  def transfer_part_associations(from_collection:, to_collection:)
    copy_sample_matrix(from_collection: from_collection, to_collection: to_collection)
    from_collection_associations = AssociationMap.new(from_collection)
    to_collection_associations   = AssociationMap.new(to_collection)
    from_associations_map = from_collection_associations.instance_variable_get(:@map)
    # Remove previous source data from each part, retain only value where the key is part_data
    from_associations_map.select! {|key| key == 'part_data' } # Retain only the part_data, so that global associations do not get copied over
    from_associations_map.fetch('part_data').map! {|row| row.map! {|part| part.key?("source") ? part.reject! {|k| k == "source" } : part } }
    from_associations_map.fetch('part_data').map! {|row| row.map! {|part| part.key?("destination") ? part.reject! {|k| k == "destination" } : part } }
    # Set edited map to the destination collection_associations
    to_collection_associations.instance_variable_set(:@map, from_associations_map) # setting it to the associations @map will push the part_data onto each part item automatically
    to_collection_associations.save()
    return from_associations_map
  end    
    
  def part_provenance_transfer(from_collection:, to_collection:, process_name:)
    to_collection_part_matrix = to_collection.part_matrix
    from_collection.part_matrix.each_with_index do |row, r_i|
      row.each_with_index do |from_part, c_i|
        if from_part
          to_part = to_collection_part_matrix[r_i][c_i]
          # Create source and destination objs
          source_id = from_part.id; source = [{id: source_id }]
          destination_id = to_part.id; destination = [{id: destination_id }]
          # raise process_name.inspect unless process_name.nil?
          destination.first.merge!({additional_relation_data: { process: process_name }}) unless process_name.nil?
          # Association source and destination
          to_part.associate(key=:source, value=source)
          from_part.associate(key=:destination, value=destination)
        end
      end
    end
  end
  
  def stamp_transfer(from_collection:, to_collection:, process_name: nil)
    from_associations_map = transfer_part_associations(from_collection: from_collection, to_collection: to_collection)
    part_provenance_transfer(from_collection: from_collection, to_collection: to_collection, process_name: process_name)
    return from_associations_map.fetch('part_data')
  end

  def get_component_volume_hash(matrix:, component_type:)
    volume_hash = Hash.new(0)
    matrix.each do |culture_array|
      culture_array.each do |culture|
        component = culture.fetch(component_type, nil)
        if component
          attributes = component.values.first
          item_id = attributes.fetch(:item_id, nil)
          if item_id.nil?
            next
          else
            volume_hash[item_id] += attributes.fetch(:working_volume).fetch(:qty)
          end
        end
      end
    end
    return volume_hash
  end
  
  def get_transfer_volume_matrix(collection:, part_associations_matrix:, dilution_factor:)
      transfer_vol_matrix = Array.new(collection.object_type.rows) { Array.new(collection.object_type.columns) { -1 } }
      c = collection_from(collection)
      c.get_non_empty.each {|r, c| 
        final_culture_vol = part_associations_matrix[r][c].fetch("Culture_Volume")
        transfer_volume = (dilution_factor*final_culture_vol[:qty].to_f).round(3)
        transfer_vol_matrix[r][c] = transfer_volume
      }
      return transfer_vol_matrix
  end
  
  def clean_up(item_arr: [uniq_media_items, uniq_input_items])
    item_arr.flatten.group_by {|i| i.object_type.name }.each {|otname, items| release items, interactive: true }
    show do 
      title "Cleaning Up.."
      separator
      note "Make sure that all materials and equiptment used is put away and cleaned before finishing."
    end
  end
  
  def incubate_plates(output_collections:, growth_temp:)
    incubation_location ="Incubator at #{growth_temp.to_i}#{DEGREES_C}"
    if output_collections.is_a? Array
      output_collections.each {|collection| collection.location = incubation_location }
      release output_collections, interactive: true
    else
      output_collections.location == incubation_location
      release [output_collections], interactive: true
    end
  end

  def get_dilution_factor(op:, fv_str:)
    param_val = get_parameter(op: op, fv_str: fv_str).to_s
    dilution_factor = (param_val == 'None') ? param_val : param_val.chomp('X').to_f
  end
  
  def get_parameter(op:, fv_str:)
    op.input(fv_str).val
  end

  # could extend a module with common class variables needed in protocol writing
  def gather_materials(empty_containers: [], transfer_required: false, new_materials: [], take_items: [])
    new_materials = new_materials.select {|m| !Protocol.materials_list.include? m}
    if !empty_containers.empty? || !new_materials.empty?
      show do
        title "Gather The Following Materials"
        separator
        note "Gather the following and bring them to your bench:"
        empty_containers.each {|c|
          ((c.is_a? Item) || (c.is_a? Collection)) ? (check "#{c.object_type.name} and label as <b>#{c.id}</b>") : (check "#{c}")
        }
        new_materials.each {|m| check "#{m}" }
      end 
    end
    take take_items, interactive: true unless take_items.length <= 0
    Protocol.materials_list.concat(new_materials).concat(empty_containers)
  end
  
  # Allows for multiple key deeply nested hash[:item][:measurement][:day][:hour] = val
  def nested_hash_data_structure
    Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }
  end
  
  def get_uninitialized_output_fv_object_type_id(op)
    AllowableFieldType.find(op.outputs[0].allowable_field_type_id).object_type_id
  end
  
  def get_uninitialized_output_object_type(op)
    oti = get_uninitialized_output_fv_object_type_id(op)
    return ObjectType.find(oti)
  end
    
  def self.add_extra_vol(int:, additional_percent: 0.1)
    return (int+(int*additional_percent)).round(3)
  end
  
end # module HighThroughputHelper

