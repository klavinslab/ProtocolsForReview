# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

needs "Standard Libs/Units"
module RiboZero_Deplete_Fragment_RNA
    include Units
    
    # ul per op/sample
    EPH_VOL = 8.5 
    ELB_VOL = 11
    RRM_VOL = 5
    RSB_VOL = "1 tube" # is only necessary for this experiment
    RBB_VOL = 5
    RRB_VOL = 35
    EtOH_70 = 200
    RNA_XP_BEADS = 99
    
    def gather_RiboZero_Deplete_Fragment_RNA_materials(op_type=nil)
        # Gather all materials and describe how much volume from each they will need for the following steps
        num_ops = operations.length
        reagents_hash = {
            "Elute, Prime, Fragment High Mix <b>(EPH)</b>" => reagent_vol_with_extra(num_ops, EPH_VOL),#ul
            "Elution Buffer <b>(ELB)</b>" => reagent_vol_with_extra(num_ops, ELB_VOL),#ul
            "rRNA Removal Mix <b>(RRM)</b>" => reagent_vol_with_extra(num_ops, RRM_VOL),#ul
            "Resuspension Buffer <b>(RSB)</b>" => RSB_VOL,
            "rRNA Binding Buffer <b>(RBB)</b>" => reagent_vol_with_extra(num_ops, RBB_VOL),#ul
            "rRNA Removal Beads <b>(RRB)</b>" => reagent_vol_with_extra(num_ops, RRB_VOL),#ul
            "70% Ethanol" => reagent_vol_with_extra(num_ops, EtOH_70),#ul
            "RNAClean XP Beads" => reagent_vol_with_extra(num_ops, RNA_XP_BEADS)
        }
        room_temp = { qty:25, units:"#{DEGREES_C}"}
        if op_type == "Dilute Total RNA"
            show do
                title "Gather the Following Materials for the Protocol After This One"
                separator
                note "Let the following reagents thaw at #{qty_display(room_temp)}:"
                reagents_hash.each {|k,v| check "#{k}"}
                check "Make 70% EtOH => #{reagents_hash["70% Ethanol"] * 0.7}µl of 100% EtOH + #{reagents_hash["70% Ethanol"] * 0.3}#{MICROLITERS} of MG H2O"
            end
        else
            show do
                title "Gather the Following Materials:"
                separator
                note "Let the following reagents thaw at #{qty_display(room_temp)}"
                reagents_hash.each {|k, v| (k == "Resuspension Buffer <b>(RSB)</b>") ? (check "<b>#{v}</b> of #{k}") : (check "<b>#{v}ul</b> of #{k}")}
                check "Make 70% EtOH => #{reagents_hash["70% Ethanol"] * 0.7}µl of 100% EtOH + #{reagents_hash["70% Ethanol"] * 0.3}#{MICROLITERS} of MG H2O"
                check "<b>2</b> - 96 Well PCR Plate(s)"
                check "<b>2</b> - 96 Well MIDI 0.8mL Plate(s)"
                check "<b>5</b> - Adhesive Seals"
            end
        end
    end
    
    def make_bind_rRNA_plate(input_def)
        in_collections = operations.map {|op| op.input(input_def).collection}.uniq
        in_collections.each {|in_coll|
            sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(in_coll)
            show do
                title "rRNA Binding Master Mix"
                separator
                check "Mix the <b>RBB Aliquot</b> & <b>RRM Aliquot</b> together by pipetting."
                check "Gather a clean new 12-Well Stripwell."
                check "Follow the table below to aliquot the master mix to a stripwell:"
                table highlight_alpha_rc(sw, rc_list) {|r,c| "#{sw_vol_mat[r][c]*(RBB_VOL+RRM_VOL)}#{MICROLITERS}"}
            end
            show do
                title "Depleting riboRNA in <b>#{in_coll}</b>"
                separator
                check "Next, using a multichannel pipette aliquot <b>#{(RBB_VOL+RRM_VOL)}#{MICROLITERS}</b> of the <b>RBB</b> & <b>RRM</b> mix to each well in the table below."
                bullet "Mix by pipetting up and down 3 times."
                table highlight_alpha_non_empty(in_coll){|r,c| "#{(RBB_VOL+RRM_VOL)}#{MICROLITERS}"}
            end
            
            # Delete temporary stripwell that was created for multichannel pipetting
            sw.mark_as_deleted
            sw.save
        }
        show do
            title "Centrifuge Plate(s) and Store RRM"
            separator
            check "Seal plate(s) with a clear adhesive seal"
            note "Centrifuge plate(s) at <b>300 x g for 45s</b>:"
            in_collections.each {|in_coll| bullet "#{in_coll}"}
            check "Return rRNA Removal Mix (RRM) back to -20C freezer."
        end
    end
    
    def incubate_bind_rRNA_plate()
        show do
            title "Denature RNA"
            separator
            check "Plate sealed plates on a thermocycler, close lid, and select: <b>RNA Denaturation</b>"
            bullet "Pre-heat lid to 100°C"
            bullet "68C for 5mins"
            note "Continue on the next step while waiting for the thermocycler."
        end
    end
    
    def make_rRNA_removal_plate(input_def, output_def)
        out_collections = operations.map {|op| op.output(output_def).collection}.uniq
        in_collections = operations.map {|op| op.input(input_def).collection}.uniq
        show do
          title "Make riboRNA Removal Plate"
          separator
          check "Vortex the room temperature <b>Ribosomal Removal Beads (RRB)</b> vigorously to resuspend the beads."
          check "Gather a new 96 Well MIDI 0.8mL Plate(s) and label: #{out_collections.map {|out_coll| "RRP_#{out_coll.id}" } }"
          check "Gather a new 96 Well MIDI 0.8mL Plate(s) and label: #{out_collections.map {|out_coll| "RCP_#{out_coll.id}" } }"
        end
        out_collections.each {|out_coll|
        
            sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(out_coll)
            if rc_list.length > 18
                show do
                    title "Aliquot RRBs for Multichannel"
                    separator
                    check "Gather a clean new 12-Well Stripwell."
                    note "Follow the table to aliquot the <b>RRBs</b> for the next step."
                    table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*RRB_VOL}#{MICROLITERS}"}
                end
            end
            # Delete temporary stripwell that was created for multichannel pipetting
            sw.mark_as_deleted
            sw.save
            
            show do
                title "Make riboRNA Removal Plate RRP_#{out_coll}"
                separator
                note "Follow the table below to aliquot the <b>RRBs</b> to the appropriate wells of <b>RRP_#{out_coll}</b>, use a multichannel where possible:"
                table highlight_alpha_non_empty(out_coll){|r,c| "#{RRB_VOL}#{MICROLITERS}"}
            end
        }
        
        in_collections.each_with_index {|in_coll, in_coll_idx|
            show do
                title "Transfer Denatured RNA"
                separator
                check "Once the thermocycler has finished, remove plate <b>#{in_coll}</b> and incubate on Bench for 1min"
                check "Next, transfer entire contents (20#{MICROLITERS}) from each well of <b>#{in_coll}</b> to the corresponding well of the <b>RRP_#{out_collections[in_coll_idx]}</b>"
                bullet "<b>Mix by pipetting 7 times or Shake on plate shaker contiuously at ~1000rpm for 1 min</b>."
            end
            show do
                title "Place Plate on Magnetic Stand"
                separator
                check "Place plate on magnetic stand for 1 min"
            end
            show do
                title "Transfer Depleted RNA"
                separator
                note "<b>KEEP PLATE ON MAGNETIC STAND FOR THE FOLLOWING STEPS</b>"
                check "Transfer all of the supernatant from each well of the <b>RRP_#{out_collections[in_coll_idx]}</b> plate to <b>RCP_#{out_collections[in_coll_idx]}</b> plate (~20-40µl)."
                warning "If any beads remain in the wells, place the RCP_#{out_collections[in_coll_idx]} back on the magnetic standfor 1 min and transfer the supernatant to a new 96 Well MIDI 0.8mL Plate. Repeat as necessary until no beads are remaining."
            end
            in_coll.mark_as_deleted
            in_coll.save
        }
        show do 
            title "Store riboRNA Removal Beads (RRB)"
            separator
            check "Store rRNA Removal Beads back in the 4#{DEGREES_C} fridge."
        end
    end
    
    
    def clean_up_rna_clean_up_plate(output_def)
        out_collections = operations.map {|op| op.output(output_def).collection}.uniq
        show do
            title "Gather RNAClean XP Beads"
            separator
            check "Vortex the RNAClean XP beads vigoursly until they are well dispersed"
        end
        out_collections.each {|out_coll|
            sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(out_coll)
            show do
                title "Aliquot RNAClean XP Beads for Multichannel"
                separator
                note "Follow the table to aliquot the beads for the next step"
                bullet "The max volume in a stripwell well is 300µl"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*RNA_XP_BEADS}#{MICROLITERS}"}
            end
            show do
                title "Clean Depleted RNA"
                separator
                note "Follow the table below to aliquot the RNAClean Beads to the appropriate wells of RCP_#{out_coll}:"
                table highlight_alpha_non_empty(out_coll){|r,c| "#{RNA_XP_BEADS}#{MICROLITERS}"}
                check "Finally, seal the plate with a clear adhesive seal, then place on plate shaker at <b>~1000rpm for 2 mins</b>."
            end
            show do
                title "Clean Depleted RNA"
                separator
                check "Once throughly mixed, incubate the plate at room temperature for 15 mins."
                check "Next, place the plate on the magnetic stand at room temperature for 5 mins."
                bullet "Place on room temperature plate rotator."
            end
            show do
                title "Washing Depleted RNA"
                separator
                note "<b>KEEP PLATE ON MAGNETIC STAND FOR THE FOLLOWING STEPS</b>"
                check "Discard all of the supernatnat from each well (~100-130µl)."
                warning "Take care not to disturb the beads in the following steps."
                check "Next, add <b>200µl</b> of freshly prepared 70% EtOH to each well."
                check "Incubate for 30 seconds at room temperature."
                check "Next, remove and discard all of the supernatant from each well (~200µl)"
                check "Finally, place an <b>Aera Breathable Seal</b> on the plate and let dry for 15 mins."
                bullet "Place plate on plate rotator to expedite and ensure drying."
            end
            show do
                title "Aliquoting Elution Buffer (ELB)"
                separator
                note "Follow the table to aliquot Elution Buffer <b>(ELB)</b> for the next step:"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*11}µl"}
            end
            show do
                title "Eluting Depleted RNA"
                separator
                note "Follow the table below to aliquot the Elution Buffer <b>(ELB)</b> to the appropriate wells of RCP_#{out_coll}:"
                table highlight_alpha_non_empty(out_coll){|r,c| "#{11}µl"}
                check "Seal the plate with a clear adhesive seal, then place on plate shaker at <b>~1000rpm for 2 mins</b>."
            end
            show do
                title "Eluting Depleted RNA"
                separator
                check "Incubate plate at room temperature for 2 mins"
                check "Then centrifuge at <b>280 x g for 1 min</b>"
                check "Finally, place plate on magnetic stand at room temperature for 5 min"
                bullet "Continue to the next step while plate is incubating."
            end
            
            # Fragmenting riboRNA depleted RNA
            show do
                title "Aliquoting Elute, Prime, Fragment High Mix (EPH)"
                separator
                note "Follow the table to aliquot the <b>EPH Mix</b>  for the next step:"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*8.5}µl"}
            end
            show do
                title "Transfer Depleted RNA"
                separator
                check "Gather a clean 96 Well PCR plate and label DFP_#{out_coll.id}"
                check "Next, Transfer <b>8.5µl</b> supernatant from the <b>RCP_#{out_coll.id}</b> plate to the corresponding well in the <b>DFP_#{out_coll.id}</b> plate."
            end
            show do
                title "Fragmenting Depleted RNA"
                separator
                note "Follow the table below to aliquot the <b>EPH Mix</b> to the appropriate wells of DFP_#{out_coll}:"
                bullet "Mix by pipetting up and down 5 times."
                table highlight_alpha_non_empty(out_coll){|r,c| "#{8.5}µl"}
                check "Seal the plate with a clear adhesive seal."
            end
            sw.mark_as_deleted
            sw.save
        }
        show do 
            title "Store Reagent(s)"
            separator
            check "Return the Elute, Prime, Fragment High Mix (EPH) to the -20C freezer"
            check "Return the RNAClean XP Beads to 4C fridge."
        end
    end
    
    def incubate_depleted_RNA_fragment_plate()
        show do
            title "Incubate Depleted RNA Fragmentation Plate (DFP)"
            separator
            separator
            check "Place sealed plate(s) on a thermocycler, close lid, and select: <b>Elution 2 - Frag - Prime</b>"
            bullet "Pre-heat lid to 100C"
            bullet "94C for 8mins"
            bullet "Hold at 4C"
            check "Once finished, centrifuge briefly at <b>300 x g for 1 min</b>  to collect condensation"
            # note "Continue on the next step while waiting for the thermocycler."
        end
    end
    
end # Module RiboZero_Deplete_Fragment_RNA
