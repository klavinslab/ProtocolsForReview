needs "Standard Libs/AssociationManagement"

module ExperimentInitializer
    include AssociationManagement

    def generate_plate_scheme(cond_list)
    rows = 8
    cols = 12
    s = cond_list.size
    num_plates = s / 96
    if (s % 96 != 0)
        num_plates += 1
    end

    
    cond_ordered = Array.new(cond_list.size)
    cond_ordered = cond_list.sort { |a, b| 
        [a.fetch(:target_sample).sample.id, 
        a.fetch(:inducers).keys, a.fetch(:inducers).values]  <=> [b.fetch(:target_sample).sample.id, #.sample_id
        b.fetch(:inducers).keys, b.fetch(:inducers).values] }
    
    i = 0
    plates = Array.new(1) #num_plates
    (0...num_plates).each do |plate|
         #curr_plate = Array.new(rows){Array.new(cols)}
         plates[plate] = Array.new(rows){Array.new(cols)}
        (0...rows).each do |r|
            (0...cols).each do |c|
                return plates if i == s #if weve processed the list, return
                plates[plate][r][c]= cond_ordered[i] #the current plate is being filled
                i += 1
            end
        end
    end
    return plates
  end
  
  #ABES HELPERS BELOW 
########################################################################################################################################333
  # methods factored out from original nc protocols and improved

  def fill_plate_with_media(out_collection, antibiotic_mat, media_type_mat)
    medias_to_coordlist = get_media_coordlists(out_collection, antibiotic_mat, media_type_mat)
    count = 0
    medias_to_coordlist.each do |media_type, media_coords_list|
      media_vol = (media_coords_list.length + 2) * 0.2#mL
      show do
        title "Filling 96 Deep Well <b>#{out_collection.id} with Media</b>"
        separator
        if count == 0
          check "Obtain a <b>96 Deep Well plate</b> and label with #<b>#{out_collection.id}</b>"
        end
        check "Aliquot <b>#{media_vol.round(2)}mL</b> of <b>#{media_type}</b> into a clean reservoir."
        note "Follow the table below to fill Deep Well plate with <b>180µl</b> the appropriate media:"
        table highlight_alpha_rc(out_collection, media_coords_list) {|r,c| media_type}
      end
      count += 1
    end
  end
  
  def get_media_coordlists(out_collection, antibiotic_mat, media_type_mat)
    result = Hash.new { |h, k| h[k] = [] }
    out_collection.dimensions[0].times do |r_idx|
      out_collection.dimensions[1].times do |c_idx|
        if media_type_mat[r_idx][c_idx]
          key = ""
          key += media_type_mat[r_idx][c_idx]
          key += " " + antibiotic_mat[r_idx][c_idx] if antibiotic_mat[r_idx][c_idx] != 'none'
          result[key] << [r_idx,c_idx]
        end
      end
    end
    return result
  end
  
  # Determines which types of media, and how much of each will be needed for a full induction experiment.
  # Adds information to the result hash passed in.
  def calculate_total_media(overnight_antibiotic_mat, experimental_antibiotic_mat, media_type_mat, total_media_hash, exp_well_modifier)    
    8.times do |r|
      12.times do |c|
        if media_type_mat[r][c]
          total_media_hash[media_type_mat[r][c] + " " + overnight_antibiotic_mat[r][c]] += 200 if overnight_antibiotic_mat[r][c]
          # NC_R_vol_for_deep_96 + NC_PR_flat_96_3 + NC_PR_flat_96_4 + NC_Lrg_Vol_culture_plates_5h
          total_media_hash[media_type_mat[r][c] + " " + experimental_antibiotic_mat[r][c]] += exp_well_modifier if experimental_antibiotic_mat[r][c]
        end
      end
    end
  end # (1000 + 200 + 200 + 3000) or (1000)
  
  

  
  # Creates a data structure that holds the amounts of each media_type/inducer combination
  # to be collected for use in making 
  def tally_induced_media_variants(inducer_mat, experimental_antibiotic_mat, media_type_mat)
    media_hash = Hash.new {|h, k| h[k] = Hash.new {|h, k| h[k] = Hash.new(0)}} # media to (inducer to (conc to count))
    inducer_mat.each_with_index do |row, r_idx|
      row.each_with_index do |col, c_idx|
        if col
          media_type_no_inducer = media_type_mat[r_idx][c_idx] + " " + experimental_antibiotic_mat[r_idx][c_idx]
          inducer_hash = col
          inducer_hash.each do |inducer, conc|
            media_hash[media_type_no_inducer][inducer][conc] += 1
          end
        end
      end
    end
    return media_hash 
  end
  
  # Creates a data structure that holds the amounts of each media_type/inducer combination
  # that will be made for this experiment in terms of how they combine with each other
  #
  # (hard to explain, these two methods and the places where they are used are in serious need of refactoring)
  #
  def complex_tally_induced_media_variants(inducer_mat, experimental_antibiotic_mat, media_type_mat)
    media_hash = Hash.new(0) # [media, (inducers to concs)) to count)
    inducer_mat.each_with_index do |row, r_idx|
      row.each_with_index do |col, c_idx|
        if col
          media_type_no_inducer = media_type_mat[r_idx][c_idx] + " " + experimental_antibiotic_mat[r_idx][c_idx]
          inducer_hash = col
          media_type_with_inducers = [media_type_no_inducer, inducer_hash]
          media_hash[media_type_with_inducers] += 1
        end
      end
    end
    return media_hash 
  end
  
########################################################################################################3
# high throughput culture data association helpers

  def record_plate_provenance_parallel_transfer(in_plate, out_plate)
    out_plate_associations = AssociationMap.new(out_plate)
    in_plate_associations = AssociationMap.new(in_plate)
    out_plate.dimensions[0].times do |r_idx|
      out_plate.dimensions[1].times do |c_idx|
        if (in_plate.matrix[r_idx][c_idx] != -1)
          add_provenance({
              from: in_plate, 
              from_map: in_plate_associations,
              from_coord: [r_idx, c_idx],
              to: out_plate,
              to_coord: [r_idx, c_idx],
              to_map: out_plate_associations
          })
        end
      end
    end
    out_plate_associations.save
    in_plate_associations.save
  end
  
  def transference_paperwork(in_collection, out_collection)
    out_collection.associate_matrix(in_collection.matrix)
    
    
    overnight_antibiotic_mat      = in_collection.data_matrix_values("Overnight Antibiotic")
    experimental_antibiotic_mat   = in_collection.data_matrix_values("Experimental Antibiotic")
    media_type_mat                = in_collection.data_matrix_values("Type of Media")
    inducer_mat                   = in_collection.data_matrix_values("Inducers")
    ctag_mat                      = in_collection.data_matrix_values("Control Tag")
    
    out_collection.set_data_matrix("Overnight Antibiotic", overnight_antibiotic_mat)
    out_collection.set_data_matrix("Experimental Antibiotic", experimental_antibiotic_mat)
    out_collection.set_data_matrix("Type of Media", media_type_mat)
    out_collection.set_data_matrix("Inducers", inducer_mat)
    out_collection.set_data_matrix("Control Tag", ctag_mat)

    
    record_plate_provenance_parallel_transfer(in_collection, out_collection)
  end
end