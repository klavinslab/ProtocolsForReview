# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

module QPCR_Constants
    
    # qPCR_RoutingTrackingLib Constants
    QPCR_STANDARD_CURVE_RANGE = [400.0, 40.0, 4.0, 0.4, 0.04, 0.004, 0.0004, 0.0]
    PHIX_STOCK_CONC = 4.0 # Change to 4.0 once 4.0nM stocks are created and placed in Aq
    
    # qPCR_ThermocyclerLib Constants
    QPCR_THERMO_CONDITIONS = "illumina_qPCR_quantification_v1.prcl"
    QPCR_THERMO_PLATE_LAYOUT = "illumina_qPCR_plate_layout_v1.pltd"
    EXPERIMENTAL_FILEPATH = "/Desktop/_qPCR_UWBIOFAB"
    EXPORT_FILEPATH = "Desktop/BIOFAB qPCR Exports" 

    
end # Module QPCR_Constants