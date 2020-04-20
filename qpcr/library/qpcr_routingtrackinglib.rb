# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

needs "qPCR/qPCR_Constants"
needs "Standard Libs/AssociationManagement"

module QPCR_RoutingTrackingLib
    
    include AssociationManagement
    include QPCR_Constants
    
    # This function does a lot of the heavy lifting in organizing the transferring of samples to each new q_coll
    def transfer_and_track_samples(qpcr_transfer_hash)
        qpcr_transfer_hash.keys.sort {|k_x, k_y| k_x.id <=> k_y.id}.each {|in_coll|
        
            in_coll_associations = AssociationMap.new(in_coll)
            q_colls_used = []
            
            qpcr_transfer_hash[in_coll].keys.sort {|k_x, k_y| k_x.id <=> k_y.id}.each {|q_coll|
                
                q_coll_associations = AssociationMap.new(q_coll)
                qpcr_tracking_matrix = q_coll_associations.get('qpcr_tracking_matrix')
                # log_info 'q_coll', q_coll, 'qpcr_tracking_matrix',qpcr_tracking_matrix
                
                in_coll_samp_mat = in_coll.matrix
                q_coll_samp_mat = q_coll.matrix
                in_coll_to_qpcr_plate_hash = qpcr_transfer_hash[in_coll][q_coll]
                in_coll_to_qpcr_plate_hash.each {|q_coord, in_coord|
                    in_r, in_c = in_coord
                    q_r, q_c = q_coord
                    
                    # Transferring sample_id matrix
                    q_coll_samp_mat[q_r][q_c] = in_coll_samp_mat[in_r][in_c]
                    
                    # Creating and filling experimental sample qpcr_obj
                    qpcr_obj = qpcr_tracking_obj()
                    # qpcr_obj[:sample_id] = in_coll_samp_mat[in_r][in_c]
                    # qpcr_obj[:replicate_num] = ''
                    qpcr_obj[:qpcr_item_destination] = "#{q_coll.id}/#{find_alpha_coord_from_rc(q_r, q_c)}"
                    qpcr_obj[:source] = "#{in_coll.id}/#{find_alpha_coord_from_rc(in_r, in_c)}"
                    qpcr_tracking_matrix[q_r][q_c] = qpcr_obj
                }
                q_coll_associations.put('qpcr_tracking_matrix', qpcr_tracking_matrix)
                q_coll_associations.save
                in_coll.matrix = in_coll_samp_mat
                in_coll.save
                q_coll.matrix = q_coll_samp_mat
                q_coll.save
                # log_info 'qpcr_tracking_matrix', qpcr_tracking_matrix
                
                q_colls_used.push(q_coll.id)
            }
            in_coll_associations.put('q_colls_used', q_colls_used)
            in_coll_associations.save()
        }        
    end    
    def qpcr_tracking_obj()
        qpcr_obj = {
            # sample_id: '',
            # replicate_num: '',
            qpcr_item_destination: '',# qpcr_collection_id/Well
            source: '', # input_collection_id/Well
            in_rxn_conc_pM: '', # Only phiX standards will have this filled in
            cq_val: ''
        }
    end
    
    def create_qpcr_plates_w_std_curve(total_rxns, num_qpcr_plates)
        # The sample type that will be used as a standard curve
        phix_sample_id = Sample.find_by_name("PhiX Control v3").id
        phix_stock_item = find(:item, {sample: {name: "PhiX Control v3"}, object_type: {name: 'Fragment Stock' }}).select {|i|
            i.get('indexed_dna_conc_nM').to_f == PHIX_STOCK_CONC  
        }.first
        
        # Each plate can only hold 24 experimental samples in triplicate (72 rxns) and 8 standard samples (24rxns)
        # Maximum of 24 samples from input collection per qPCR plate
        
        # Create qpcr collection with default standard curve for each plate needed for the experiment
        qpcr_collections = []
        
        num_qpcr_plates.times do
            
            # Create new qPCR collection
            new_q_coll = produce new_collection '96 qPCR collection'
            
            # include standard curve sample types in first three columns of qPCR plate
            sample_id_matrix = new_q_coll.matrix
            
            # Associate qpcr_tracking_matrix
            qpcr_tracking_matrix = Array.new(new_q_coll.object_type.rows) { Array.new(new_q_coll.object_type.columns)  {-1} }
            
            # Adding standard curve sample_id - PhiX
            sample_id_matrix.each_with_index {|row, r_i|
                row.each_with_index {|col, c_i|
                    std_cols = [0, 1, 2]
                    if std_cols.include? c_i
                        # Fill sample_id_matrix of new_q_coll with phix_sample
                        sample_id_matrix[r_i][c_i] = phix_sample_id
                        
                        # Fill qpcr_tracking_matrix with known attrbutes of std curve samples
                        std_qpcr_obj = qpcr_tracking_obj()
                        # std_qpcr_obj[:sample_id] = phix_sample_id
                        # std_qpcr_obj[:replicate_num] = (c_i + 1)
                        std_qpcr_obj[:qpcr_item_destination] = "#{new_q_coll.id}/#{find_alpha_coord_from_rc(r_i, c_i)}"
                        std_qpcr_obj[:source] = "#{phix_stock_item.id}/PhiX_STD_#{QPCR_STANDARD_CURVE_RANGE[r_i]}" 
                        std_qpcr_obj[:in_rxn_conc_pM] = set_std_in_rxn_conc(r_i, c_i)
                        qpcr_tracking_matrix[r_i][c_i] = std_qpcr_obj
                    end
                }
            }
            q_coll_associations = AssociationMap.new(new_q_coll)
            q_coll_associations.put('qpcr_tracking_matrix', qpcr_tracking_matrix)
            q_coll_associations.save()
            
            new_q_coll.matrix = sample_id_matrix
            new_q_coll.save
            qpcr_collections.push(new_q_coll)
        end
        # Now that the new qpcr plates are created they need to be filled
        # Follow the sample_id_matrix to make sure samples are correctly being tracked
        return qpcr_collections
    end
    def set_std_in_rxn_conc(r_i, c_i)
        std_curve_conc_stripwell = QPCR_STANDARD_CURVE_RANGE
        return (std_curve_conc_stripwell[r_i])/10.0 # Std curve gets diluted 1:10 in the qpcr_rxn
    end
    
    def create_transfer_mapping(input_str, exp_reps_val, qpcr_collections)
        # For each input_collection transfer samples to qpcr_collections for quantification
        groupby_in_collections = operations.group_by {|op| op.input(input_str).collection}
        
        # Build qpcr_transfer_hash to keep track of which wells of the qpcr collection will be filled
        qpcr_transfer_hash = Hash.new()
        groupby_in_collections.map {|in_coll, ops|
        
            # Create triplicates of the non_empty wells of the in_coll and slice by the num of cols in the in_coll container
            input_replicate_rows = in_coll.get_non_empty.each_slice(in_coll.object_type.columns).map {|row| 
                row*exp_reps_val
            }
            # log_info 'input_replicate_rows', input_replicate_rows
            
            # Initialize variables to hold on to the same qpcr_collection until it is filled
            q_coll = nil
            to_fill_rc = nil
            qpcr_transfer_hash[in_coll] = {}
            
            # For each input_collection row that we created triplicates for, organize into 4 by 9 matrix, then merge to transfer_hash
            input_replicate_rows.each_with_index {|row_rc_set, r_idx|
                
                # Will format triplicates for ease of tech to transfer to qpcr_collection/plate
                qpcr_replicate_rc_matrix = format_in_coll_input_rc_list(row_rc_set)
                # log_info 'qpcr_replicate_rc_matrix', qpcr_replicate_rc_matrix
                    
                # Get a qpcr collection to fill and see which wells are to be filled
                # NOTE: 2 input_collection rows fill up a qpcr_collection with a standard curve
                if r_idx % 2 == 0
                    # q_coll = qpcr_collections[r_idx%2]
                    q_coll = get_qpcr_collection(qpcr_collections)
                    to_fill_rc = get_format_to_fill_rc(q_coll)
                end
                
                # Build hash
                hash = build_qpcr_transfer_hash(in_coll, q_coll, to_fill_rc, qpcr_replicate_rc_matrix)
                
                # Merge to large qpcr_transfer_hash under the input collection key
                if qpcr_transfer_hash[in_coll].keys.include? q_coll
                    qpcr_transfer_hash[in_coll][q_coll].merge!(hash)
                else
                    qpcr_transfer_hash[in_coll][q_coll] = hash
                end
            }
        }
        # log_info qpcr_transfer_hash # ie: {in_coll =>{ q_coll =>{[q_coll_rc]=>[in_coll_rc], ...}
        # qpcr_transfer_hash.each {|key, val| log_info key, val}
        return qpcr_transfer_hash
    end
    def get_qpcr_collection(qpcr_collections)
        return qpcr_collections.shift()
    end
    def get_format_to_fill_rc(q_coll)
        return q_coll.get_empty.each_slice(9).map {|s| s}
    end

    # Will format triplicates for ease of tech to transfer to qpcr_collection/plate
    #
    # @params row_rc_list [2D Array] represents triplicates created from an input collection row ie: A1...A12 in triplicate
    def format_in_coll_input_rc_list(row_rc_set)
        
        # Find where row_rc_set starts and repeats for replicates 
        # row_rc_set starts from the if it is coming from the first column of the input collection ie: in_c == 0
        triplicate_row_starting_idx = row_rc_set.each_index.select{|idx| 
            in_r, in_c = row_rc_set[idx]
            in_c == 0
        }
        
        # Slicing input triplicates by the position of the [X,0] index
        increment = triplicate_row_starting_idx[0] + triplicate_row_starting_idx[1]
        
        # Build formatted matrix with dimensions of 4 by 9
        formatted_input_rc_matrix = []
        last_row = []
        triplicate_row_starting_idx.map {|idx| 
            # Use starting idx and increment to take a section of row_rc_set, then slice by 9 to fit dimensions
            arr = row_rc_set[idx...(idx + increment)].each_slice(9).map{|s|s}
            
            # If the row_rc_set.length is > 9 then arr will have two slices, the first will go into our formatted matrix
            # The second (remaining samples) will go onto the last_row array
            arr.each_with_index {|slice, a_i|
                # If it is the first slice, check length, fill to 9 if necessary, then push to formatted matrix
                if a_i == 0
                    if slice.length == 9
                        formatted_input_rc_matrix.push(slice)
                    else
                        (9 - slice.length).times { slice.push(-1)}
                        formatted_input_rc_matrix.push(slice)
                    end
                else
                    # If it is the second smaller slice push each rc_tuple to the last_row arr
                    slice.each {|rc| last_row.push(rc) }
                end
            }
        }
        # Finally, fill last_row array to 9 if necessary, then push to formatted_input_rc_matrix
        if (last_row.length != 9) 
            (9 - last_row.length).times { last_row.push(-1)}
        end
        formatted_input_rc_matrix.push(last_row)
        
        return formatted_input_rc_matrix
    end
    
    def build_qpcr_transfer_hash(in_coll, q_coll, to_fill_rc, qpcr_replicate_rc_matrix)
        hash = Hash.new()
        rows_filled = 0
        qpcr_replicate_rc_matrix.each_with_index {|row, r_i|
            row.each_with_index {|in_coord, c_i|
                if in_coord != -1
                    fill_coord = to_fill_rc[r_i][c_i]
                    hash[fill_coord] = in_coord #"#{in_coll.id}/#{in_coord}"
                end
            }
            rows_filled = r_i
        }
        # Removes the rows of the q_coll that were filled by input_replicate samples
        (0..rows_filled).each {|r_i| to_fill_rc.shift() }
        return hash
    end

end # Module QPCR_RoutingTracking
