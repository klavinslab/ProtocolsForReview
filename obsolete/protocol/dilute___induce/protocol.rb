# By: Eriberto Lopez
# elopez3@uw.edu
# 051319

needs "High Throughput Culturing/HighThroughputHelper"

class Protocol
  include HighThroughputHelper
  
  #DEF
  INPUT = "Culture Plate"
  OUTPUT = "Experimental Plate"
  DILUTION = "Dilution"
  OUTGROWTH = "Outgrowth (hr)"
  OPTIONS = "Option(s)"

  # Access class variables via Protocol.your_class_method
  @@materials_list = []
  def self.materials_list; @@materials_list; end

  def main
    operations.retrieve.make
    clean_up_arr = []
    operations.each do |op|
      dilution_factor = get_dilution_factor(op: op, fv_str: DILUTION)
      output_diluted_plates = op.output_array(OUTPUT).collections
      op = (debug ? Operation.find(194403) : op)
      log_info "op", op.operation_type.name
      op.input_array(INPUT).collections.each_with_index do |in_collection, idx|
        out_collection = output_diluted_plates[idx]
        raise "Not enough output plates have been planned please add an output field value to this operation: Plan #{op.plan.id} Operation #{op.id}." if out_collection.nil?
        
        # Tranfer culture information and record PartProvenance
        part_associations_matrix = stamp_transfer(from_collection: in_collection, to_collection: out_collection, process_name: "Dilution")
        
        # Account and gather materials for the output collection
        media_hash   = get_component_volume_hash(matrix: part_associations_matrix, component_type: "Media")
        inducer_hash = get_component_volume_hash(matrix: part_associations_matrix, component_type: "Inducer(s)")
        media_items   = Item.find(media_hash.keys.map {|id| id.to_i }); inducer_items = Item.find(inducer_hash.keys.map {|id| id.to_i })
        
        take_items = [media_items, inducer_items].flatten!
        
        gather_materials(empty_containers: output_diluted_plates, new_materials: ['Multichannel Pipette', 'Media Reservoir'], take_items: take_items)
        
        transfer_vol_matrix = get_transfer_volume_matrix(collection: in_collection, part_associations_matrix: part_associations_matrix, dilution_factor: dilution_factor)
        
        pre_fill_collection(out_collection: out_collection, media_hash: media_hash, part_associations_matrix: part_associations_matrix, transfer_vol_matrix: transfer_vol_matrix)
        
        induce_collection(out_collection: out_collection, inducer_hash: inducer_hash, part_associations_matrix: part_associations_matrix) unless inducer_hash.empty?
        
        transfer_and_dilute_cultures(in_collection: in_collection, out_collection: out_collection, transfer_vol_matrix: transfer_vol_matrix)
        
        # Delete input collection and move output collection to incubator
        incubator = in_collection.location
        out_collection.location = incubator
        out_collection.save()
        in_collection.mark_as_deleted
      end
      
      clean_up(item_arr: clean_up_arr)
      operations.store
    end
  end #main
  
  def pre_fill_collection(out_collection:, media_hash:, part_associations_matrix:, transfer_vol_matrix:)
    show do 
      title "Pre-fill #{out_collection.object_type.name} #{out_collection} with Media"
      separator
      note "You will need the following amount of media:"
      media_hash.each {|media, volume| check "<b>#{(volume/1000).round(2)}#{MILLILITERS}</b> of <b>#{media}</b>"}
      note "Follow the table below to prefill #{out_collection.id} with the appropriate type of media and volume:"
      table highlight_alpha_non_empty(out_collection) {|r, c|
        media_component = part_associations_matrix[r][c].fetch("Media").values.first
        m_vol = media_component.fetch(:working_volume)
        m_vol[:qty] = m_vol[:qty] - transfer_vol_matrix[r][c]
        "#{media_component.fetch(:item_id)}\n#{format_collection_display_str(m_vol)}" 
      }
    end
  end
  
  def induce_collection(out_collection:, inducer_hash:, part_associations_matrix:)
    show do 
      title "Induce #{out_collection.object_type.name} #{out_collection}"
      separator
      note "You will need the following"
      inducer_hash.each {|inducer, volume| check "<b>#{(volume).round(2)}#{MICROLITERS}</b> of <b>#{inducer}</b>"}
      note "Follow the table below to induce the cultures in #{out_collection.id} with the appropriate type of inducer and volume:"
      table highlight_alpha_non_empty(out_collection) {|r, c|
        inducer_component = part_associations_matrix[r][c].fetch("Inducer(s)", {}) # There may be conditions with no inducer
        attributes = inducer_component.empty? ? inducer_component : inducer_component.values.first
        "#{attributes.fetch(:item_id, "None")}\n#{format_collection_display_str(attributes.fetch(:working_volume, ''))}" 
      }
    end
  end

  def transfer_and_dilute_cultures(in_collection:, out_collection:, transfer_vol_matrix:)
    show do 
      title "Transfer Cultures from #{in_collection} to #{out_collection}"
      separator
      note "Transfer cultures:"
      bullet "<b>From #{in_collection.object_type.name} #{in_collection}</b>"
      bullet "<b>To #{out_collection.object_type.name} #{out_collection}</b>"
      note "Follow the table to transfer the appropriate volume:"
      table highlight_alpha_non_empty(out_collection) {|r, c| "#{transfer_vol_matrix[r][c]}#{MICROLITERS}"}
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
    log_info 'from_associations_map', from_associations_map
    
    # Remove previous source data from each part
    from_associations_map.reject! {|k| k != 'part_data'} # Retain only the part_data, so that global associations do not get copied over
    log_info 'from_associations_map part_data', from_associations_map
    
    from_associations_map.fetch('part_data').map! {|row| row.map! {|part| part.key?("source") ? part.reject! {|k| k == "source" } : part } }
    from_associations_map.fetch('part_data').map! {|row| row.map! {|part| part.key?("destination") ? part.reject! {|k| k == "destination" } : part } }
    log_info 'from_associations_map part_data with out source and destination', from_associations_map
    
    # Set edited map to the destination collection_associations
    to_collection_associations.instance_variable_set(:@map, from_associations_map)
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
            destination.first.merge({additional_relation_data: { process: process_name }}) unless process_name.nil?
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
  
  def format_collection_display_str(value)
    if value.is_a? Hash
      return "#{value[:qty]}#{value[:units]}"
    elsif value.is_a? String
      return value
    else
      raise "This #{value.class} can not be formatted for collection display"
    end
  end

end #Class
