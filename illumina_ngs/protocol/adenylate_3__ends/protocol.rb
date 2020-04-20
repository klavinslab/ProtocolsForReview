# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18
# °C µl

needs "RNA/RNA_ExtractionPrep"
needs "Illumina NGS Libs/RNASeq_PrepHelper"
needs "Illumina NGS Libs/TruSeqStrandedTotalRNAKit"
needs "Illumina NGS Libs/TruSeqDNANanoLPKit"


class Protocol
    include RNA_ExtractionPrep
    include RNASeq_PrepHelper
    include TruSeqStrandedTotalRNAKit 
    include DNA_NanoLigation # TruSeqDNANanoLPKit
    
    # DEF
    INPUT = "cDNA Library"
    OUTPUT = "Adenylated cDNA Library"
    
    def intro(sample_type)
        show do
            title "Adenylate 3' Ends"
            separator
            note "A single ‘A’ nucleotide is added to the 3’ ends of the blunt fragments to prevent them from ligating to one another during the adapter ligation reaction."
            note "A corresponding single ‘T’ nucleotide on the 3’ end of the adapter provides a complementary overhang for ligating the adapter to the fragment."
            note "This strategy ensures a low rate of chimera (concatenated template) formation."
            if sample_type == 'Yeast Strain'
                note "<b>1.</b> Add A-Tailing Mix & and Control A-Tailing Mix to each sample."
                note "<b>2.</b> Incubate on thermocycler."
            else # DNA Library input
                note "<b>1.</b> Repair ends and create blunt-end fragments."
                note "<b>2.</b> Add A-Tailing Mix to each sample."
                note "<b>3.</b> Incubate on thermocycler."
            end
        end
    end
    
    def main
        
        # Allows for the operation to pass the the collection/item with the same item_id
        operations.each {|op| collections_pass(op, INPUT, OUTPUT)} # RNASeq_PrepHelper
        
        amplified_cDNA_libs_ops = operations.map {|op| op }.select {|op| op.input(INPUT).sample_type.name == 'DNA Library'}
        amplified_cDNA_libs_ops = Operation.find([178819, 178820]) if debug
        
        yeast_rna_seq_libs_ops = operations.map {|op| op }.select {|op| op.input(INPUT).sample_type.name == 'Yeast Strain'}
        
        get_ice(cool_centrifuge=false)
        
        # cDNA is coming from Yeast Strain samples
        if !yeast_rna_seq_libs_ops.empty?
            sample_type = yeast_rna_seq_libs_ops.map {|op| op.input(INPUT).sample_type.name}.uniq.first
            intro(sample_type)
            gather_and_defrost_adenylate_materials
            out_collections = yeast_rna_seq_libs_ops.map {|op| op.output(OUTPUT).collection}.uniq
            out_collections.each {|out_coll|
                add_a_tailing_mix(out_coll)
                incubate_adapter_ligation_plate(out_coll)
                out_coll.location = 'Thermocycler'
                out_coll.save
            }
            num_ops = yeast_rna_seq_libs_ops.length
            gather_and_defrost_ligate_adapters_materials(num_ops, operation_type())
        end
        
        # cDNA is coming from Pre-amplified DNA Library samples - TruSeqDNANanoLPKit
        if !amplified_cDNA_libs_ops.empty?
            
            # sample_type = amplified_cDNA_libs_ops.map {|op| op.input(INPUT).sample_type.name}.uniq.first
            intro('DNA Library')
            gather_dna_nano_adenylation_materials(amplified_cDNA_libs_ops.length)
            converting_to_blunt_ends(amplified_cDNA_libs_ops)
            input_collections = amplified_cDNA_libs_ops.map {|op| op.input(INPUT).collection}.uniq
            output_collections = amplified_cDNA_libs_ops.map {|op| op.output(OUTPUT).collection}.uniq
            input_collections.zip(output_collections) do |in_collection, output_collection|
                clean_up_blunt_end_fragments(in_collection)
                eluting_blunt_end_fragments(in_collection, output_collection)
            end
            add_dna_nano_a_tailing_mix(amplified_cDNA_libs_ops)
            defrost_nano_adapter_ligation_materials()
        end
        return {}
    end # main



end # Class
