# By: Eriberto Lopez
# elopez3@uw.edu
# Production: 10/05/18

needs "Standard Libs/Debug"
needs "Illumina NGS Libs/TruSeqStrandedTotalRNAKit"

class Protocol
    include Debug 
    include TruSeqStrandedTotalRNAKit
    
    # I/O
    OUTPUT = "Illumina Adapter Plate"
    
    # PARAMS
    ILLUMINA_ADAPTER_PLATE_TYPE = "Illumina Adapter Plate Type"
    
    def main
        operations.make
        adapter_plt_type = operations.map {|op| op.input(ILLUMINA_ADAPTER_PLATE_TYPE).val}.uniq.first
        # log_info 'adapter_plt_type', adapter_plt_type
        
        create_illumina_adapter_sample_collection(adapter_plt_type)
        
        return {}
        
    end # main
    
end #Class