# By: Eriberto Lopez 08/07/18
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
    INPUT = "Depleted RNA Frags Plate"
    OUTPUT = "First Strand cDNA Library"
    
    def intro()
        show do
            title "Synthesize First Strand cDNA"
            separator
            note "This protocol reverse transcribes RNA Fragments that were primed with random hexamers into the first strand cDNA."
            note "<b>1.</b> Gather thawed reagents and Reverse Transcriptase."
            note "<b>2.</b> Make a Master Mix and apply to each well in the input plate."
            note "<b>3.</b> Incubate plate on pre-programmed thermocycler."
        end
    end
    
    def main
        
        intro
        
        # Allows for the operation to pass the the collection/item with the same item_id
        operations.each {|op|
            collections_pass(op, INPUT, OUTPUT) # RNASeq_PrepHelper
        }
        
        gather_First_Second_cDNA_Synthesis_materials
        
        make_first_strand_syn_act_D_master_mix
        
        in_collections = operations.map {|op| op.input(INPUT).collection}.uniq
        
        take(in_collections, interactive: true)
        
        out_collections = operations.map {|op| op.output(OUTPUT).collection}.uniq
        
        out_collections.each {|out_coll|
            adding_first_strand_synthesis_act_D(out_coll)
            incubate_plate_on_thermocycler(out_coll)
        }
        
        return_first_strand_syn_reagents
        
        # operations.store
        return {}
        
    end # main

end # class
