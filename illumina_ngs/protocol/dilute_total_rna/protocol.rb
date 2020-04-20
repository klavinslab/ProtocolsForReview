# By Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18
# C µl

needs "RNA/RNA_ExtractionPrep"
needs "Illumina NGS Libs/RNASeq_PrepHelper"
needs "Illumina NGS Libs/TruSeqStrandedTotalRNAKit"


class Protocol
    include RNA_ExtractionPrep
    include RNASeq_PrepHelper
    include TruSeqStrandedTotalRNAKit
    
    
    INPUT = "Total RNA"
    OUTPUT = "Diluted Total RNA Plate"
    
    INPUT_RNA_CONC = 300#ng # TODO: Find right starting concentration for an input so that the enrich fragment step does not over amplify the cDNA library and make it too concentrated
    FINAL_VOL = 10
    
    def main
        operations.make
        
        # Retrieve RNA extracts and let thaw at room temp
        thaw_rna_etracts
        
        # Get ice for following reagents
        get_ice
        
        # Sanatize bench
        sanitize
        
        # Retrieve materials for rRNA depletion and Fragmentation 
        gather_RiboZero_Deplete_Fragment_RNA_materials(operation_type())
        
        normalize_and_fill_rna_plates()
        
        show {note "<b>Put away the following.</b>"}
        operations.store
        return {}
        
    end # Main
    
    
    # Caluculates the volume needed from the RNA sample to meet the desired final concentration
    #
    # @params rna_conc [int] is the concentration of RNA in [ng/ul]
    # @returns rna_dil_vol [int] is the volume of RNA required to meet the desired final conc.
    def dilute_rna(rna_conc)
        r_num = Random.new
        (debug) ? rna_conc = r_num.rand(1000) : rna_conc = rna_conc  # For testing & debugging
        rna_dil_vol = (INPUT_RNA_CONC.to_f/rna_conc.to_f)
        return rna_dil_vol
    end
    
    # Calculates the volume of MG H2O required to meet the desired final RNA conc
    #
    # @params rna_dil_vol [int] is the volume of RNA required to meet the desired final conc.
    # @returns h2o_dil_vol [int] is the volume of water required to meet the desired final conc.
    def dilute_h2o(rna_dil_vol)
        h2o_dil_vol = FINAL_VOL - rna_dil_vol
        if h2o_dil_vol < 0
            return 0
        else
            return h2o_dil_vol
        end
        # (h2o_dil_vol < 0) ? (return 0) : (return h2o_dil_vol)
    end
    
    # Finds all RNA extractions in the job and directs tech to grab them - TODO: Sort by box/location
    def thaw_rna_etracts()
        rna_etracts = operations.map {|op| op.input(INPUT).item}
        take(rna_etracts, interactive: true)
        show do
            title "Thawing Samples"
            separator
            note "Let the RNA Extract(s) thaw at room temperature."
        end
    end
    
    # Directs tech to fill the output collection with the correct item, rna_vol, and water_vol into the appropriate well
    # 
    # out_colleciions [Array of objs] is an array of collection objs that the RNAs will get diluted into
    def normalize_and_fill_rna_plates()
        r_num = Random.new
        
        groupby_out_collection = operations.group_by {|op| op.output(OUTPUT).collection}
        
        groupby_out_collection.each {|out_coll, ops|
            obj_type = ObjectType.find(out_coll.object_type_id)
            ops.each {|op|
                rna_item = op.input(INPUT).item
                rna_item.get(:concentration).nil? ? rna_conc = r_num.rand(1000) : rna_conc = rna_item.get(:concentration)
                op.temporary[:rna_dil_vol] = dilute_rna(rna_conc)
                op.temporary[:h2o_dil_vol] = dilute_h2o(op.temporary[:rna_dil_vol])
            }
            rc_list = ops.map {|op| [op.output(OUTPUT).row, op.output(OUTPUT).column]}
            item_matrix = ops.map {|op| op.input(INPUT).item.id}.each_slice(obj_type.columns).map {|slice| slice}
            rna_vol_matrix = ops.map {|op| op.temporary[:rna_dil_vol]}.each_slice(obj_type.columns).map {|slice| slice}
            h2o_vol_matrix = ops.map {|op| op.temporary[:h2o_dil_vol]}.each_slice(obj_type.columns).map {|slice| slice}
            log_info 'rna_vol_matrix',rna_vol_matrix,'h2o_vol_matrix',h2o_vol_matrix
            
            show do
                title "Gather Material(s)"
                separator
                check "Gather a #{obj_type.name} and label <b>#{out_coll.id}</b>"
            end
            
            tot_h2o_vol = 0
            h2o_vol_matrix.flatten.each {|vol| tot_h2o_vol += vol}
            show do
                title "Fill #{obj_type.name} #{out_coll} with MG H2O"
                separator
                check "For the next steps you will need #{(tot_h2o_vol + 20.0).round(2)}#{MICROLITERS}"
            end
            
            show do
                title "Fill #{obj_type.name} #{out_coll} with MG H2O"
                separator
                note "Follow the table below to fill the plate:"
                table highlight_alpha_rc(out_coll, rc_list) { |r, c| "#{h2o_vol_matrix[r][c].round(1)}#{MICROLITERS}" }
            end
            
            fill_by_row = rc_list.group_by {|r,c| r}.sort
            fill_by_row.each { |row, rc_list|
                show do
                    title "Fill #{obj_type.name} #{out_coll} with RNA [#{INPUT_RNA_CONC/FINAL_VOL}#{NANOGRAMS}/#{MICROLITERS}]"
                    separator
                    table highlight_alpha_rc(out_coll, rc_list) { |r, c| "#{item_matrix[r][c]}\n#{rna_vol_matrix[r][c].round(1)}#{MICROLITERS}" }
                end
            }
        }
        show do
            title "Centrifuge Plate(s)"
            separator
            note "Use the large centrifuge with the the plate rotor"
            check "Spin plate(s) at <b>500 x g</b> for <b>1 min</b> to collect everything into the well."
        end
    end
end #Class
