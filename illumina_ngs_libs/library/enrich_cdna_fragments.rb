# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

module Enrich_cDNA_Fragments
    include Units
    def library_type(collection)
        sample_type = collection.matrix.flatten.select {|s_id| s_id != -1}.map {|s_id| Sample.find(s_id).sample_type.name }.uniq
        library_type = (sample_type == "Yeast Strain") ? "cDNA" : "DNA"
        return library_type
    end

    def gather_defrost_amplification_materials(collections_to_defrost)
        # Gather the frozen plate so that it is defrosted by the time all the reagents are prepped
        take collections_to_defrost, interactive: true
        
        num_ops = operations.length
        reagents_hash = {
            'PCR Master Mix (PMM)'=> '1-2 tube(s)',
            'PCR Primer Cocktail (PPC)'=>'1-2 tube(s)',
            'Resuspension Buffer (RSB)' =>'1-2 tube(s)',
            'Freshly prepared 80% Ethanol'=> reagent_vol_with_extra(num_ops, 400),
            'AMPure XP Beads'=> reagent_vol_with_extra(num_ops, 50)
            
        }
        show do
            title "Gather the following materials:"
            separator
            note "Let the following reagents thaw at room temperature, then immediately place on ice"
            reagents_hash.each {|k, v| (k.include? 'PCR') ? (check "#{k}") : nil}
            note "\n"
            note "Gather the following materials:"
            etoh_vol = reagents_hash['Freshly prepared 80% Ethanol']
            check "Make 80% EtOH => #{etoh_vol * 0.8}#{MICROLITERS} of 100% EtOH + #{etoh_vol * 0.2}#{MICROLITERS} of MG H2O"
            check "<b>1</b> - 96 Well PCR Plate(s)"
            check "<b>1</b> - 96 Well MIDI 0.8mL Plate(s)"
            check "<b>3</b> - Adhesive Seals"
        end
    end
    
    def make_pcr_master_mix()
        num_ops = operations.length
        pmm_vol = 5 * num_ops
        ppc_vol = 25 * num_ops
        master_mix_vol = pmm_vol + ppc_vol
        (master_mix_vol > 1501) ? tubes = 2 : tubes = 1
        (master_mix_vol > 1501) ? aliquot = [pmm_vol/2, ppc_vol/2] : aliquot = [pmm_vol, ppc_vol]
        show do 
          title "Create PCR Master Mix"
          separator
          check "Ensure that #{'PCR Master Mix (PMM)'} & #{'PCR Primer Cocktail (PPC)'} are defrosted"
          check "Gather <b>#{tubes}</b> 1.5mL microfuge tube(s)."
          check "In each of the microfuge tube(s), aliquot <b>#{aliquot[0]}#{MICROLITERS} of PMM</b> & <b>#{aliquot[1]}#{MICROLITERS} of PPC</b>"
          bullet "Mix throughly by pipetting."
        end
    end
    
    def add_pcr_master_mix(collection)
        library_type = library_type(collection)
        if collection.get_non_empty.length > 18
            sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(collection)
            show do
                title "Aliquot PCR Master Mix for Multichannel"
                separator
                note "Follow the table to aliquot the PCR Master Mix into a stripwell for the next step:"
                bullet "The maximum volume in a stripwell well is 300#{MICROLITERS}"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*30}#{MICROLITERS}"}
            end
            sw.mark_as_deleted
            sw.save
        end
        show do
            title "Aliquoting PCR MM to Indexed #{library_type} Libraries"
            separator
            check "Ensure samples in plate <b>#{collection}</b> are thawed."
            note "Follow the table to aliquot the PCR Master Mix to the appropriate wells:"
            bullet "Mix throughly by pipetting 5 times"
            table highlight_alpha_non_empty(collection){|r,c| "#{30}#{MICROLITERS}"}
            check "Finally, seal plate and centrifuge briefly at 280 x g for 30 sec"
        end
    end

    def incubate_enrich_pcr_plate(collection)
        show do
          title "Incubate Enrichment PCR Plate #{collection}"
          separator
          note "Place sealed plate on thermocycler & Run: <b>Enrich</b>"
          note "Thermocycler Conditions:"
          bullet "Pre-heat lid to 100°C"
          bullet "98°C for 30 seconds"
          note "15 Cycles of:"
          bullet "98°C for 10 seconds"
          bullet "60°C for 30 seconds"
          bullet "72°C for 30 seconds"
          bullet "72°C for 5 minutes"
          note ""
          bullet "Hold at 4°C"
        end
    end
    def clean_up_enrich_pcr(collection)
        library_type = library_type(collection)
        if collection.get_non_empty.length > 19
            sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(collection)
            show do
                title "Aliquot AMPure XP Beads for Multichannel"
                separator
                check "Vortex the AMPure Beads for at least 1 minute or until they are well dispersed."
                note "Follow the table to aliquot the AMPure XP Beads into a stripwell for the next step:"
                bullet "The maximum volume in a stripwell well is 300#{MICROLITERS}"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*47.5}#{MICROLITERS}"}
            end
            sw.mark_as_deleted
            sw.save
        end
        show do
            title "Adding AMPure XP Beads to 96 Well MIDI Plate"
            separator
            check "Gather a new, clean <b>96 Well MIDI 0.8mL Plate</b> and label: <b>CleanUp_#{collection}</b>"
            note "Follow the table below to aliquot the <b>AMPure Beads</b> to the appropriate wells of the new plate:"
            bullet "Mix by pipetting up and down 10 times."
            table highlight_alpha_non_empty(collection){|r,c| "#{47.5}#{MICROLITERS}"}
            note "Continue on to the next step"
        end
        show do
            title "Transfering Enriched #{library_type} Libraries"
            separator
            check "Once the thermocycler has finished, transfer entire contents of plate <b>#{collection}</b> to the correspoding well of the <b>CleanUp_#{collection}</b>"
            bullet "Mix throughly by pipetting 10 times"
            check "Incubate plate at room temperature for 15 mins"
            check "Centrifuge plate at 280 x g for 1 min"
            check "Place plate on magnetic stand for 5 mins"
        end
        show do
            title "Clean Up Enriched #{library_type} Libraries"
            separator
            warning "WITH THE PLATE ON THE MAGNETIC STAND"
            check "Remove and discard 95#{MICROLITERS} of supernatant from each well of <b>CleanUp_#{collection}</b>"
        end
        washes = 1
        (2).times do
            show do 
                title "Washing Enriched #{library_type} Libraries (#{washes}/2)"
                separator
                note "With the <b>CleanUp_#{collection}</b> on the magnetic stand, add <b>200#{MICROLITERS}</b> of 80% EtOH"
                warning "DO NOT DISTURB THE BEADS!"
                table highlight_alpha_non_empty(collection){|r,c| "#{200}#{MICROLITERS}"}
                check "Incubate for 30 secs"
            end
            show do 
                title "Washing Enriched #{library_type} Libraries"
                separator
                warning "DO NOT DISTURB THE BEADS!"
                check "Remove and discard all of the supernatant from each well"
            end
            
            if washes == 2
                show do 
                    title "Drying Enriched #{library_type} Libraries"
                    separator
                    check "Seal plate with a Aera Breathable seal"
                    check "Let samples air-dry at room temperature for 10 mins"
                    bullet "Place plate on plate rotator to expidite process and ensure drying"
                end
            end
            washes += 1
        end
        
        if collection.get_non_empty.length > 19
            sw, sw_vol_mat, rc_list = multichannel_vol_stripwell(collection)
            show do
                title "Aliquot Resuspension Buffer (RSB) for Multichannel"
                separator
                note "Follow the table to aliquot the Resuspension Buffer (RSB) into a stripwell for the next step:"
                bullet "The maximum volume in a stripwell well is 300#{MICROLITERS}"
                table highlight_alpha_rc(sw, rc_list){|r,c| "#{sw_vol_mat[r][c]*32.5}#{MICROLITERS}"}
            end
            sw.mark_as_deleted
            sw.save
        end
        
        show do
            title "Eluting Indexed #{library_type} Libaries"
            separator
            check "Remove </b>CleanUp_#{collection}</b> from magnetic plate."
            note "Follow the table to aliquot Resuspension Buffer to the appropriate wells:"
            bullet "Mix throughly by pipetting until the beads are dispersed!"
            table highlight_alpha_non_empty(collection){|r,c| "#{32.5}#{MICROLITERS}"}
            check "Seal plate & incubate at room temperature for 2 mins"
            check "Next, place plate on magnetic stand and incubate for 5 mins"
            note "Continue to next step while incubating."
        end
    end
    
    def transfer_clean_cDNA(collection)
        library_type = library_type(collection)
        show do
            title "Transfer clean #{library_type}"
            separator
            check "Gather a new, clean <b>96 Well PCR Plate</b> and label: <b>#{collection}</b>"
            warning "WITH THE PLATE ON THE MAGNETIC STAND"
            check "Transfer <b>30#{MICROLITERS}</b> from each well of <b>CleanUp_#{collection}</b> to the corresponding  well of the new <b>#{collection}</b>"
        end
        collection.location = "-20°C NGSeq Section"
        collection.save
    end
    
end # Module Enrich_cDNA_Fragments
