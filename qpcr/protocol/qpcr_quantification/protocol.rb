# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18
#
# This protocol should walk someone through setting up the workspace on the qPCR Thermocycler.
# The input collection has a 'q_colls_used' association to find which q_colls are used to quantify the cDNA libs from input_collection

needs "Standard Libs/Debug"
needs "qPCR/qPCR_QuantificationLib"
needs "qPCR/qPCR_ThermocyclerLib"

class Protocol
    include Debug
    include AbsoluteQuantification
    include QPCR_ThermocyclerLib
    
    # DEF
    INPUT = "Indexed DNA Library"

    def intro()
        show do
            title 'Quantification of cDNA Libraries via qPCR'
            separator
            note "<a target=\"_blank\" rel=\"noopener noreferrer\" href=\"https://support.illumina.com/content/dam/illumina-support/documents/documentation/chemistry_documentation/qpcr/sequencing-library-qpcr-quantification-guide-11322363-c.pdf\" target=_blank>  Illumina Sequencing Library qPCR Quantification Guide</a> "
            note "This protocol will guide you through the process to quantify the concentration of Indexed cDNA in each cDNA library."
            note "The qPCR method uses flourescence of a PCR reaction across thermocycler cycles to determine the concentration of the starting material in the reaction"
            note "<b>1.</b> Setup the qPCR workspace on the BioRad Thermocycler."
            note "<b>2.</b> Run thermocycler."
            note "<b>3.</b> Export qPCR run data."
            note "<b>4.</b> Upload qPCR run data."
        end
    end
    
    def main
        
        intro()
        
        groupby_in_items = operations.group_by {|op| op.input(INPUT).item}
        
        groupby_in_items.each {|in_item, ops|
            
            if debug
                in_item = Item.find(359386)
                
            end
            
            q_colls_used = in_item.get('q_colls_used')
            
            # For each q_colls_used direct tech to setup the qPCR workspace
            q_colls_used.each {|q_coll_id|
            
                # Set up qPCR template and filenames
                experiment_name = setup_biorad_qpcr_thermocycler_workspace(q_coll_id)
                
                # After assay is finished upload files necessary to measure Cq
                export_qpcr_measurements(experiment_name)
                
                qpcr_upload = uploading_qpcr_measurments(experiment_name)
                
                # Calculates in rxn starting quantities and updates qpcr_trackin_matrix 
                sq_conc_hash = qpcr_quantification(q_coll_id, qpcr_upload)
                
                # Calculate input dna library concentration and create matrix to associate to input collection for downstream use
                calculate_input_sample_concentrations(sq_conc_hash)
                
                Collection.find(q_coll_id).mark_as_deleted
                
            }
        }
        {}
    end # Main
end # Class


