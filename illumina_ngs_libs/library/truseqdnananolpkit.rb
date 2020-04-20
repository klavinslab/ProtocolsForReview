# By: Eriberto Lopez
# elopez3@uw.edu
# Production: 10/05/18

# MISL Lab NGS Preparation kit and Protocol

# needs "Illumina NGS Libs/TruSeqStrandedTotalRNAKit"
# include RNASeq_PrepHelper

module DNA_NanoLigation
    include Units
    
    ERP2_VOL = 40
    AMP_BEADS_VOL = 160
    LIG2_VOL = 2.5
    ATL_MIX = 15
    
    def gather_dna_nano_adenylation_materials(num_ops)
        reagents_hash = {
            "End Repair Mix (ERP2)" => reagent_vol_with_extra(num_ops, ERP2_VOL).to_s + "#{MICROLITERS}",#ul
            "AMPure XP Beads" => reagent_vol_with_extra(num_ops, AMP_BEADS_VOL).to_s + "#{MICROLITERS}",#ul
            "Freshly Prepared 80% Ethanol" => reagent_vol_with_extra(num_ops, 400).to_s + "#{MICROLITERS}",#ul
            "Resuspension Buffer (RSB)" => "1 tube"
        }
        show do
            title "Gather Materials"
            separator
            note "Gather and thaw the following materials, then place on ice:"
            reagents_hash.each {|k,v| check "#{v} of #{k}"}
        end
    end
    
    def converting_to_blunt_ends(ops)
      collections_prepped = []
      groupby_collection = ops.group_by {|op| op.input('cDNA Library').child_item_id }
      groupby_collection.each do |collection_id, ops|
        collection = Collection.find(collection_id)
        rc_list = ops.map {|op| [op.inputs[0].row, op.inputs[0].column] }
        show do
          title "Converting DNA Libraries to Blunt End Fragments - #{collection.object_type.name} #{collection}"
          separator
          note "Follow the table below to aliquot <b>ERP2</b> to the appropriate wells of #{collection.object_type.name} <b>#{collection}</b>:"
          bullet "Mix throughly by pipetting 10 times"
          table highlight_alpha_rc(collection, rc_list){|r,c| "#{ERP2_VOL}#{MICROLITERS}"}
        end
        collections_prepped.push(collection)
      end
      show do
        title "Thermocycling DNA Libraries to Blunt End Fragments"
        separator
        check "Place <b>#{collections_prepped.map{|c| c.id}}</b> on the thermocycler and run: <b>ERP</b> program"
        note "Thermocycler Conditions:"
        bullet "Each well contains 100#{MICROLITERS}"
        bullet "30#{DEGREES_C} for 30 mins"
        bullet "Then, place on ice"
        check "PLACE A TIMER FOR 33 Minutes"
      end
      collections_prepped.each {|collection| collection.location = "Thermocycler"}
    end
    
    # def cleaning_blunt_end_fragments(ops)
    #     blunt_end_container = op.input('cDNA Library').item
    #     blunt_end_collection = collection_from(blunt_end_container)
    #     total_80_etoh = (blunt_end_collection.get_non_empty.length*200)*2 # 2 washes required
    #     etoh_vol = (total_80_etoh*0.8).round(3)
    #     h2o_vol = (total_80_etoh*0.2).round(3)
    #     ampure_xp_bead_vol = 160*blunt_end_collection.get_non_empty.length
    #     show do
    #         title "Cleaning Blunt End Fragments"
    #         separator
    #         note "For the next steps you will need:"
    #         bullet "#{total_80_etoh}#{MICROLITERS} of 80% Ethanol = #{etoh_vol}#{MICROLITERS} & #{h2o_vol}#{MICROLITERS}"
    #         bullet "#{ampure_xp_bead_vol}#{MICROLITERS} of Ampure XP Beads"
    #         bullet "Single or Multichannel P200 pipette"
    #     end
    #     show do
    #         title "Cleaning Blunt End Fragments"
    #         separator
    #         check "Add 160#{MICROLITERS} of <b>Ampure XP beads</b> to each well of #{blunt_end_container.object_type.name} #{blunt_end_container}"
    #         bullet "Gently pipette the entire volume up and down 10 times to mix thoroughly."
    #         check "Next, incubate #{blunt_end_container} for <b>15mins</b>"
    #         note "Continue, on to the next step while timer is going."
    #     end
    #     show do
    #         title "Cleaning Blunt End Fragments"
    #         separator
    #         check "Place #{blunt_end_container} on to the magnetic stand at room temperature for 15 minutes, or until liquid is clear."
    #         check "Using a 200#{MICROLITERS} single channel or multichannel pipette set to 127.5#{MICROLITERS}, 
    #         remove and discard 127.5#{MICROLITERS} of the supernatant from each well of the #{blunt_end_conatiner} #{blunt_end_container.object_type.name}."
    #         check "Repeat removal of supernatant to ensure no Ethanol is carried over to downstream processes."
    #         note "Leave #{blunt_end_container} on the magnetic stand for the following step."
    #     end
    #     num_washes = 2
    #     num_washes.times do |idx|
    #         show do
    #             title "Washing Blunt End Fragments (#{idx}/#{num_washes})"
    #             separator
    #             note "With the PCR plate on the magnetic stand, add 200#{MICROLITERS} freshly prepared 80% EtOH to each well without disturbing the beads"
    #             note "Incubate the #{blunt_end_container} #{blunt_end_container.object_type.name} at room temperature for 30 seconds, and then remove and discard all of the supernatant from each well."
    #             bullet "Take care not to disturb the beads!!!"
    #         end
    #     end
    #     show do
    #         title "Drying Blunt End Fragments"
    #         separtor
    #         warning "Be sure that all Etanol has been removed from each sample to avoid downstream issues".upcase
    #         check "Let #{blunt_end_container} stand at room temperature for 15 minutes to dry, and then remove the plate from the magnetic stand."
    #         check "Set timer for 15 mins and continue on to the next step."
    #     end
    #     show do
    #         title "Isolating Blunt End Fragments"
    #         separator
    #         note "After beads have throughly dried, resuspend pellet in #{17.5}#{MICROLITERS}, by resuspending 10 times"
    #         bullet "PRO TIP: Throughly dried bead pellets will have small cracks and will NOT be shiny."
    #         check "Once beads are resuspended, incubate plate at room temperature for 2 mins"
    #         note "Continue on to the next step"
    #     end
    #     output_container = op.output('Adenylated cDNA Library').item
    #     show do
    #         title "Isolating Blunt End Fragments"
    #         separator
    #         check "After incubation, place the #{blunt_end_container} on the magnetic stand at room temperature for 5 minutes or until the liquid is clear."
    #         check "Next, transfer 15#{MICROLITERS} of the clear supernatant from each well of the #{blunt_end_container} to the corresponding well of a new, clean #{output_container.object_type.name} labeled as #{output_container}"
    #         note "Continue on to the next step"
    #     end
    # end
    
    def add_dna_nano_a_tailing_mix(ops)
      collections_prepped = []
      groupby_collection = ops.group_by {|op| op.input('cDNA Library').child_item_id }
      groupby_collection.each do |collection_id, ops|
        collection = Collection.find(collection_id)
        rc_list = ops.map {|op| [op.inputs[0].row, op.inputs[0].column] }
        show do
          title "Adding A-Tailing Mix (ATL) to #{collection}"
          separator
          note "Follow the table below to aliquot the <b>ATL</b> to the appropriate wells of <b>#{collection}</b>:"
          bullet "Mix by pipetting up and down 10 times."
          table highlight_alpha_rc(collection, rc_list){|r,c| "#{ATL_MIX}#{MICROLITERS}"}
          check "Seal the item, then centrifuge <b>280 x g for 1 min</b>."
        end
        collections_prepped.push(collection)
      end
      show do
        title "Incubating Adapter Ligations"
        separator
        check "Place <b>#{collections_prepped.map {|c| c.id}}</b> a thermocycler, close lid, and select: <b>A Ligation</b>"
        note "Thermocycler Conditions:"
        bullet "Pre-heat lit to 100#{DEGREES_C}"
        bullet "37#{DEGREES_C} for 30 mins"
        bullet "70#{DEGREES_C} for 5 mins"
        bullet "Hold at 4#{DEGREES_C}" # Give plate 4#{DEGREES_C} for 1 min (similar to being on ice for 1 min)
        check "Set a timer for 40 mins"
        note "Continue on to the next step while incubating items."
      end
      collections_prepped.each {|collection| collection.location = "Thermocycler"}
    end    
    
    def clean_up_blunt_end_fragments(collection)
        if collection.get_non_empty.length > 18
            sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(collection)
            show do
                title "Aliquot AMPure XP Beads for Multichannel"
                separator
                check "Gather AMPure XP Beads & vortex vigorously to disperse beads."
                check "Gather a new, clean 12-Well Stripwell."
                note "Follow the table to aliquot the AMPure XP beads into a stripwell for the next step:"
                bullet "The maximum volume in a stripwell well is 300#{MICROLITERS}"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*AMP_BEADS_VOL}#{MICROLITERS}"}
            end
            sw.mark_as_deleted
            sw.save
        end
        take [collection], interactive: true
        collection.location = "Bench"
        show do
            title "Clean Up Blunt End Fragments Plate #{collection}"
            separator
            note "Follow the table below to aliquot the <b>AMPure XP</b> beads to the appropriate wells of <b>#{collection}</b>:"
            bullet "Mix by pipetting 10 times"
            table highlight_alpha_non_empty(collection){|r,c| "#{AMP_BEADS_VOL}#{MICROLITERS}"}
            check "Incubate plate at room temperature for 15 mins."
            check "After timer has finished, place plate on magnetic stand at room temperature for 15 mins."
        end
        show do
            title "Clean Up Blunt End Fragments Plate #{collection}"
            separator
            note "<b>KEEP PLATE ON STAND FOR THE FOLLOWING STEPS</b>"
            check "Set pipette or multichannel pipette to <b>127.5#{MICROLITERS}</b>"
            check "<b>Without disturbing the bead pellet</b> remove and discard supernatant from each well."
            check "Repeat once again to ensure all supernatant is removed."
            # check "After timer has finished, place plate on magnetic stand at room temperature for 15 mins"
        end
        show do
            title "Washing Blunt End Fragments Plate #{collection}"
            separator
            check "Aliquot freshly prepared 80% Ethanol into a new, clean multichannel resivoir."
        end
        wash = 1
        (2).times do
            show do
                title "Washing Blunt End Fragments Plate (#{wash}/2)"
                separator
                note "<b>KEEP PLATE ON MAGNETIC STAND FOR THE FOLLOWING STEPS</b>"
                note "Follow the table below to aliquot the <b>80% EtOH</b> to the appropriate wells:"
                table highlight_alpha_non_empty(collection){|r,c| "#{200}#{MICROLITERS}"}
                check "Incubate the plate at room temperature for 30 seconds, and then remove and discard all of the supernatant from each well."
                bullet "DO NOT DISTURB THE BEADS PELLET"
            end
            wash += 1
        end
        show do 
            title "Washing Blunt End Fragments Plate"
            separator
            check "Finally, place an <b>Aera Breathable Seal</b> on the plate and let dry for 15 mins."
            bullet "Place plate on plate rotator to expedite and ensure drying."
            note "Continue on to the next step while bead pellets are drying."
        end
    end
    
    def eluting_blunt_end_fragments(collection, out_collection)
        if collection.get_non_empty.length > 19
            sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(collection)
            show do
                title "Aliquot Resupension Buffer (RSB) for Multichannel"
                separator
                check "Gather a new clean 96 Well PCR Plate and label: <b>ALP_#{collection}</b>"
                note "Follow the table to aliquot the <b>RSB</b> into a stripwell for the next step:"
                bullet "The maximum volume in a stripwell well is 300#{MICROLITERS}"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*17.5}#{MICROLITERS}"}
            end
            sw.mark_as_deleted
            sw.save
        end
        show do
            title "Eluting Blunt End Fragments"
            separator
            note "Follow the table below to aliquot the <b>RSB</b> to the appropriate wells:"
            table highlight_alpha_non_empty(collection){|r,c| "#{17.5}#{MICROLITERS}"}
            bullet "Gently pipette the entire volume up and down 10 times"
            check "Incubate at room temperature for 2 mins"
        end
        show do
            title "Eluting Blunt End Fragments"
            separator
            check "Place plate on magnetic stand and incubate at room temperature for 5 mins"
            check "Finally, transfer <b>15#{MICROLITERS}</b> of clear supernatant from each well of plate <b>#{collection}</b> to <b>ALP_#{out_collection}</b>"
        end
    end
    
    def defrost_nano_adapter_ligation_materials()
      num_ops = 1 # just a placeholder
      reagents_hash = {
        "Ligation Mix (LIG2)" => reagent_vol_with_extra(num_ops, LIG2_VOL).to_s + "#{MICROLITERS}",#ul
        "AMPure XP Beads" => reagent_vol_with_extra(num_ops, AMP_BEADS_VOL).to_s + "#{MICROLITERS}",#ul
        "Freshly Prepared 80% Ethanol" => reagent_vol_with_extra(num_ops, 400).to_s + "#{MICROLITERS}",#ul
        "Resuspension Buffer (RSB)" => "1 tube"
      }
      show do
        title "Gather Materials and Defrost"
        separator
        note "Gather and thaw the following materials, then place on ice:"
        reagents_hash.each {|k,v| check "#{k}"}
      end
      show do
        title "Prepparing for Ligation"
        separator
        check "Clean up materials and reagents that you will not be using for the 'Ligate Adapters' operation before finishing"
      end
    end
    
    # Ligate Adapter Protocol
    def gather_nano_adapter_ligation_materials(num_ops)
        reagents_hash = {
            "Ligation Mix (LIG2)" => reagent_vol_with_extra(num_ops, LIG2_VOL).to_s + "#{MICROLITERS}",#ul
            "AMPure XP Beads" => reagent_vol_with_extra(num_ops, AMP_BEADS_VOL).to_s + "#{MICROLITERS}",#ul
            "Freshly Prepared 80% Ethanol" => reagent_vol_with_extra(num_ops, 400).to_s + "#{MICROLITERS}",#ul
            "Resuspension Buffer (RSB)" => "1 tube"
        }
        show do
            title "Gather Materials"
            separator
            note "Gather and thaw the following materials, then place on ice:"
            reagents_hash.each {|k,v| check "#{v} of #{k}"}
        end
    end

    def add_nano_ligation_mix(collection)
      lig_vol = 2.5
      rsb_vol = 2.5
      collection = collection_from(collection)
      if collection.get_non_empty.length > 18
        sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(collection)
        show do
          title "Preparing Ligation Master Mix"
          separator
          # check "Spin down the Ligation Control (CTL) & Stop Ligation Buffer (STL)."
          check "Gather a new, clean 12-Well Stripwell."
          note "Follow the table to aliquot the Ligation Mix (LIG2) into a stripwell for the next step:"
          table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*lig_vol}#{MICROLITERS}"}
        end
        show do
          title "Preparing Ligation Master Mix"
          separator
          check "To the same stripwell created in the previous step."
          note "Follow the table to aliquot the Resuspension Buffer (RSB) into a stripwell for the next step:"
          table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*rsb_vol}#{MICROLITERS}"}
        end
        sw.mark_as_deleted
        sw.save
        show do
          title "Adding Ligation Mix to #{collection}"
          separator
          note "Follow the table below to aliquot the <b>Ligation Mix</b> to the appropriate wells:"
          bullet "Thoroughly mix by pipetting 5 times"
          table highlight_alpha_non_empty(collection){|r,c| "#{(lig_vol+rsb_vol)}#{MICROLITERS}"}
        end
      else
        show do
          title "Adding Resuspension Buffer (RSB) to #{collection}"
          separator
          note "Follow the table below to aliquot the <b>Resuspension Buffer (RSB)</b> to the appropriate wells:"
          bullet "Thoroughly mix by pipetting 5 times"
          table highlight_alpha_non_empty(collection){|r,c| "#{rsb_vol}#{MICROLITERS}"}
        end
        show do
          title "Adding Ligation Mix to #{collection.id}"
          separator
          note "Follow the table below to aliquot the <b>Ligation Mix (LIG2)</b> to the appropriate wells:"
          bullet "Thoroughly mix by pipetting 5 times"
          table highlight_alpha_non_empty(collection){|r,c| "#{lig_vol}#{MICROLITERS}"}
        end
      end
    end
    
end # Module DNA_NanoLigation
