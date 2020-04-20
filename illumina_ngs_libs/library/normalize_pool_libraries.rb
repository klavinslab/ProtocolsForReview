# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

module Normalize_Pool_Libraries
    include Units
    include CollectionDisplay
    
    def normalizing_cdna_libraries(input_def, output_def, normalization_def)
        
        groupby_in_collections = operations.group_by {|op| op.input(input_def).collection}
        groupby_in_collections.each {|in_coll, ops|
            if debug
                in_coll = Collection.find(398482)
            end
            
            # Find indexed DNA concentrations
            dilution_rc_list = [] # used to keep track of which samples need to be diltued before normalized - to display
            dilution_factor_matrix = [] # used to keep track of how much a given sample must be diluted
            diluted_dna_conc_nM = [] # Calculates the conc of the sample after the dilution factor has been applied
            
            in_coll.data_matrix(:indexed_dna_conc_nM).each_with_index {|row, r_idx|
                df_arr = []
                diluted_conc_arr = []
                row.each_with_index {|da, c_idx|
                    if !da.nil?
                        # If the conc of sample is greater than 250 nM then it must be diluted
                        (da.value > 250.0) ? dilution_rc_list.push([r_idx, c_idx]) : nil
                        
                        # Depending on how concentrated the sample dilute by either 100, 10, or 1 fold
                        dilution_factor = dilution_factor(da.value)
                        
                        # Create a matrix to keep track of how diluted samples need to be
                        df_arr.push(dilution_factor)
                        
                        # Apply dilution factor to the indexed_dna_conc_nM value
                        diluted_conc_arr.push(da.value/dilution_factor)
                    else
                        df_arr.push(-1)
                        diluted_conc_arr.push(-1)
                    end
                }
                dilution_factor_matrix.push(df_arr)
                diluted_dna_conc_nM.push(diluted_conc_arr)
            }
            
            
            # log_info 'diluted_dna_conc_nM',diluted_dna_conc_nM
            # log_info 'dilution_rc_list', dilution_rc_list
            # log_info 'dilution_factor_matrix', dilution_factor_matrix
            
            # Direct tech to dilute the libraries before normalization
            if !dilution_rc_list.nil?
                show do
                    title "Dilute cDNA Libraries"
                    separator
                    note "Gather a clean <b>96 Well PCR Plate</b> and label <b>Dilution_#{in_coll}</b>"
                    note "Follow the table to pre-fill the plate with <b>Tris-HCl 10 mM, pH 8.5 with 0.1% Tween 20</b>"
                    table highlight_alpha_rc(in_coll, dilution_rc_list){|r,c| "#{dilutant_vol(dilution_factor_matrix[r][c])}#{MICROLITERS}"}
                end
                show do
                    title "Dilute cDNA Libraries"
                    separator
                    note "Follow the table below to transfer the appropriate volume of sample from #{in_coll} to its corresponding well in <b>Dilution_#{in_coll}</b>"
                    bullet "Mix by pipetting 10 times"
                    table highlight_alpha_rc(in_coll, dilution_rc_list){|r,c| "#{sample_vol(dilution_factor_matrix[r][c])}#{MICROLITERS}"}
                end
            end
            
            gather_dilutant_vol = 0
            normalization_conc = operations.map {|op| op.input(normalization_def).val}.uniq.first
            dilutant_vol_matrix = diluted_dna_conc_nM.map {|row|
                row.map {|conc|
                    total_vol = ((conc/normalization_conc) * 10 ) - 10 # Find the conc_factor to dilute 10ul of a given conc to the normalization_conc. Then subtract the volume already in the well
                    (total_vol > 0) ? gather_dilutant_vol += total_vol.round(2) : gather_dilutant_vol += 0
                    (total_vol > 0) ? total_vol.round(2) : 0
                }
            }
            
            # Direct tech to transfer samples to new output collection and normalize to a given concentration
            groupby_out_collections = ops.group_by {|op| op.output(output_def).collection}
            groupby_out_collections.each {|out_coll, ops|
                show do 
                    title "Normalizing DNA Libraries"
                    separator
                    note "Gather a clean <b>#{out_coll.object_type.name}</b> and label it <b>#{out_coll.id}</b>"
                    note "Next, transfer 10#{MICROLITERS} of each sample from both <b>Dilution_#{in_coll.id}</b> and <b>#{in_coll.id}</b> to it's corresponding well in <b>#{out_coll.id}</b>"
                end
                show do 
                    title "Normalizing DNA Libraries"
                    separator
                    note "Gather or create <b>#{gather_dilutant_vol.round(-2)}#{MICROLITERS}</b> of <b>Tris-HCl 10 mM, pH 8.5 with 0.1% Tween 20</b>"
                    note "Follow the table to add the appropriate amount of dilutant to <b>#{out_coll.object_type.name}</b>_<b>#{out_coll.id}</b>"
                    table highlight_alpha_non_empty(out_coll){|r,c| "#{dilutant_vol_matrix[r][c]}"}
                end
            }
        }
    end
    
    def sample_vol(dilution_factor)
        if dilution_factor == 100.0
            dil_vol = 1
        elsif dilution_factor == 10.0
            dil_vol = 5
        else
            dil_vol = -1
        end
    end
    
    def dilutant_vol(dilution_factor)
        if dilution_factor == 100.0
            dil_vol = 99
        elsif dilution_factor == 10.0
            dil_vol = 45
        else
            dil_vol = -1
        end
    end
    def dilution_factor(conc)
        if conc > 2500.0
            dilute_by = 100.0
        elsif conc.between?(250.0, 2500.0)
            dilute_by =  10.0
        elsif (conc < 250.0)
            dilute_by =  1.0
        else
            log_info 'this is else'
        end
        return dilute_by
    end
    
end # Module Normalize_Pool_Libraries


