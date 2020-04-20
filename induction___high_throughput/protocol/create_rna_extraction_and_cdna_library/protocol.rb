# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

needs "Standard Libs/Debug"
# needs "Induction - High Throughput/NovelChassisLib"



class Protocol
    
    include Debug
    # include NovelChassisLib
    INPUT = "RNA Prep Plate"
    
    MEDIA_LABEL_HASH = {
        'None'=>'M9',
        'Kan'=>'M9_Kan',
        'Kan_Chlor'=>'M9_Kan_Chlor',
        'None_None'=>'M9', 
        'None_arab_25.0'=>'M9_Arab', 
        'Kan_None'=>'M9_Kan', 
        "None_IPTG_0.25"=>'M9_IPTG', 
        "None_IPTG_0.25|arab_25.0"=>'M9_IPTG_Arab', 
        "Kan_IPTG_0.25"=>'M9_Kan_IPTG',
        'Kan_arab_25.0'=>'M9_Kan_Arab',
        'Kan_IPTG_0.25|arab_25.0'=>'M9_Kan_IPTG_Arab'
    }
    def main
        
        operations.retrieve.make
        
        dual_adapter_indicies_arr = [
            "ATTACTCG TATAGCCT",	"TCCGGAGA TATAGCCT",	"CGCTCATT TATAGCCT",	"GAGATTCC TATAGCCT",	
            "ATTCAGAA TATAGCCT",	"GAATTCGT TATAGCCT",	"CTGAAGCT TATAGCCT",	"TCCGGAGA TATAGCCT",
            "CGGCTATG  TATAGCCT",	"TCCGCGAA TATAGCCT",	"TCTCGCGC TATAGCCT",	"AGCGATAG TATAGCCT",
            "ATTACTCG ATAGAGGC",	"TCCGGAGA ATAGAGGC",	"CGCTCATT ATAGAGGC",	"GAGATTCC ATAGAGGC",
            "ATTCAGAA ATAGAGGC",	"GAATTCGT ATAGAGGC",	"CTGAAGCT ATAGAGGC",	"TCCGGAGA ATAGAGGC",
            "CGGCTATG  ATAGAGGC",	"TCCGCGAA ATAGAGGC",	"TCTCGCGC ATAGAGGC",	"AGCGATAG ATAGAGGC",
            "ATTACTCG CCTATCCT",	"TCCGGAGA CCTATCCT",	"CGCTCATT CCTATCCT",	"GAGATTCC CCTATCCT",
            "ATTCAGAA CCTATCCT",	"GAATTCGT CCTATCCT",	"CTGAAGCT CCTATCCT",	"TCCGGAGA CCTATCCT",
            "CGGCTATG  CCTATCCT",	"TCCGCGAA CCTATCCT",	"TCTCGCGC CCTATCCT",	"AGCGATAG CCTATCCT",
            "ATTACTCG GGCTCTGA",	"TCCGGAGA GGCTCTGA",	"CGCTCATT GGCTCTGA",	"GAGATTCC GGCTCTGA",
            "ATTCAGAA GGCTCTGA",	"GAATTCGT GGCTCTGA",	"CTGAAGCT GGCTCTGA",	"TCCGGAGA GGCTCTGA",
            "CGGCTATG  GGCTCTGA",	"TCCGCGAA GGCTCTGA",	"TCTCGCGC GGCTCTGA",	"AGCGATAG GGCTCTGA",
            "ATTACTCG AGGCGAAG",	"TCCGGAGA AGGCGAAG",	"CGCTCATT AGGCGAAG",	"GAGATTCC AGGCGAAG",
            "ATTCAGAA AGGCGAAG",	"GAATTCGT AGGCGAAG",	"CTGAAGCT AGGCGAAG",	"TCCGGAGA AGGCGAAG",
            "CGGCTATG  AGGCGAAG",	"TCCGCGAA AGGCGAAG",	"TCTCGCGC AGGCGAAG",	"AGCGATAG AGGCGAAG",
            "ATTACTCG TAATCTTA",	"TCCGGAGA TAATCTTA",	"CGCTCATT TAATCTTA",	"GAGATTCC TAATCTTA",
            "ATTCAGAA TAATCTTA",	"GAATTCGT TAATCTTA",	"CTGAAGCT TAATCTTA",	"TCCGGAGA TAATCTTA",
            "CGGCTATG  TAATCTTA",	"TCCGCGAA TAATCTTA",	"TCTCGCGC TAATCTTA",	"AGCGATAG TAATCTTA",
            "ATTACTCG CAGGACGT",	"TCCGGAGA CAGGACGT",	"CGCTCATT CAGGACGT",	"GAGATTCC CAGGACGT",
            "ATTCAGAA CAGGACGT",	"GAATTCGT CAGGACGT",	"CTGAAGCT CAGGACGT",	"TCCGGAGA CAGGACGT",
            "CGGCTATG  CAGGACGT",	"TCCGCGAA CAGGACGT",	"TCTCGCGC CAGGACGT",	"AGCGATAG CAGGACGT",
            "ATTACTCG GTACTGAC",	"TCCGGAGA GTACTGAC",	"CGCTCATT GTACTGAC",	"GAGATTCC GTACTGAC",
            "ATTCAGAA GTACTGAC",	"GAATTCGT GTACTGAC",	"CTGAAGCT GTACTGAC",	"TCCGGAGA GTACTGAC",
            "CGGCTATG  GTACTGAC",	"TCCGCGAA GTACTGAC",	"TCTCGCGC GTACTGAC",	"AGCGATAG GTACTGAC"
        ]
        
        adapter_indicies_id_arr = [
            "D701-D501",	"D702-D501",	"D703-D501",	"D704-D501",	"D705-D501",	"D706-D501",	"D707-D501",	"D702-D501",	"D709-D501",	"D710-D501",	"D711-D501",	"D712-D501",
            "D701-D502",	"D702-D502",	"D703-D502",	"D704-D502",	"D705-D502",	"D706-D502",	"D707-D502",	"D702-D502",	"D709-D502",	"D710-D502",	"D711-D502",	"D712-D502",
            "D701-D503",	"D702-D503",	"D703-D503",	"D704-D503",	"D705-D503",	"D706-D503",	"D707-D503",	"D702-D503",	"D709-D503",	"D710-D503",	"D711-D503",	"D712-D503",
            "D701-D504",	"D702-D504",	"D703-D504",	"D704-D504",	"D705-D504",	"D706-D504",	"D707-D504",	"D702-D504",	"D709-D504",	"D710-D504",	"D711-D504",	"D712-D504",
            "D701-D505",	"D702-D505",	"D703-D505",	"D704-D505",	"D705-D505",	"D706-D505",	"D707-D505",	"D702-D505",	"D709-D505",	"D710-D505",	"D711-D505",	"D712-D505",
            "D701-D506",	"D702-D506",	"D703-D506",	"D704-D506",	"D705-D506",	"D706-D506",	"D707-D506",	"D702-D506",	"D709-D506",	"D710-D506",	"D711-D506",	"D712-D506",
            "D701-D507",	"D702-D507",	"D703-D507",	"D704-D507",	"D705-D507",	"D706-D507",	"D707-D507",	"D702-D507",	"D709-D507",	"D710-D507",	"D711-D507",	"D712-D507",
            "D701-D508",	"D702-D508",	"D703-D508",	"D704-D508",	"D705-D508",	"D706-D508",	"D707-D508",	"D702-D508",	"D709-D508",	"D710-D508",	"D711-D508",	"D712-D508"   
           ]
        
        dual_adapter_indicies_matrix = dual_adapter_indicies_arr.each_slice(12).map {|slice| slice}
        adapter_indicies_id_marix = adapter_indicies_id_arr.each_slice(12).map {|slice| slice}
        
        operations.each do |op|
            
            if debug
                plate = Item.find(139260)
            end

            experimental_media_mat = plate.get('experimental_media_mat')
            transfer_coordinates = plate.get('transfer_coordinates')
            sample_id_matrix = Collection.find(plate.id).matrix
            
            tab = [['Item_id', 'Sample_name', "Well", 'Index_1_name','Index_1_seq', 'Index_2_name', 'Index_2_seq']]
            new_items_arr = sample_id_matrix.map.each_with_index {|row, r_idx| 
                row.map.each_with_index {|col, c_idx|
                    if (col != -1)
                        sample_id = col
                        experimental_condition = MEDIA_LABEL_HASH[experimental_media_mat[r_idx][c_idx]]
                        plate_position = transfer_coordinates[r_idx][c_idx]
                        barcode = dual_adapter_indicies_matrix[r_idx][c_idx]
                        barcode_id = adapter_indicies_id_marix[r_idx][c_idx]
                        new_cdna_lib_item = produce new_object 'Illuminated Fragment Library'
                        new_cdna_lib_item.sample_id = sample_id
                        new_cdna_lib_item.associate('experimental_condition', experimental_condition)
                        new_cdna_lib_item.associate('barcode', barcode)
                        new_cdna_lib_item.associate('barcode_id', barcode_id)
                        new_cdna_lib_item.associate("source".to_sym, "plate_#{plate.id}")
                        new_cdna_lib_item.associate('plate_position', plate_position)
                        new_cdna_lib_item.location = 'Bench - being pooled for run'
                        new_cdna_lib_item.save
                        tab.push([new_cdna_lib_item.id, "#{new_cdna_lib_item.id}_#{experimental_condition}", new_cdna_lib_item.get('plate_position'), "#{barcode_id.split('-')[0]}", "#{barcode.split(' ')[0]}", "#{barcode_id.split('-')[1]}", "#{barcode.split(' ')[1]}"])
                        # log_info 'new_cdna_lib_item', new_cdna_lib_item, new_cdna_lib_item.id, new_cdna_lib_item.sample_id, new_cdna_lib_item.get('experimental_condition'), new_cdna_lib_item.get('plate_position'), new_cdna_lib_item.get('barcode')
                    end
                }
            }
            show do
                title "table"
                separator
                table tab
            end
        end
        
        return {}
        
    end

end
