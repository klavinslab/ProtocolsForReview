# By: Eriberto Lopez 
# elopez3@uw.edu
# °C µl
# Production 10/05/18

needs "RNA/RNA_ExtractionPrep"
needs "Illumina NGS Libs/RNASeq_PrepHelper"
needs "Illumina NGS Libs/TruSeqStrandedTotalRNAKit"

class Protocol
    include RNA_ExtractionPrep
    include RNASeq_PrepHelper
    include TruSeqStrandedTotalRNAKit
    
    # DEF
    INPUT = "Indexed DNA Library"
    OUTPUT = "Indexed DNA Library"
    
    def intro()
        show do
            title "Enriching Indexed cDNA Fragments"
            separator
            note "This protocol uses PCR to selectively enrich those DNA fragments that have adapter molecules on both ends and to maplify the amount of DNA in the library."
            note "The PCR Enrichment step is performed with a PCR Cocktail that anneals to the ends of the adapters. We minimize the number of the PCR cycle to avoid skewing the representaion of the library."
            note "<b>1.</b> Prepare the PCR Master Mix."
            note "<b>2.</b> Incubate on thermocycler."
            note "<b>3.</b> Clean enriched cDNA libraries."
        end
    end
    
    def main
        
        intro()
        
        # Allows for the operation to pass the the collection/item with the same item_id
        operations.each {|op|
            collections_pass(op, INPUT, OUTPUT) # RNASeq_PrepHelper
        }
        
        get_ice(cool_centrifuge=false)
        
        in_collections = operations.map {|op| op.input(INPUT).collection}.uniq
        
        gather_defrost_amplification_materials(in_collections)
        
        make_pcr_master_mix # Generates PCR MM for all samples in job
        
        in_collections.each {|in_coll|
            add_pcr_master_mix(in_coll)
            incubate_enrich_pcr_plate(in_coll)
            clean_up_enrich_pcr(in_coll)
            transfer_clean_cDNA(in_coll)
        }
        
        operations.store
        
        return {}
    end # Main










end # Class

