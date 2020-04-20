needs "Standard Libs/AssociationManagement"
needs "Tissue Culture Libs/CollectionDisplay"
needs "High Throughput Culturing/ExperimentInitializer"

# HIDDEN INPUTS!
# - media
# - antibiotics

# HIDDEN OUTPUTS!
# - antibiotic media for Recover step (next operation)
# - IF pre-make media option THEN
#       - enough antibiotic media for full induction experiment

class Protocol
  include AssociationManagement
  include PartProvenance
  include ExperimentInitializer
  include CollectionDisplay
  
  # Antibiotic Parameters
  STOCK_KAN_CONC = 10#mg/mL
  FINAL_KAN_CONC = "Kanamycin Concentration (µg/mL)"
  STOCK_CHLOR_CONC = 25#mg/mL
  FINAL_CHLOR_CONC = "Chloramphenicol Concentration (µg/mL)"
  
  def main

    if operations.size != 1
      raise "Manager Error: this protocol only accepts batches of single operations, retry as singleton"
    end
    op = operations.first
    
    operations.retrieve.make
    
    experimental_plates = op.output_array("Overnight Experimental Prep Plate").map { |fv| fv.collection }
    
    # dummy_op = Operation.find()
    
    # generate condition list as list of hashes using inputs
    condition_list = op.input_array("Culture Condition").map do |fv|
      # these operations have already been checked for validity in precondition
      definition_op = FieldValue.find(fv.wires_as_dest.first.from_id).operation
      
      # extract condition definition
      ovn_antibiotic  = definition_op.input("Overnight Antibiotic").val
      exp_antibiotic  = definition_op.input("Experimental Antibiotic").val
      media_type      = definition_op.input("Type of Media").val
      inducers        = definition_op.input("Inducer(s) as  {\"name\": mM_concentration}").val
      control_tag     = definition_op.input("Control Tag").val
      target_sample   = definition_op.input("Target Sample").item
      # input json turns keys to symbols, we will turn them back into strings for consistency
      inducers_string_keys = {}
      inducers.each do |k, v|
        inducers_string_keys[k.to_s] = v
      end
      
      condition_replicates = []
      definition_op.input("Replicates").val.to_i.times do |rep|
          # each element of conditions is a hash representing the full definition of a well in the exp plate 
          condition_replicates << {
            target_sample:  target_sample,
            ovn_antibiotic: ovn_antibiotic,
            exp_antibiotic: exp_antibiotic,
            media_type:     media_type,
            inducers:       inducers_string_keys,
            control_tag:    control_tag,
          } #elements of condition list, mapped from inputs
      end
      condition_replicates
    end
    
    condition_list.flatten!
    
    # Sort conditions into Array of 96w Matricies, each matrix element has a condition definition hash
    # Matricies correspond to output plates
    scheme = generate_plate_scheme(condition_list)
    
    # Bookkeeping and calculations
    total_media_hash = Hash.new(0)
    experimental_plates.each_with_index do |out_plate, idx|
      # Use scheme to load up output plates with correct parts and part data associations
      condition_layout_mat = scheme[idx]
      
      item_mat             = condition_layout_mat.map { |row| row.map { |col| col[:target_sample] if col }}           # Matrix<Item>
      sample_mat           = condition_layout_mat.map { |row| row.map { |col| col[:target_sample].sample.id if col }} # Matrix<SampleId>
      ovn_antibiotic_mat   = condition_layout_mat.map { |row| row.map { |col| col[:ovn_antibiotic] if col }}          # Matrix<antibiotic name>
      exp_antibiotic_mat   = condition_layout_mat.map { |row| row.map { |col| col[:exp_antibiotic] if col }}          # Matrix<antibiotic name>
      media_type_mat       = condition_layout_mat.map { |row| row.map { |col| col[:media_type] if col }}              # Matrix<media name>
      inducer_mat          = condition_layout_mat.map { |row| row.map { |col| col[:inducers] if col }}                # Matrix<Hash<inducer name, inducer conc>>
      ctag_mat             = condition_layout_mat.map { |row| row.map { |col| col[:control_tag] if col }}             # Matrix<control type name>
      
      # create all parts for output plate
      out_plate.associate_matrix(sample_mat)
      
      # add associations to plate parts
      out_plate.set_data_matrix("Overnight Antibiotic", ovn_antibiotic_mat)
      out_plate.set_data_matrix("Experimental Antibiotic", exp_antibiotic_mat)
      out_plate.set_data_matrix("Type of Media", media_type_mat)
      out_plate.set_data_matrix("Inducers", inducer_mat)
      out_plate.set_data_matrix("Control Tag", ctag_mat)
      
      # add provenance associations to plate parts
      record_experimental_plate_provenance(item_mat, out_plate)
      
      # decide whether to prepare all the media needed for a full nc workflow, or only the media needed
      # to make an experiment ready glycerol stock plate
      if op.input("Prepare Experimental Media now?").val == "yes"
        calculate_total_media(ovn_antibiotic_mat, exp_antibiotic_mat, media_type_mat, total_media_hash, (1000 + 200 + 200 + 3000))
        out_plate.associate("prepare_media_cookie", "yes")
      else
        calculate_total_media(ovn_antibiotic_mat, exp_antibiotic_mat, media_type_mat, total_media_hash, 1000)
      end
    end
    
    # make whatever media is needed
    make_media_instructions(total_media_hash, op)
    
    # instruct technician to fill plate with media and transfer samples to media
    experimental_plates.each_with_index do |out_plate, idx|
      # Use scheme to load up output plates with correct parts and part data associations (pretty ugly that we are doing this extraction twice over)
      condition_layout_mat = scheme[idx]
      item_mat             = condition_layout_mat.map { |row| row.map { |col| col[:target_sample] if col }}           # Matrix<Item>
      ovn_antibiotic_mat   = condition_layout_mat.map { |row| row.map { |col| col[:ovn_antibiotic] if col }}          # Matrix<antibiotic name>
      media_type_mat       = condition_layout_mat.map { |row| row.map { |col| col[:media_type] if col }}              # Matrix<media name>

      # fill plate wells with correct type of media
      fill_plate_with_media(out_plate, ovn_antibiotic_mat, media_type_mat)
      
      # direct technician to begin transfer samples and media into output plate, preparing for overnight
      sample_transfer(out_plate, item_mat)
    end
    
    # begin incubation for all plates
    begin_incubation(experimental_plates, op.input("Temperature (°C)").val.to_i)
    
    operations.store(interactive: false)

    {}

  end
  
  # On the output experimental plate, record the sources for each part
  # as the input item that corresponds to it as defined in item layout.
  #
  # @param out_plate [Item]  output collection, destination of transfered samples
  #                 for this protocol
  # @param item_layout [Array<Array<Item>>]  input items, arranged in a matrix
  #                 as they will appear in the output collection
  def record_experimental_plate_provenance(item_layout, out_plate)
    plate_associations = AssociationMap.new(out_plate)
    item_layout.each_with_index do |row, r_idx|
      row.each_with_index do |from_item, c_idx|
        if from_item #note every slot in matrix has a from item
            # not associating data to 'from items' - it is slow, and it will be implicit anyway
            add_provenance({
                from: from_item, 
                from_map: nil,
                to: out_plate, 
                to_coord: [r_idx, c_idx], 
                to_map: plate_associations
            })
        end
      end
    end
    plate_associations.save
  end
  
  def sample_transfer(out_plate, item_mat)
    #create rclist by item for this plate
    item_to_coordlist = Hash.new { |h, k| h[k] = [] }
    item_mat.each_with_index do |row, r_idx|
      row.each_with_index do |col, c_idx|
        if col
            item_to_coordlist[col] << [r_idx, c_idx]
        end
      end
    end
    
    # transfer scraping into wells
    item_to_coordlist.each do |item, coordlist|
      show do
        title "Filling 96 Deep Well <b>#{out_plate.id} with Samples</b>"
        separator
        note "Use a pipette tip to scrape out some of #{item} into each of the highlighted wells on #{out_plate}"
        table highlight_alpha_rc(out_plate, coordlist) {|r,c| item.id }
      end
    end
  end
  
  def begin_incubation(experimental_plates, temp)
    experimental_plates.each do |plate|
      plate.move "#{temp} C Shaker incubator"
    end
    
    show do
      title "Incubating Plates"
      note "Move #{experimental_plates.to_sentence} to the #{temp}°C incubator and place on shaker - 800rpm."
    end
  end
  
  # Direct tech to aliquot and create antibiotic media
  def make_media_instructions(total_media_hash, op)
    total_media_hash.each do |media, quant|
      kan_stk_vol = 0
      chlor_stk_vol = 0
      (media.include? 'Kan') ? kan_stk_vol = (op.input(FINAL_KAN_CONC).val.to_f * (quant))/(STOCK_KAN_CONC*1000) : 0
      (media.include? 'Chlor') ? chlor_stk_vol = (op.input(FINAL_CHLOR_CONC).val.to_f * (quant))/(STOCK_CHLOR_CONC*1000) : 0
      show do
        if kan_stk_vol == 0 && chlor_stk_vol == 0
          title "Aliquoting #{media} Media"
          separator
          check "In the appropriate container aliquot: <b>#{quant.to_f/1000}mL</b> of <b>#{media} Media</b>"
          check "Label, date, & initial the container: <b>#{media} Media</b>"
        else
          title "Creating Antibiotic Media: #{media}"
          separator
          check "In the appropriate container aliquot: <b>#{quant.to_f/1000}mL</b> of <b>#{media.split(' ').first} Media</b>"
          check "To that aliquot, add <b>#{kan_stk_vol}µl</b> of <b>Kanamycin Stock (#{STOCK_KAN_CONC}mg/mL)</b>" if (kan_stk_vol > 0)
          check "To that aliquot, add <b>#{chlor_stk_vol}µl</b> of <b>Chloramphenicol Stock (#{STOCK_CHLOR_CONC}mg/mL)</b>" if (chlor_stk_vol > 0)
          check "Label, date, & initial the container: <b>#{media}</b>"
        end
      end
    end
  end
  
end
