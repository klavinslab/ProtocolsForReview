# By:Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18
# C l

# This protocol is to be used to quantify an Illumina TruSeq cDNA Prep
# 
# What this protocol needs to overcome
# Stanardize Standard Curve for experiment - Currently using PhiX dilutions and amplifying with Illumina qPCR Primers (Standard Primers)
# Track where each sample will go on collections generated for the qPCR instrument
# Produce triplicates for each experimental sample that will be quantified
# Direct tech to place samples in the correct well and plate (how to make this easy)
# Direct tech to interact with the qPCR instrument and run templates or customized plate layouts
# Upload files generated by the qPCR instrument (csv format?)
# Parse measurement files to obtain standard curve, Ave Cq scores for replicates, and finally calculate concentration based on the standard curve generated 
# Then associate information about the qPCR measurement Cq score, calculated concentration, standard curve function, (place into ngs_tracking_matrix)

needs "Standard Libs/Debug"
needs "RNA/StaRNAdard Lib"
needs "qPCR/qPCR_PreparationLib"
needs "qPCR/qPCR_RoutingTrackingLib"

class Protocol
    include Debug
    include StaRNAdard_Lib
    include QPCR_Preparation
    include QPCR_RoutingTrackingLib 
    
    # DEF
    INPUT = 'Indexed DNA Library'
    OUTPUT = 'Indexed DNA Library'
    
    # Constants
    EXP_REPLICATES = 3
    
    def intro()
        show do
            title 'Quantification of cDNA Libraries via qPCR'
            separator
            # Online Illumina PDF Guide
            note "<a target=\"_blank\" rel=\"noopener noreferrer\" href=\"https://support.illumina.com/content/dam/illumina-support/documents/documentation/chemistry_documentation/qpcr/sequencing-library-qpcr-quantification-guide-11322363-c.pdf\" target=_blank>  Illumina Sequencing Library qPCR Quantification Guide</a> "
            
            note "This protocol will guide you through the process to quantify the concentration of Indexed cDNA in each cDNA library."
            note "The qPCR method uses flourescence of a PCR reaction across thermocycler cycles to determine the concentration of the starting material in the reaction"
            note "<b>1.</b> Create qPCR master mix with flourescence dye."
            note "<b>2.</b> Create Concentration Standard Curve dilutions from a control library or Illumina PhiX Control."
            note "<b>3.</b> Dilute Indexed cDNA libraries so they are in the assay's linear range (1:10,000 in qPCR rxn)."
            note "<b>4.</b> Prepare 96 Well qPCR plates & reactions to assess the concentration of the Indexed cDNA libraries."
        end
    end

    def main
        
        # Allows for the operation to pass the the collection/item with the same item_id
        operations.each {|op|
            collections_pass(op, INPUT, OUTPUT) # "RNA/StaRNAdard Lib"
        }
        
        # intro
        intro()
        
        # Sanitize & Prep
        general_sanitize()
        get_ice(cool_centrifuge=true)
        
        # Gather materials
        total_rxns, num_qpcr_plates = gather_qpcr_materials()
        
        # Gather master mix reagents
        master_mix_reagents_hash = gather_master_mix_materials(total_rxns)
        
        # Create standard curve Dilutions 
        create_qpcr_standard_curve()
        
        # Direct tech to perform a 1:1,000 dilution of each of the cDNA libraries in the input collection
        dilute_cDNA_libraries_to_linear_range(INPUT)
        
        # Create master mix
        create_qpcr_master_mix(master_mix_reagents_hash)
        
        # Now I want to produce a qPCR 96 well collection (white) for each set of 24 samples or 72 rxns
        qpcr_collections = create_qpcr_plates_w_std_curve(total_rxns, num_qpcr_plates)
        
        # Create a hash that represents input_collection samples being transferred to qPCR collections
        qpcr_transfer_hash = create_transfer_mapping(INPUT, EXP_REPLICATES, qpcr_collections.map(&:clone)) # use copy of qpcr_collections
        
        # Fill plates with information then use info from each collection to direct the preparation of the qpcr_plates
        transfer_and_track_samples(qpcr_transfer_hash)
        direct_tech_to_transfer_diluted_cdna(qpcr_transfer_hash)
        
        centrifuge_qpcr_plates(qpcr_collections)
    end # Main
    
end # Class Protocol
