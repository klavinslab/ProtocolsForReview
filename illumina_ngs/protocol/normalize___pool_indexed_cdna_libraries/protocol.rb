# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18
#
# This protocol should be done after qPCR quantification has calculated and associated the indexed lib conc nM

# needs "RNA/StaRNAdard Lib"
needs "Illumina NGS Libs/TruSeqStrandedTotalRNAKit"


class Protocol
    # include StaRNAdard_Lib
    include TruSeqStrandedTotalRNAKit
    
    # DEF
    INPUT = "Indexed DNA Library"
    OUTPUT = "Pooled DNA Library"
    
    # PARAM
    FINAL_CONC = "Normalize to (nM)"
    
    def intro()
        show do 
           title "Normalize & Pool Indexed DNA Libraries"
           separator
           note "This process describes how to prepare the DNA templates for cluster generation. 
                Indexed DNA libraries are normalized to a given concentration (nM), then pooled in equal volumes."
           note "<b>1.</b> Dilute samples to a range that is accurate to pipette."
           note "<b>2.</b> Fill plate with dilutant and transfer appropriate sample volume."
           note "<b>3.</b> Pool normalized samples in equal volumes."
        end
    end
    
    def main
        
        intro
        
        # Allows for the operation to pass the the collection/item with the same item_id
        # operations.each {|op|
        #     collections_pass(op, INPUT, OUTPUT) # RNASeq_PrepHelper
        # }
        
        operations.make
        
        # Calculate how much of cDNA libs are needed to obtain Normalization paramter conc in 50ul total
        normalizing_cdna_libraries(INPUT, OUTPUT, FINAL_CONC)
        
        
        
        tin  = operations.io_table 'input'
        tout = operations.io_table 'output'
        
        show do
          title 'Input Table'
          table tin.all.render
        end
        
        show do
          title 'Output Table'
          table tout.all.render
        end
        
        operations.store
        
        {}
        
    end # Main

end # Class
