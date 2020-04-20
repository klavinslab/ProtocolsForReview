# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18
# °C µl

# Standard Libs
needs "Standard Libs/Debug"
needs "Standard Libs/Units"
needs "Standard Libs/AssociationManagement"

# Tissue Culture Libs
needs "Tissue Culture Libs/CollectionDisplay"

# Illumina NGS Libs
lib_path = "Illumina NGS Libs/"
needs lib_path + "RiboZero_Deplete_Fragment_RNA" 
needs lib_path + "First_Second_cDNA_Synthesis" 
needs lib_path + "Adenlyate_3_Ends" 
needs lib_path + "Ligate_Adapters" 
needs lib_path + "Enrich_cDNA_Fragments" 
needs lib_path + "Normalize_Pool_Libraries"
needs lib_path + "CreateIlluminaAdapterPlate"
needs lib_path + "FindUpdateIlluminaAdapterPlate"

module TruSeqStrandedTotalRNAKit
    
    # Standard Libs
    include Debug, Units, AssociationManagement
    
    # Tissue Culture Libs
    include CollectionDisplay
    
    # Illumina NGS Libs
    include RiboZero_Deplete_Fragment_RNA
    include First_Second_cDNA_Synthesis
    include Adenlyate_3_Ends
    include Ligate_Adapters
    include Enrich_cDNA_Fragments
    include Normalize_Pool_Libraries
    include CreateIlluminaAdapterPlate
    include FindUpdateIlluminaAdapterPlate
    
end # Module TruSeqStrandedTotalRNAKit