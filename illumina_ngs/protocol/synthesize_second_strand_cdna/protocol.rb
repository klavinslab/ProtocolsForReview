# By: Eriberto Lopez 
# elopez3@uw.edu
# Production 10/05/18

needs "Standard Libs/Debug"
needs "Tissue Culture Libs/CollectionDisplay"
needs "Illumina NGS Libs/RNASeq_PrepHelper"
needs "Illumina NGS Libs/TruSeqStrandedTotalRNAKit"

class Protocol
    include Debug
    include CollectionDisplay
    include RNASeq_PrepHelper
    include TruSeqStrandedTotalRNAKit
    
    #I/O
    INPUT = "First Strand cDNA Library"
    OUTPUT = "cDNA Library"

    def intro()
        show do
            title "Synthesize Second Strand cDNA"
            separator
            note "This protocol removes the RNA template and synthesizes a replacements strand, to generate double stranded cDNA."
            note "Then AMPure XP beads are used to separate the ds cDNA from the second strand reaction mix, thus isolating blunt-ended cDNA."
            note "<b>1.</b> Add Second Strand Master Mix to First Strand cDNA Plate."
            note "<b>2.</b> Incubate Plate on pre-programmed thermocycler."
            note "<b>3.</b> Use beads to isolate blunt-end double stranded cDNA."
        end
    end
    
    def main
        
        intro
        
        # Allows for the operation to pass the the collection/item with the same item_id
        operations.each {|op|
            collections_pass(op, INPUT, OUTPUT) # RNASeq_PrepHelper
        }
        
        in_collections = operations.map {|op| op.input(INPUT).collection}.uniq
        
        take(in_collections, interactive: true)
        
        out_collections = operations.map {|op| op.output(OUTPUT).collection}.uniq
        
        out_collections.each {|out_coll|
            
            adding_second_strand_mm(out_coll)
            
            incubate_plate_on_thermocycler(out_coll, thermo_template='second_strand_syn')
            
            take([out_coll], interactive: true)
            
            clean_up_cDNA_libraries(out_coll)
            
            eluting_clean_cDNA_libraries(out_coll)
        }
        
        return_first_strand_syn_reagents
        
        operations.store

        return {}
        
    end # main

end # class
