# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

needs "Standard Libs/Units"
module Adenlyate_3_Ends
    include Units
    
    CTA_VOL = 2.5
    ATL_VOL = 12.5
    def gather_and_defrost_adenylate_materials()
        reagents_hash = {
            "A-Tailing Control (CTA)" => "1 tube", #/48rxns
            "A-Tailing Mix (ATL)" => "1 tube", #/48rxns
            "Resuspension Buffer (RSB)" => "1 tube", #/48rxns
        }
        show do
            title "Gather and Defrost Materials"
            separator
            note "Gather the following reagents and defrost at room temperature:"
            reagents_hash.each {|k,v| check "#{k}"}
            note "\n"
            note "Gather the following materials:"
            check "<b>1</b> - Adhesive Seal"
        end
    end
    
    def add_a_tailing_mix(collection)
        sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(collection)
        cta_tot_vol = (collection.get_non_empty.length).round()*2.5
        cta_vol = cta_tot_vol/100
        cta_h2o_vol = cta_tot_vol - cta_vol
        if rc_list.length > 18
            show do
                title "Aliquot A-Tailing Control (CTA) for Multichannel"
                separator
                check "Create #{cta_tot_vol}#{MICROLITERS} of 1:100 CTA => <b>#{cta_h2o_vol}#{MICROLITERS}</b> MG H2O + <b>#{cta_vol}#{MICROLITERS}</b> CTA"
                note "Follow the table to aliquot the A-Tailing Control (CTA) into a stripwell for the next step:"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*2.5}#{MICROLITERS}"}
            end
        else
            show do 
                title "Aliquot A-Tailing Control (CTA)"
                separator
                check "Create #{cta_tot_vol}#{MICROLITERS} of 1:100 CTA => <b>#{cta_h2o_vol}#{MICROLITERS}</b> MG H2O + <b>#{cta_vol}#{MICROLITERS}</b> CTA"
            end
        end
        show do
            title "Adding A-Tailing Control (CTA) to #{collection.id}"
            separator
            note "Follow the table below to aliquot the <b>CTA</b> to the appropriate wells of #{collection.id}:"
            bullet "Mix by pipetting up and down 5 times."
            table highlight_alpha_non_empty(collection){|r,c| "#{CTA_VOL}#{MICROLITERS}"}
        end
        if rc_list.length > 18
            show do
                title "Aliquot A-Tailing Mix (ATL) for Multichannel"
                separator
                check "Give the A-Tailing Mix (ATL) a quick spin down."
                note "Follow the table to aliquot the A-Tailing Mix (ATL) into a stripwell for the next step:"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*ATL_VOL}#{MICROLITERS}"}
            end
        end
        show do
            title "Adding A-Tailing Mix (ATL) to #{collection}"
            separator
            note "Follow the table below to aliquot the <b>ATL</b> to the appropriate wells of <b>#{collection}</b>:"
            bullet "Mix by pipetting up and down 7 times."
            table highlight_alpha_non_empty(collection){|r,c| "#{ATL_VOL}#{MICROLITERS}"}
            check "Seal the plate with a clear adhesive seal, then centrifuge <b>280 x g for 1 min</b>."
        end
        sw.mark_as_deleted
        sw.save
    end
    
    def incubate_adapter_ligation_plate(collection)
        show do
            title "Incubating Adapter Ligation Plate #{collection.id}"
            separator
            check "Place sealed plate on a thermocycler, close lid, and select: <b>A Ligation</b>"
            note "Thermocycler Conditions:"
            bullet "Pre-heat lit to 100°C"
            bullet "37°C for 30 mins"
            bullet "70°C for 5 mins"
            bullet "Hold at 4°C" # Give plate 4°C for 1 min (similar to being on ice for 1 min)
            check "Set a timer for 40 mins"
            note "Continue on to the next step while incubating plate."
        end
    end

    
end # Module Adenlyate_3_Ends# Library code here