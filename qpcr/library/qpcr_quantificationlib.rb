# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

needs "Standard Libs/AssociationManagement"
needs "RNA/StaRNAdard Lib"
module AbsoluteQuantification
    
    include AssociationManagement
    include StaRNAdard_Lib
    
    
    # This function calculates the input sample conc (nM) and associating it to it's respective part in the collection it is in
    #
    # @params sq_conc_hash [Hash] is a hash that consists of 'collection/alpha_coord': in_qpcr_rxn_conc(float)
    def calculate_input_sample_concentrations(sq_conc_hash)
        sq_conc_hash.each {|input_source, rxn_conc|
            in_coll_id, alpha_coord = input_source.split('/')
            in_coll = Collection.find(in_coll_id)
            r, c = find_rc_from_alpha_coord(alpha_coord=alpha_coord).first
            # Apply the dilution factor that is caused by placing 2ul of sample into 18ul of qpcr_mastermix
            linear_range_diluted_stock_conc = rxn_conc * 10
            
            # Find the dilution factor that was applied to get sample into qpcr linear range 1:1000
            dilution_factor = ( 10**( Math.log10(in_coll.get_part_data(:dilution_factor, r, c)).abs ) )
            
            # Apply linear range dilution to linear_range_diluted_stock_conc to find original sample concentration
            input_sample_conc_pM = linear_range_diluted_stock_conc * dilution_factor
            input_sample_conc_nM = (input_sample_conc_pM/1000).round(4)
            
            in_coll.set_part_data(:indexed_dna_conc_nM, r, c, input_sample_conc_nM)
        }
    end
    
    # This fuction creates a matrix that corresponds to how dilute an input sample is before going into the qpcr_rxn
    #
    # @params collection [collection obj] is the collection that contains the samples that are being quantified
    # @returns dilution_factor_matrix [2-D Array] is the matrix that contains floats corresponding to how diluted a indexed lib is before going into the qpcr rxn
    def dilution_factor_matrix(collection)
        dilution_factor_matrix = Array.new(8) { Array.new(12) {-1} }
        collection.get_non_empty.each {|r,c| 
            dilution_factor_matrix[r][c] = collection.get_part_data(:dilution_factor, r, c)
        }
        return dilution_factor_matrix
    end
    
    
    
    # This function finds the qPCR standard curve then applies the regressional trendline to the experimental samples in order to find the concentration of indexed cDNA Libs/Fragments
    # @params q_coll_id [int] is the id number of the qpcr plate collection that was measured
    # @params qpcr_upload [upload obj] is the upload that was uploaded by the tech that corresponds to the measurements of the q_coll_id collection
    # @returns sq_conc_hash [Hash] is a hash that consists of 'collection/alpha_coord': in_qpcr_rxn_conc(float)
    def qpcr_quantification(q_coll_id, qpcr_upload)
        
        # Turn qpcr_upload.csv into a matrix
        upload_matrix = read_url(qpcr_upload)
        
        # Apply standard curve to the experimental samples
        sq_conc_hash = quantifying_experimental_samples(q_coll_id, upload_matrix)
        
        return sq_conc_hash
    end
    
    # This function quatifies the experimental samples by finding the qpcr_standard_curve then, applying it the the average Cq_vals of experimental samples
    # 
    # @params q_coll_id [int] is the id number of the qpcr plate collection that was measured
    # @params upload_matrix [2-D Array] is a parsed out .csv upload from the qpcr_thermocycler
    # @returns sq_conc_hash [Hash] is a hash that consists of 'collection/alpha_coord': in_qpcr_rxn_conc(float)
    def quantifying_experimental_samples(q_coll_id, upload_matrix)
        
        q_coll = Collection.find(q_coll_id)
        q_coll_associations = AssociationMap.new(q_coll)
        
        qpcr_tracking_matrix = q_coll.get('qpcr_tracking_matrix')
        qpcr_tracking_matrix = update_qpcr_tracking_matrix_cq_vals(
            upload_matrix,
            qpcr_tracking_matrix
            )
        
        # Average collected value and arranage in a x=>y structure
        cq_replicates_hash = create_cq_replicates_hash(qpcr_tracking_matrix)
        cq_replicates_hash.each {|k, arr|
            cq_replicates_hash[k] = array_average(arr)
        }
        
        # Find standard curve 
        slope, yint, x_arr, y_arr, r_sq, effieciency = find_qpcr_standard_curve(cq_replicates_hash)
        qpcr_standard_curve = "Cq = #{slope}(log_initial_conc) + #{yint}\n(R^2 = #{r_sq}; Effieciency #{effieciency}%)"
        
        # Find starting quantity concentration of sample inside the qpcr rxn well by applying standard curve 
        sq_conc_hash = find_starting_quantity_concentration(cq_replicates_hash, slope, yint)
        # log_info 'sq_conc_hash', sq_conc_hash
        
        # Update qpcr_tracking_matrix with starting quantity values
        qpcr_tracking_matrix = qpcr_tracking_matrix.map {|arr|
            arr.map {|obj| 
                if obj != -1
                    if !obj[:source].include? "STD"
                        obj[:in_rxn_conc_pM] = sq_conc_hash[obj[:source]].round(3)
                    end
                end
                obj
            }
        }
        # Associate to part items
        q_coll.get_non_empty.each {|r, c|
            q_coll.set_part_data(:qpcr_tracking_matrix, r, c, qpcr_tracking_matrix[r][c])
        }
        # Associate old school way to the collection
        q_coll_associations.put('qpcr_tracking_matrix', qpcr_tracking_matrix)
        q_coll_associations.put('qpcr_standard_curve', qpcr_standard_curve)
        q_coll_associations.save

        return sq_conc_hash
    end
    
    # This function applies the standard curve to the experimental measuremnt values of cq_replicates_hash
    # It does two things finds the initial log conc then find the starting quantity in the rxn
    #
    # @params cq_replicates_hash [hash] uses the source argument from qpcr_tracking_matrix to track replicates
    # @params slope [float] is the slope of the calculated regreesional standard curve 
    # @params yint [float] is the y-intercept of the calculated regreesional standard curve 
    #
    # @returns sq_conc_hash [Hash] is a hash that consists of 'collection/alpha_coord': in_qpcr_rxn_conc(float)
    def find_starting_quantity_concentration(cq_replicates_hash, slope, yint)
        sq_conc_hash = Hash.new()
        cq_replicates_hash.each {|k, cq_ave|
            # Doing two things finding the initial log conc then finding the starting quantity in rxn
            sq_conc_hash[k] = (10**( (cq_ave - yint)/slope) )
        }
        return sq_conc_hash
    end
    
    
    # This function is used to create a hash that accounts for the triplicates in the qpcr_quantification
    #
    # @params qpcr_tracking_matrix [2-D Array] is a matrix of qpcr tracking objs/hashes
    # 
    # @returns cq_replicates_hash [hash] uses the source argument from qpcr_tracking_matrix to track replicates
    # ie: { 'item_id/A1=>[cq_1, cq_2, cq_3],....}'
    def create_cq_replicates_hash(qpcr_tracking_matrix)
        cq_replicates_hash = Hash.new()
        qpcr_tracking_matrix.each {|arr|
            arr.each {|args|
                if args != -1
                    if cq_replicates_hash.keys.include? args[:source] 
                        cq_replicates_hash[args[:source].to_s].push(args[:cq_val])
                    else
                        cq_replicates_hash[args[:source].to_s] = [args[:cq_val]]
                    end
                end
            }
        }
        return cq_replicates_hash
    end
    
    # Updates qpcr_tracking_matrix with values from the output of the qpcr thermocycler
    #
    # @params upload_matrix [2-D Array] is the parsed out csv that was uploaded by the tech
    # @params qpcr_tracking_matrix [2-D Array] is a matrix of qpcr tracking objs/hashes
    # 
    # @returns qpcr_tracking_matrix [2-D Array] is a matrix of qpcr tracking objs/hashes that has been updated with measurement values
    def update_qpcr_tracking_matrix_cq_vals(upload_matrix, qpcr_tracking_matrix)
        headers = upload_matrix.shift
        well_idx = headers.find_index('Well')
        cq_idx = headers.find_index('Cq')
        upload_matrix.each {|arr|
            alpha_coord = "#{arr[well_idx].first}#{arr[well_idx][1..arr[well_idx].length].to_i}"
            r, c = find_rc_from_alpha_coord(alpha_coord=alpha_coord).first
            if qpcr_tracking_matrix[r][c] != -1
                qpcr_tracking_matrix[r][c][:cq_val] = arr[cq_idx].to_f
            end
        }        
        return qpcr_tracking_matrix
    end
    
    
    # This function calculates the qpcr standard curve
    #
    # @params upload [upload obj] is the upload that was uploaded from the qPCR thermocycler
    # @returns values that pretain to the standard curve
    def find_qpcr_standard_curve(cq_replicates_hash)
        std_curve_obj = Hash.new()
        cq_replicates_hash.each {|k, cq_ave|
            if k.include? "STD"
                std_conc = k.split('_')[-1].to_f
                std_curve_obj[std_conc] = cq_ave
                cq_replicates_hash.delete(k) # Formats the cq_replicates_hash to only have experimental values
            end
        }
        slope, yint, x_arr, y_arr = qpcr_standard_curve(std_curve_obj)
        r_sq = r_squared_val(slope, yint, x_arr, y_arr)
        effieciency = qpcr_efficiency(slope)
        return slope, yint, x_arr, y_arr, r_sq, effieciency
    end
    
    # Averages values in an array and reduces them to just one value
    def array_average(arr)
        return arr.reduce(:+).to_f / arr.size
    end
    
    # This function iterates over the qpcr upload, to find the Cq values of replicate samples in the experiment
    # 
    # @params replicates_obj [hash] is a hash with key=>array of alpha_numeric coordinates that match coordinates in the csv_matrix produced by the qpcr upload
    # @params csv_matrix [2-D Array] is a matrix generated by parsing out the output of the qpcr instrument
    def retrieve_cq_values(replicate_obj, csv_matrix)
        headers = csv_matrix[0]
        well_idx = headers.find_index('Well')
        cq_idx = headers.find_index('Cq')
        replicate_obj.each {|k, q_arr|
            csv_matrix.each {|arr|
                if q_arr.include? arr[well_idx]
                    q_arr.delete(arr[well_idx])
                    q_arr.push(arr[cq_idx].to_f)
                end
            }
        }
        return replicate_obj
    end

    
    # This function creates a standard curve from the qPCR Standards in the qPCR collection used ('q_colls_used')
    #
    # @params coordinates [hash or 2D-Array] can be a hash or [[x,y],..] where x is known concentration & y is measurement of Cq Mean across three replicates
    #
    # @returns slope [float] float representing the slope of the regressional line
    # @returns yint [float] float representing where the line intercepts the y-axis
    # @returns x_arr [Array] a 1D array for all x coords
    # @returns y_arr [Array] a 1D arrya for all y coords
    def qpcr_standard_curve(standard_curve_obj)
        # Calculating Std Curve for GFP
        num_of_pts = 0
        a = 0
        x_sum = 0
        y_sum = 0
        x_sq_sum = 0
        x_arr = []
        y_arr = []
        standard_curve_obj.each do |x, y|
            if x > 0.0039 # May need to be modified 092018 
                #TODO: Come up with a way to trim points off std curve in order to obtain the highest effieciency/accurate linear range
                
                x = x/10 # Standard Aliquot gets diluted 1:10 into qPCR rxn
                
                x = Math.log10(x) # Log initial concentration in qPCR rxn
                a += (x * y)
                x_sum += x
                x_sq_sum += (x**2)
                y_sum += y
                x_arr.push(x)
                y_arr.push(y)
                num_of_pts += 1
            end
        end
        a *= num_of_pts
        b = x_sum * y_sum
        c = num_of_pts * x_sq_sum
        d = x_sum**2
        slope = (a - b)/(c - d)
        f = slope * (x_sum)
        yint = (y_sum - f)/num_of_pts
        # show{note "y = #{(slope).round(2)}x + #{(yint).round(2)}"}
        return (slope).round(3), (yint).round(3), x_arr, y_arr
    end
    
    # Finds the efficiency of the primer set in the qpcr standard curve
    # 
    # @params slope [int] is the slope of the standard curve 
    # @returns efficiency [float] is the percentage of how efficient the standard curve amplification 
    def qpcr_efficiency(slope)
        efficiency = (10**(-1/slope) - 1) * 100
        return efficiency.round(2)
    end

    
    # This function calculates how much deviation points are from a regressional line - R-squared Value 
    # The closer it is to 1 or -1 the less deviation theres is
    #
    # @params slope [float] float representing the slope of the regressional line
    # @params yint [float] float representing where the line intercepts the y-axis
    # @params x_arr [Array] a 1D array for all x coords
    # @params y_arr [Array] a 1D arrya for all y coords
    #
    # @returns rsq_val [float] float representing the R-squared Value
    def r_squared_val(slope, yint, x_arr, y_arr)
        y_mean = y_arr.sum/y_arr.length.to_f
        # Deviation of y coordinate from the y_mean
        y_mean_devs = y_arr.map {|y| (y - y_mean)**2}
        dist_mean = y_mean_devs.sum # the sq distance from the mean
        # Finding y-hat using regression line
        y_estimate_vals = x_arr.map {|x| (slope * x) + yint }
        # Deviation of y-hat values from the y_mean
        y_estimate_dev = y_estimate_vals.map {|y| (y - y_mean)**2}
        dist_regres = y_estimate_dev.sum # the sq distance from regress. line
        rsq_val = (dist_regres/dist_mean).round(4)
        return rsq_val
    end
    
end # Module Absolute Quantification

# Library code here