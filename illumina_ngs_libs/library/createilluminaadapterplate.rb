# Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

needs "Standard Libs/AssociationManagement"
needs "Standard Libs/MatrixTools"
needs "YG_Harmonization/YG_Controls"


module CreateIlluminaAdapterPlate
    include AssociationManagement, MatrixTools
    include YG_Controls
    
    def create_illumina_adapter_sample_collection(adapter_plt_type)
        
        # Create a new 96 Well Adapter Plate
        output_adapter_plt = produce_new_adapter_plate()
        
        # Find Illumina Adapters and Indexes samples based on the type of adapter plate paramtere
        adapter_samp_pfx, select_adapter_samples = find_adapter_index_samples(adapter_plt_type)
        
        # With the set of selected adatpters fill the 96 Well Adapter Plate
        fill_new_adapter_plate(output_adapter_plt, select_adapter_samples)
        
        # To distiguish between similar adapter plate types obtain the plate_number of the plate through user input
        show_hash = get_plate_number_from_new_plate(adapter_plt_type)
        
        # Create a tracking obj that will be dispersed into a matrix; Each obj has information about each well in the physical adapter plate
        ngs_tracking_obj = create_tracking_obj(show_hash)
        ngs_tracking_matrix = create_tracking_matrix(output_adapter_plt, ngs_tracking_obj)
        
        # Associate tracking matrix and other info to the new adapter plate
        to_associate = {}
        to_associate['ngs_tracking_matrix'.to_sym] = ngs_tracking_matrix
        to_associate['adapter_plate_type'.to_sym] = adapter_plt_type
        to_associate['date_openned'.to_sym] = show_hash[:date_openned]
        adapter_plate_associations(output_adapter_plt, args=to_associate)
        
        # Displays details of the new adapter plate that was create by this protocol
        show do
            title "New Adapter Plate Created"
            separator
            note "Illumina Adapter Plate: #{output_adapter_plt}"
            note "Collection id: #{output_adapter_plt.id}"
            note "Adapter Plate Type: #{adapter_plt_type}"
            note "Plate # #{show_hash[:plate_number]}"
            note "Date openned: #{show_hash[:date_openned]}"
            note "AssociationMap Associations key: 'ngs_tracking_matrix'"
            note "AssociationMap Associations key: 'adapter_plate_type'"
            note "AssociationMap Associations key: 'date_openned'"
        end
    end
    
    def produce_new_adapter_plate()
        # Produce 96 Well Adapter Plate collection
        container = ObjectType.find_by_name('96 Well Adapter Plate')
        output_adapter_plt = produce new_collection container.name
        output_adapter_plt.location = "-20°C Freezer Illumina Section"
        log_info 'Produced adapter_plt collection', output_adapter_plt
        return output_adapter_plt
    end

    def find_adapter_index_samples(adapter_plt_type)
        # Find adapter samples with adapter_plt_type prefix and use the alpha coord to fill into the appropriate position in the plate
        adapter_samp_pfx = adapter_plt_type.split('_')[0..2].join("_")
        select_adapter_samples = find(:sample, sample_type_id: SampleType.find_by_name('Illumina Adapters and Indexes').id ).select {|s| 
            s.name.include? adapter_samp_pfx 
        }
       return  adapter_samp_pfx, select_adapter_samples
    end
    
    def fill_new_adapter_plate(output_adapter_plt, select_adapter_samples)
        select_adapter_samples.each {|a_samp|
            alpha_coord = a_samp.name.split('_')[-1]
            r , c = find_rc_from_alpha_coord(alpha_coord=alpha_coord)[0]
            output_adapter_plt.set(r, c, a_samp)
        }
        log_info 'output_adapter_plt filled', output_adapter_plt, output_adapter_plt.matrix
    end

    def get_plate_number_from_new_plate(adapter_plt_type)
        # Get the lot number of the new plate to distiguish multi plates of the same type
        show do
            title "New Illumina Adapter Plate"
            separator
            note "What is the Lot # of the new Illumina #{adapter_plt_type}?"
            get "number", var: "plate_number", label: "Enter the plate number found on the new Illumina #{adapter_plt_type}", default: 123456
            get "text", var: "date_openned", label: "What it today's date? (MM/DD/YY)", default: '07/18/17'
        end
    end
    
    def create_tracking_obj(show_hash)
        date_openned = show_hash[:date_openned]
        tracking_obj = {
            volume: 5,#ul
            plan_associations: [], # Can get two uses from each well 2.5ul each use
            item_associations: [],  # Can get two uses from each well 2.5ul each use
            date_openned: date_openned
        }
        return tracking_obj
    end

    def create_tracking_matrix(adapter_plate, tracking_obj)
        tracking_matrix = Array.new(adapter_plate.object_type.rows) { Array.new(adapter_plate.object_type.columns) {tracking_obj} }
        return tracking_matrix
    end

    def adapter_plate_associations(output_adapter_plt, args)
        adapter_plt_associations = AssociationMap.new(output_adapter_plt)
        args.each {|sym, val| adapter_plt_associations.put(sym, val)}
        adapter_plt_associations.save
    end

    
end # Module CreateIlluminaAdapterPlate



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




