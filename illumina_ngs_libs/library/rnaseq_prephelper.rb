# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

needs "Standard Libs/Units"
module RNASeq_PrepHelper
    include Units
    # Used for multichannel pipetting, creates a stripwell to display with the number of aliquots of the desired reagents
    #
    # @params collection [colleciton obj] is the collection that you be aliquoting reagent to
    # @returns sw [collection obj] the stripwell obj that will be used to display
    # @returns sw_vol_mat [2D-Array] is the matrix that contains the information of how many aliquots of reagents go in each well
    # @returns rc_list [Array] is a list of [r,c] tuples that will be used to display which wells are to be used for aliquots
    def multichannel_vol_stripwell(collection)
        # Create a stripwell to display
        sw_obj_type = ObjectType.find_by_name('stripwell')
        sw = Collection.new()
        sw.object_type_id = sw_obj_type.id
        sw.apportion(sw_obj_type.rows, sw_obj_type.columns)
        sw.quantity = 1
        
        # Create a matrix the size of the stripwell
        sw_vol_mat = Array.new(sw_obj_type.rows) { Array.new(sw_obj_type.columns) {0} }
        
        # For the non empty wells in the collection that you are aliquoting add 1 to the sw_vol_mat in the appropriate col
        arr = collection.get_non_empty.each_slice(sw_obj_type.columns)
        arr.each_with_index {|row, r_idx|
            row.each_with_index {|col, c_idx|
                sw_vol_mat[0][c_idx] += 1
                # (sw_vol_mat[0][c_idx] == -1) ? sw_vol_mat[0][c_idx] = 1 : sw_vol_mat[0][c_idx] += 1
            }
        }
        
        # Collect tuples [r,c] for the wells that have master mix/reagent aliquoted 
        rc_list = sw_vol_mat[0].each_with_index.map {|well, w_idx| (well == 0) ? nil : [0, w_idx] }.select {|rc| rc != nil}
        return sw, sw_vol_mat, rc_list
    end 
    
    # Finds the uniq operation types in a operation/protocol
    def operation_type()
        op_type = OperationType.find(operations.map {|op| op.operation_type_id}.uniq.first).name
        return op_type.name
    end
    
    # Caluclates reagent volume plus 10%
    #
    # @params num_ops [int] the number of operations/rxns/sample
    # @params single_samp_vol [int] the vol of the reagent for a single sample/rxn
    def reagent_vol_with_extra(num_ops, single_samp_vol)
        # Includes 10% extra volume
        return ((num_ops * single_samp_vol) + (num_ops * single_samp_vol)*0.10).round(2)  
    end

    # Allows for the operation to pass the the collection/item with the same item_id
    def collections_pass(op, input_name, output_name = nil)
        
        output_name ||= input_name
        fv_in = op.input(input_name)
        fv_out = op.output(output_name)
        raise "Could not find input '#{input_name}' in pass" unless fv_in
        raise "Could not find input '#{output_name}' in pass" unless fv_out
        
        fv_out.child_sample_id = fv_in.child_sample_id
        fv_out.child_item_id = fv_in.child_item_id
        fv_out.row = fv_in.row
        fv_out.column = fv_in.column

        fv_out.save
        
        self
    end

end # module RNASeq_PrepHelper