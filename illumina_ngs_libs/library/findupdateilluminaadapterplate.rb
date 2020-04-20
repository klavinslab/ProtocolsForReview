# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

module FindUpdateIlluminaAdapterPlate
    include AssociationManagement, MatrixTools
    include YG_Controls
    
    def find_illumina_adapter_plates(adapter_plate_type)
        adapter_plate_items = find(:item, { object_type: { name: '96 Well Adapter Plate' } } ).select {|i| i.location != 'deleted'}
        adapter_plate_items = adapter_plate_items.select {|item| 
            item.get('adapter_plate_type') == adapter_plate_type
        }
        
        # From the plates that are not deleted use the 'tracking_matrix' to determine if there are available indexes
        available_adapter_plates = adapter_plate_items.select {|item| 
            tracking_matrix = item.get('ngs_tracking_matrix')
            get_tracking_matrix_well_vols(tracking_matrix).include?(5) || get_tracking_matrix_well_vols(tracking_matrix).include?(2.5)
        }
        return available_adapter_plates
    end
    
    def get_tracking_matrix_well_vols(tracking_matrix)
        tracking_matrix.each_with_index.map {|row, r_i| row.each_with_index.map {|col, c_id| col[:volume]}}.flatten.uniq
    end
    
    # TODO: When there are multiple adapter plates of the same type how do we sort them so that we finish the most use plate first?
    # This function creates a hash for each available adapter plate item. For each item, index [r,c] are grouped by how much vol is in each well
    # This will be used to keep track of which wells should be used first (ie: wells with 5ul)
    # ie: {item =>{ 5 =>[ [r,c], [r,c] ], 2.5 =>[ [r,c], [r,c], ... ]} }
    def create_adapters_in_adapter_plate_hash(available_adapter_plates)
        adapter_plate_hash = {}
        available_adapter_plates.each {|item|
            group_idxs_by_vol = Hash.new()
            tracking_matrix = item.get('ngs_tracking_matrix')
            tracking_matrix.each_with_index {|row, r_idx|
                row.each_with_index {|obj, c_idx|
                    if obj[:volume] != 0
                        if group_idxs_by_vol.include? obj[:volume]
                            group_idxs_by_vol[obj[:volume]].append([r_idx, c_idx])
                        else
                            group_idxs_by_vol[obj[:volume]] = [[r_idx, c_idx]]
                        end
                    end
                }
                
            }
            adapter_plate_hash[item] = group_idxs_by_vol
            # log_info 'adapter_plate_hash', adapter_plate_hash
        }
        return adapter_plate_hash
    end

    # This function uses the adapter_plate_hash that groups indexes by volume for each avialble adapter plate in use
    # Next, it finds the coordinates of a collection that will be needing adapters and indexes (non_empty)
    # We loop thorough the adapter_plate_hash to find the properties of a sample in a given [r,c] of the adapter_plate_coll
    # Next, we .shift() the first element of the experimental_wells array which is the exp_r, exp_c
    # And use those coordinates to associate the sample_properties (index/Adapter properties) to the experimental collection
    # If there are no more experimental_wells then stop/break
    # In the same pattern the existing ngs_tracking_matrix must get updated with the volume that was removed, which plan & items the index is associated to
    def associating_and_updating_adapter_plate(adapter_plate_hash, collection)
        plans = operations.map {|op| op.plan.id}.uniq
        collection_associations = AssociationMap.new(collection)
        # Generate a list of [r,c] that require an Adapter and index
        experimental_wells = collection.get_non_empty
        exp_adapter_matrix = Array.new(collection.object_type.rows) { Array.new(collection.object_type.columns) {-1}}
        
        log_info 'adapter_plate_hash', adapter_plate_hash
        
        adapter_plate_hash.each {|item, vol_hash|
            adapter_plate_associations = AssociationMap.new(item) 
            adapter_plate_tracking_mat = item.get('ngs_tracking_matrix') 
            log_info 'tracking matrix before assignment', adapter_plate_tracking_mat
            adapter_plate_coll = Collection.find(item.id)
            
            # Always use adapter/index wells that have the most volume left
            sorted_vol_keys = vol_hash.keys.sort.reverse
            
            sorted_vol_keys.each { |vol|
                rc_arr = vol_hash[vol]
                rc_arr.each {|coord|
                    idx_r, idx_c = coord
                    sample_id = adapter_plate_coll.matrix[idx_r][idx_c]
                    sample = Sample.find(sample_id)
                    sample_properties = sample.properties # .properties creates a hash of the Sample field values
                    sample_properties[:sample_id] = sample_id
                    sample_properties[:sample_name] = sample.name
                    sample_properties[:plate_number] = adapter_plate_tracking_mat[idx_r][idx_c][:plate_number]
                    
                    # Takes experimental wells sequentially until there are no more then, breaks the loop
                    (!experimental_wells.empty?) ? (exp_r, exp_c = experimental_wells.shift()) : (break)
                    exp_adapter_matrix[exp_r][exp_c] = sample_properties
                    
                    # After index has been assigned update the adapter tracking matrix volume, plan associations, item_associations
                    adapter_obj = adapter_plate_tracking_mat[idx_r][idx_c]
                    adapter_obj[:volume] -= 2.5
                    plans.each {|plan| adapter_obj[:plan_associations].append(plan)}
                    adapter_obj[:item_associations].append(collection.id)
                }
            }
            log_info 'tracking matrix after assignment', adapter_plate_tracking_mat
            adapter_plate_associations.put('ngs_tracking_matrix'.to_sym, adapter_plate_tracking_mat)
            adapter_plate_associations.save()
        }
        collection_associations.put('ngs_tracking_matrix'.to_sym, exp_adapter_matrix)
        collection_associations.save()
        log_info 'experimental ngs_tracking_matrix', exp_adapter_matrix
            
    end
    
end # Module FindIlluminaAdapterPlate

