# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

needs "Standard Libs/Units"
module First_Second_cDNA_Synthesis
    include Units
    
    # ul per rxn/op
    FSA_VOL = 7.2
    REV_TRANS_VOL = 0.8
    CTE_VOL = 5
    SSM_VOL = 20
    AMP_BEAD_VOL = 90
    EtOH_80_VOL = 400
    RSB_VOL = 17.5
    
    # So far only first strand materials have been added 080718 - 1pm
    def gather_First_Second_cDNA_Synthesis_materials(op_type=nil)
        # Gather all materials and describe how much volume from each they will need for the following steps
        num_ops = operations.length
        # FSA and SSIIRev are at a 9:1 ratio, plus the total vol added is 8ul so 7.2:0.8
        reagents_hash = {
            "First Strand Synthesis Act D Mix (FSA)" => reagent_vol_with_extra(num_ops, FSA_VOL),
            "SuperScript II Reverse Transcriptase" => reagent_vol_with_extra(num_ops, REV_TRANS_VOL),
            "End Repair Control (CTE) 1:50" => reagent_vol_with_extra(num_ops, CTE_VOL),
            "Second Strand Marking Master Mix (SMM)" => SSM_VOL # Vol zero for this portion of the protocol
        }
        
        second_reagents_hash = {
            "AMPure XP Beads" => reagent_vol_with_extra(num_ops, AMP_BEAD_VOL),
            "Freshly Prepared 80% Ethanol (EtOH)" => reagent_vol_with_extra(num_ops, EtOH_80_VOL)
        }
        
        room_temp = { qty:25, units:"#{DEGREES_C}"}
        
        if !op_type.nil?
            case op_type.name
            when "rRNA Deplete and Fragment RNA"
                show do
                    title "Gather the following materials for the protocol after this one"
                    separator
                    note "Let the following reagents thaw at room temperature:"
                    second_reagents_hash.each {|k,v| check "#{k}"}
                    check "Make 80% EtOH => #{second_reagents_hash["Freshly Prepared 80% Ethanol (EtOH)"] * 0.8}#{MICROLITERS} of 100% EtOH + #{second_reagents_hash["Freshly Prepared 80% Ethanol (EtOH)"] * 0.2}#{MICROLITERS} of MG H2O"
                    note "Let the following reagents thaw on ice until future use:"
                    reagents_hash.each {|k,v| check "#{k}"}
                end
            end
        else
            show do
                title "Gather the following materials:"
                separator
                note "Let the following reagents thaw at #{qty_display(room_temp)}"
                reagents_hash.each {|k, v| (check "<b>#{v}ul</b> of #{k}")}
                check "<b>5</b> - Adhesive Seals"
                check "<b>2</b> - 96 Well MIDI 0.8mL Plate(s)"
            end
        end
    end
   
    def make_first_strand_syn_act_D_master_mix()
        show do
            title "Create 1st Strand Synthesis Act D Master Mix (FSA)"
            separator
            warning "First Strand Synthesis Act D Mix contains Actinomycin D, a toxin."
            check "Gather a 1.5mL microfuge tube and label: <b>FSA MM</b>"
            check "<b>In the fumehood</b>, Mix First Strand Synthesis Act D Mix (FSA) and SSII Rev. Transcriptase"
            bullet "Mix throughly by pipetting <b>DO NOT VORTEX</b>"
        end
    end
    
    def adding_first_strand_synthesis_act_D(collection)
        sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(collection)
        if rc_list.length > 18
            show do
                title "Aliquot FSA MM for Multichannel"
                separator
                check "Gather a new, clean 12-Well Stripwell"
                note "Follow the table to aliquot the FSA MM into a stripwell for the next step:"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*(FSA_VOL+REV_TRANS_VOL)}#{MICROLITERS}"}
            end
        end
        show do
            title "Fragmenting Depleted RNA"
            separator
            note "Follow the table below to aliquot the <b>FSA Master Mix</b> to the appropriate wells of #{collection}:"
            bullet "Use a multichannel where possible"
            bullet "Mix by pipetting up and down 5 times."
            table highlight_alpha_non_empty(collection){|r,c| "#{FSA_VOL+REV_TRANS_VOL}#{MICROLITERS}"}
            check "Seal the plate with a clear adhesive seal."
        end
        sw.mark_as_deleted
        sw.save
    end
    

    def incubate_plate_on_thermocycler(out_coll, thermo_template='first_strand_syn')
        case thermo_template 
        when 'first_strand_syn'
            show do
              title "Incubate Plate <b>#{out_coll}</b> on Thermocycler"
              separator
                check "Place sealed plate on a thermocycler, close lid, and select: <b>Synthesize 1st Strand</b>"
                note "Thermocycler Conditions:"
                bullet "Pre-heat lid to 100°C"
                bullet "25°C for 10 mins"
                bullet "24°C for 15 mins"
                bullet "70°C for 15 mins"
                bullet "Hold at 4°C"
                note "<b>If there are no available thermocyclers place plate on ice until ready!</b>"
                check "Once plate is incubating, place a <b>40 minute timer</b>"
            end
        when 'second_strand_syn'
            show do 
                title "Incubate Plate <b>#{out_coll}</b> on Thermocycler"
                separator
                check "Place sealed plate on a thermocycler, close lid, and select: <b>Synthesize 2nd Strand</b>"
                note "Thermocycler Conditions:"
                bullet "16°C for 1 hour"
                check "Place timer and let Lab Manager know if you will not be here to continue."
            end
        else 
            show do
                title "Incubate Plate <b>#{out_coll}</b> on Thermocycler"
                separator
                warning "No thermocycler template was found"
            end
        end
        out_coll.location = "Thermocycler"
        out_coll.save
    end
    
    def return_first_strand_syn_reagents()
        show do
            title "Return First Strand Synthesis Reagents"
            separator
            check "Return <b>First Strand Synthesis Act D Mix (FSA)</b> to -20°C Freezer"
            check "Return <b>SuperScript II Reverse Transcriptase</b> to -20°C Freezer"
        end
    end
    
    # Second strand Functions/Show blocks
    
    def adding_second_strand_mm(out_coll)
        sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(out_coll)
        cte_tot_vol = (out_coll.get_non_empty.length).round()*CTE_VOL
        cte_vol = cte_tot_vol/50.0 # 1:50 dilution
        cte_h2o_vol = cte_tot_vol - cte_vol
        if rc_list.length > 18
            show do
                title "Aliquot End Repair Control (CTE) for Multichannel"
                separator
                check "Gather a new, clean 12-Well Stripwell."
                check "Create #{cte_tot_vol}#{MICROLITERS} of 1:50 CTE => #{cte_h2o_vol}#{MICROLITERS} MG H2O + #{cte_vol}#{MICROLITERS} CTE"
                note "Follow the table to aliquot the End Repair Control (CTE) into a stripwell for the next step:"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*CTE_VOL}#{MICROLITERS}"}
            end
        end
        show do
            title "Adding End Repair Control to <b>#{out_coll}</b>"
            separator
            note "Follow the table below to aliquot the <b>End Repair Control</b> to the appropriate wells of <b>#{out_coll}</b>:"
            bullet "Mix by pipetting up and down 5 times."
            table highlight_alpha_non_empty(out_coll){|r,c| "#{CTE_VOL}#{MICROLITERS}"}
        end
        if rc_list.length > 18
            show do
                title "Aliquot Second Strand Master Mix (SMM) for Multichannel"
                separator
                check "Gather a new, clean 12-Well Stripwell."
                check "Give the Second Strand MM a quick spin down."
                note "Follow the table to aliquot the SMM into a stripwell for the next step:"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*SSM_VOL}#{MICROLITERS}"}
            end
        end
        show do
            title "Adding Second Strand Master Mix (SMM) to #{out_coll.id}"
            separator
            note "Follow the table below to aliquot the <b>SMM</b> to the appropriate wells of <b>#{out_coll}</b>:"
            bullet "Mix by pipetting up and down 5 times."
            table highlight_alpha_non_empty(out_coll){|r,c| "#{SSM_VOL}#{MICROLITERS}"}
            check "Seal the plate with a clear adhesive seal."
        end
        sw.mark_as_deleted
        sw.save
    end
    
    def clean_up_cDNA_libraries(collection)
        # Coming from thermocycler
        collection.location = "Bench"
        collection.save
        
        sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(collection)
        if rc_list.length > 18
            show do
                title "Aliquot AMPure XP Beads for Multichannel"
                separator
                check "Vortex beads vigorously until well dispersed"
                check "Gather a new, clean 12-Well Stripwell."
                note "Follow the table to aliquot the AMPure XP Beads into a stripwell for the next step:"
                bullet "The maximum volume in a stripwell well is 300#{MICROLITERS}"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*AMP_BEAD_VOL}#{MICROLITERS}"}
            end
        end
        show do
            title "Create new cDNA Clean Up Plate (CCP)"
            separator
            check "Gather a new, clean 96 Well MIDI 0.8mL Plate and label: <b>CCP_#{collection}</b>"
            note "Follow the table below to aliquot the <b>AMPure XP Beads</b> to the appropriate wells:"
            table highlight_alpha_non_empty(collection){|r,c| "#{AMP_BEAD_VOL}#{MICROLITERS}"}
            note "Continue on to the next step to transfer cDNA libraries to new plate."
        end
        show do
            title "Transferring cDNA libraries"
            separator
            check "Transfer the entire contents from each well of plate <b>#{collection}</b> to the corresponding well of <b>CCP_#{collection}</b>"
            bullet "Mix by pipetting 7 times to mix throughly"
            check "Seal the plate with a clear adhesive seal."
            check "Incubate at room temperature for 15 mins."
        end
        show do
            title "cDNA Clean Up Plate <b>#{collection}</b> (CCP)"
            separator
            check "Centrifuge plate to 280 x g for 1 min."
            check "Place the CCP plate on the magnetic stand at room temperature for 5 mins."
            bullet "Place on plate rotator to ensure all beads are bound to the side the well."
        end
        show do
            title "Aliquoting 80% Ethanol"
            separator
            check "Aliquot freshly prepared 80% EtOH into a new clean multichannel reservoir."
        end
        show do
            title "Washing cDNA Clean Up Plate <b>#{collection}</b> (CCP)"
            separator
            note "<b>KEEP PLATE ON MAGNETIC STAND FOR THE FOLLOWING STEPS</b>"
            check "Without disturbing the beads, remove and discard <b>135#{MICROLITERS}</b> of supernatant from each well of the <b>CCP_#{collection}</b>"
        end
        wash = 1
        (2).times do
            show do
                title "Washing cDNA Clean Up Plate <b>#{collection}</b> (CCP) (#{wash}/2)"
                separator
                note "<b>KEEP PLATE ON MAGNETIC STAND FOR THE FOLLOWING STEPS</b>"
                note "Follow the table below to aliquot the <b>80% EtOH</b> to the appropriate wells:"
                table highlight_alpha_non_empty(collection){|r,c| "#{200}#{MICROLITERS}"}
                check "Incubate the CCP plate at room temperature for 30 seconds, and then remove and discard all of the supernatant from each well."
                bullet "DO NOT DISTURB THE BEADS PELLET"
            end
            wash += 1
        end 
        show do 
            title "cDNA Clean Up Plate (CCP)"
            separator
            check "Finally, place an <b>Aera Breathable Seal</b> on the plate and let dry for 15 mins."
            bullet "Place plate on plate rotator to expedite and ensure drying."
            note "Continue on to the next step while bead pellets are drying."
        end
        sw.mark_as_deleted
        sw.save
    end
    
    def eluting_clean_cDNA_libraries(collection)
        sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(collection)
        if rc_list.length > 18
            show do
                title "Aliquot Resuspension Buffer (RSB) for Multichannel"
                separator
                check "Gather a new, clean 12-Well Stripwell."
                check "Centrifuge the thawed, room temperature Resuspension Buffer to 600 × g for 5 seconds"
                note "Follow the table to aliquot the Resuspension Buffer (RSB) into a stripwell for the next step:"
                bullet "The maximum volume in a stripwell well is 300#{MICROLITERS}"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*RSB_VOL}#{MICROLITERS}"}
            end
        end
        show do
            title "Eluting Clean cDNA Libraries"
            separator
            note "Follow the table below to aliquot the <b>Resuspension Buffer (RSB)</b> to the appropriate wells of <b>#{collection}</b>:"
            table highlight_alpha_non_empty(collection){|r,c| "#{RSB_VOL}#{MICROLITERS}"}
            check "Finally, seal the plate with a clear adhesive seal, then place on plate shaker at <b>~1000rpm for 2 mins</b>."
        end
        show do
            title "Eluting Clean cDNA Libraries #{collection}"
            separator
            check "Incubate <b>CCP_#{collection}</b> for 2 mins at room temperature"
            check "Next, centrifuge plate at 208 x g for 1 min"
            check "Finally, place plate on magnetic stand and on plate rotator for 5 mins."
            note "Continue on to the next step while incubating plate."
        end
        show do
            title "Transferring cDNA Libraries"
            separator
            note "<b>KEEP CCP_#{collection} PLATE ON MAGNETIC STAND FOR THE FOLLOWING STEPS</b>"
            check "Gather a new, clean 96 Well PCR Plate and label: <b>#{collection}</b>"
            check "Transfer <b>15#{MICROLITERS}</b> of supernatant (cDNA) from the <b>CCP_#{collection}</b> to the corresponding wells of the new <b>#{collection}</b> plate."
            check "Finally, seal the plate with a clear adhesive seal, then place on plate at <b>-20°C RNA Seq Staging</b>"
        end
        sw.mark_as_deleted
        sw.save
        # Storing cDNA Libs plate that is ready to be Adenlyated 
        collection.location = '-20°C RNA Seq Staging'
        collection.save
    end

    def return_first_strand_syn_reagents()
        show do
            title "Cleaning Up..."
            separator
            check "Before finishing, clean up bench and return reagents to the appropriate temperature."
        end
    end
    
end # Module First_Second_cDNA_Synthesis


