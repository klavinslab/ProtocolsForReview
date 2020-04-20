# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

needs "Illumina NGS Libs/RNASeq_PrepHelper"
needs "Illumina NGS Libs/TruSeqStrandedTotalRNAKit"

class Protocol
    
    # include Debug
    # include CollectionDisplay
    include RNASeq_PrepHelper
    include TruSeqStrandedTotalRNAKit
    
    # DEF
    INPUT = "Diluted Total RNA"
    OUTPUT = "Depleted RNA Frags"


# TODO: Gather cDNA synthesis materials
    def intro()
        show do
            title "Introduction - Illumina RNA Seq Library Prep"
            separator
            note "This is the first step in the: <a href=https://support.illumina.com/downloads/truseq_stranded_total_rna_sample_preparation_guide_15031048.html>Illumina TruSeq Stranded Total RNA with RiboZero Guide</a>"
            note "In this protocol, you will be depleting the abundant ribosomal RNA from your sample."
            note "Then, you will be chemically fragmenting the depleted RNA, since the Illumina platform is optimized for short reads."
            note "<b>1.</b> Deplete riboRNA"
            note "<b>2.</b> Isolate & Wash Depleted RNA"
            note "<b>3.</b> Chemically Fragment RNA"
        end
    end

    def main
        
        intro
        
        operations.retrieve.make
        
        gather_RiboZero_Deplete_Fragment_RNA_materials
        
        gather_First_Second_cDNA_Synthesis_materials(operation_type())
        
        make_bind_rRNA_plate(INPUT)
        
        incubate_bind_rRNA_plate
        
        make_rRNA_removal_plate(INPUT, OUTPUT)
        
        # Cleans riboRNA depleted RNA and creates RNA Fragmenting plate ready for the thermocycler
        clean_up_rna_clean_up_plate(OUTPUT)
        
        incubate_depleted_RNA_fragment_plate()
        
        operations.store
        
        return {}
        
    end # Main

end # Class
