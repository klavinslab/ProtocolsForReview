
# Used for printing out objects for debugging purposes
needs "Standard Libs/Debug"
# needs "Standard Libs/AssociationManagement"
# needs "Standard Libs/MatrixTools"
needs "YG_Harmonization/YG_Controls"
needs "Tissue Culture Libs/CollectionDisplay"
needs "Illumina NGS Libs/TruSeqStrandedTotalRNAKit"

class Protocol
    
    include Debug #, AssociationManagement, MatrixTools
    include YG_Controls
    include CollectionDisplay
    include TruSeqStrandedTotalRNAKit
 
    #PARAMS
    ILLUMINA_ADAPTER_PLATE_TYPE = "Illumina Adapter Plate Type"


    
  def main
        adapter_plate_type = operations.map {|op| op.input(ILLUMINA_ADAPTER_PLATE_TYPE).val}.uniq.first
        available_adapter_plates = find_illumina_adapter_plates(adapter_plate_type)
        adapter_plate_hash = create_adapters_in_adapter_plate_hash(available_adapter_plates)
        test_collection = create_test_collection()
        log_info test_collection.get_non_empty.length

        associating_and_updating_adapter_plate(adapter_plate_hash, test_collection)
      
  end # main
  
  def create_test_collection()
        # Create XX layout collection
        container = ObjectType.find_by_name('96 Well PCR Plate')
        test_collection = produce new_collection container.name
        test_collection.location = "-20°C Freezer"
        # log_info 'test_collection', test_collection
        
        # I want a list of the r,c to an X design on a collection plate
        rc_list = []
        tst = []
        alpha = ('A'..'H').to_a
        r_alpha = alpha.reverse
        r_nums = (0...12).to_a.reverse
        (0...8).to_a.map do |idx|
            coord = alpha[idx] + (idx + 1).to_s
            r_coord = r_alpha[idx] + (idx + 1).to_s
            coord_r = alpha[idx] + (r_nums[idx] + 1).to_s
            r_coord_r = r_alpha[idx] + (r_nums[idx] + 1).to_s
            
            rc = find_rc_from_alpha_coord(alpha_coord=coord).first
            rrc = find_rc_from_alpha_coord(alpha_coord=r_coord).first
            cr = find_rc_from_alpha_coord(alpha_coord=coord_r).first
            rcr = find_rc_from_alpha_coord(alpha_coord=r_coord_r).first
            rc_list.push(rc)
            rc_list.push(rrc)
            rc_list.push(cr)
            rc_list.push(rcr)
            
            tst.push(coord)
            tst.push(r_coord)
            tst.push(coord_r)
            tst.push(r_coord_r)
        end
      log_info tst, rc_list
      
      rc_list.each do |r,c|
          test_collection.set(r,c,6390)
      end
      
      show do
          title "Collection Test"
          separator
          table highlight_rc(test_collection, rc_list){|r,c| 'YS' }
      end
      return test_collection
      
  end
  
  
    def get_date_created()
        log_info item.created_at
    end
    def get_tracking_matrix_well_vols(tracking_matrix)
        tracking_matrix.each_with_index.map {|row, r_i| row.each_with_index.map {|col, c_id| col[:volume]}}.flatten.uniq
    end
    
end # class
