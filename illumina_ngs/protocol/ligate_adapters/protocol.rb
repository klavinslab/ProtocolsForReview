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
    INPUT = "Adenylated cDNA Library"
    OUTPUT = "Indexed DNA Library"
    
    # Parameter
    ADAPTER_PLATE = "Illumina Adapter Plate"

    def intro(sample_type)
        show do
            title "Ligate Adapters"
            separator
            note "This protocol ligates indexing adapters to the ends of the ds cDNA, preparing them for hybridization onto a flow cell. This allows researcher to distiguish cDNA libraries from individual samples."
            note "<b>1.</b> Prepare each sample with ligation mix."
            note "<b>2.</b> Incubate cDNA libraries to ligate Index/Adapters."
            note "<b>3.</b> Use beads to throughly remove non-indexed cDNA library fragments."
        end
    end
    
    def main
        # ISSUE: This .makes concatenates all input parts into an output collection
        
        operations.make
        
        yeast_rna_seq_libs_ops = operations.map {|op| op }.select {|op| 
            op.input(INPUT).sample_type.name == 'Yeast Strain'
        }
        log_info 'yeast_rna_seq_libs_ops', yeast_rna_seq_libs_ops
        # cDNA is coming from Yeast Strain samples
        
        if !yeast_rna_seq_libs_ops.empty?
            
            sample_type = yeast_rna_seq_libs_ops.map {|op| op.input(INPUT).sample_type.name}.uniq.first
            intro(sample_type)
            
            index_plate_type = yeast_rna_seq_libs_ops.map {|op| op.input(ADAPTER_PLATE).val}.uniq.first
            
            gather_and_defrost_ligate_adapters_materials(
                num_ops=yeast_rna_seq_libs_ops.length, 
                operation_type(), 
                index_plate_type=index_plate_type
            )
            
            in_out_collection_hash = Hash.new()
            yeast_rna_seq_libs_ops.map {|op| 
                in_out_collection_hash[op.input(INPUT).collection] = op.output(OUTPUT).collection
            }
            
            in_out_collection_hash.each {|in_coll, out_coll|
                take([in_coll], interactive: true)
                add_ligation_mix(in_coll)
                add_adapters_from_adapter_plate(in_coll, out_coll, index_plate_type)
                incubate_adapter_ligation_plate(in_coll)
                add_stop_ligation_buffer(in_coll)
                clean_up_indexed_cDNA(in_coll, sample_type)
                final_elution(in_coll, out_coll)
            }
        end
        
        amplified_cDNA_libs_ops = operations.map {|op| op }.select {|op| 
            op.input(INPUT).sample_type.name == 'DNA Library'
        }
        if !amplified_cDNA_libs_ops.empty?
            sample_type = amplified_cDNA_libs_ops.map {|op| op.input(INPUT).sample_type.name}.uniq.first
            intro(sample_type)
            
            index_plate_type = amplified_cDNA_libs_ops.map {|op| op.input(ADAPTER_PLATE).val}.uniq.first
            
            in_out_collection_hash = Hash.new()
            amplified_cDNA_libs_ops.map {|op| 
                in_out_collection_hash[op.input(INPUT).collection] = op.output(OUTPUT).collection
            }
            
            gather_nano_adapter_ligation_materials(amplified_cDNA_libs_ops.length)
            in_out_collection_hash.each {|in_coll, out_coll|
                take([in_coll], interactive: true)
                add_nano_ligation_mix(Collection.find(in_coll.id)) # DNA_NanoLigation
                add_adapters_from_adapter_plate(in_coll, out_coll, index_plate_type)
                incubate_adapter_ligation_plate(in_coll)
                add_stop_ligation_buffer(in_coll)
                clean_up_indexed_cDNA(in_coll, sample_type)
                final_elution(in_coll, out_coll)
            }
        end
        
        operations.store
        
        return {}
        
    end # Main

end # Class
