# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

# needs "qPCR/qPCR_Constants"
needs "Tissue Culture Libs/CollectionDisplay"
# needs "Standard Libs/AssociationManagement"
needs "Standard Libs/Units"

module QPCR_Preparation
    include CollectionDisplay
    include Units
    # include QPCR_Constants
    
    def get_total_rxns()
        # Std Curve (24 rxnx) plus 24 samples in triplicate (72 rxns) are able to fit onto a 96 well plate
        
        # Samples in triplicate
        rxns = operations.length * 3
        
        # Find the number of 96 Well qPCR plates needed for the experiement
        num_qpcr_plates = rxns/72
        
        # If there are any remaining create a new 96 Well qPCR plate
        (rxns % 72 > 0) ? (num_qpcr_plates += 1) : nil
        
        # If creating another plate, then that must include a standard curve as well (24 rxns)
        (rxns % 72 > 0) ? (rxns += 24) : nil
        
        return rxns, num_qpcr_plates
    end
    
    # Gather the materials necessary for this protocol based on the number of samples found in each input_collection
    def gather_qpcr_materials()
        total_rxns, num_qpcr_plates = get_total_rxns()
        show do
            title "Gather the Following Materials"
            separator
            check "<b>#{num_qpcr_plates}</b> - 96 Well qPCR plate (White)"
        end
        return total_rxns, num_qpcr_plates
    end
    
    def create_qpcr_master_mix(master_mix_reagents_hash)
        total_master_mix_vol = 0#ul
        master_mix_reagents_hash.each {|reg, vol| total_master_mix_vol += vol}
        (total_master_mix_vol > 1501) ? container = "15mL Falcon tube" : container = '1.5mL Microfuge tube'
        show do
            title "Creating qPCR Master Mix"
            separator
            check "Gather a #{container} and label: <b>qPCR MM</b>"
            note "Mix the following reagents by pipetting throughly:"
            master_mix_reagents_hash.each {|reg, vol| check "<b>#{vol}#{MICROLITERS}</b> of #{reg}"}
            bullet "Place immediately on ice and away from light until use!"
        end
        show do 
            title "Put Away Enzymatic Buffers"
            separator
            note "Put the following reagents to their appropriate storage temperature range (ie: -20°C or -4°C):"
            master_mix_reagents_hash.select {|reg, vol| !reg.include? 'Primer'}.select {|reg, vol|  !reg.include? 'H2O'}.each {|reg, vol| check "#{reg}"}
        end
    end
    
    def create_qpcr_standard_curve()
        
        # Get PhiX sample/stock
        # Find PhiX aliquot
        
        # Created 4nM 10ul aliquots to use in standard curve ranging from 400pM to 0pM in folds of 10 (10/08/18)
        phix_stock_item = find(:item, {sample: {name: "PhiX Control v3"}, object_type: {name: 'Fragment Stock' }}).select {|i| i.get('indexed_dna_conc_nM').to_f == 4.0}.first
        
        # Go take aliquot
        take [phix_stock_item], interactive: true
        
        # Create new empty stripwell for displaying
        stripwell = create_stripwell_collection()
        
        # Fill a stripwell with PhiX dilutions - Includes images for techs
        create_phix_standard_curve_stripwell(stripwell)
        stripwell.mark_as_deleted # Deletes virtual collection that was just used for display purposes
        stripwell.save
        
        # Keep track of how many times a stock has been used - Avoid more than 3 uses (freeze thaw cycles)
        track_phix_standard_use(phix_stock_item)
    end
    
    # Keep track of how many times a stock has been used - Avoid more than 3 uses (freeze thaw cycles)
    def track_phix_standard_use(phix_stock_item)
        if phix_stock_item.get('times_used').nil?
            phix_stock_item.associate(:times_used, 1)
        else
            times_used = phix_stock_item.get('times_used')
            times_used += 1
            if times_used == 3
                show do
                    title "Toss out PhiX Stock #{phix_stock_item}"
                    separator
                    check "This item has been used at least 3 times, so toss it out"
                end
                phix_stock_item.mark_as_deleted
                phix_stock_item.save
            else
                release [phix_stock_item], interactive: true
            end
        end
    end

    
    def create_phix_standard_curve_stripwell(stripwell)
        # Important !!!
        # Standard Curve stripwell concentrations before going into qpcr_rxn
        # QPCR_STANDARD_CURVE_RANGE
        # NOTE: This will be diluted 1:10 in the qpcr_rxn
        
        dilutant_vol =[[27, 27, 27, 27, 27, 27, 27, 30]]
        well_num = [[1, 2, 3, 4, 5, 6, 7, 8]]
        
        rc_list = []
        dilutant_vol.each_with_index {|row, r_idx| 
            row.each_with_index {|col, c_idx|
                rc_list.push([r_idx, c_idx])
            }
        }
        show do 
            title "Create PhiX Standard Curve"
            separator
            note "Let the PhiX item thaw at room temperature while preparing Standard Curve stripwell"
            check "Gather 0.1% Tween 20 (10mL of MG H2O + 10#{MICROLITERS} of Tween-20)"
            check "Gather a new 8-Well Stripwell and label the wells 1-8"
            note "Follow the table below to fill with 0.1% Tween-20"
            table highlight_rc(stripwell, rc_list){|r,c| "#{dilutant_vol[r][c]}#{MICROLITERS}\nWell_#{well_num[r][c]}"}
        end
        # show do
        #     title "Create PhiX Standard Curve"
        #     separator
        #     check "Add 72#{MICROLITERS} of 0.1% Tween-20 to the 0.5nM PhiX Aliquot you just thawed."
        #     bullet "This has 80#{MICROLITERS} of 50pM phiX in 0.1% Tween-20"
        #     check "Mix briefly by pipetting then centrifuge to collect"
        #     bullet 'Try to avoid foaming!!'
        # end
        show do
            title "Create PhiX Standard Curve"
            separator
            check "To the pre-filled stripwell, transfer <b>3#{MICROLITERS}</b> from the defrosted PhiX Aliquot to <b>Well_1</b>."
            bullet "<b>Well_1</b> has <b>30#{MICROLITERS}</b> of 400pM PhiX in 0.1% Tween-20"
            check "Mix briefly by pipetting, cap, then centrifuge to collect"
            bullet 'Try to avoid foaming!!'
        end        
        image_path = 'Actions/RNA/qPCR_Quantification/'
        # img1 = image_path + 'phix_standard_curve_step_1.png' 
        # img2 = image_path + 'phix_standard_curve_step_2.png'
        # img3 = image_path + 'phix_standard_curve_step_3.png'
        # img4 = image_path + 'phix_standard_curve_step_4.png'
        # image_arr = [img1, img2, img3, img4]
        
        # New standard curve - dilutions in folds of 10
        img1 = image_path + 'phix_standard_cuvre_step_1_v2.png' # :( Wrong cuvre on purpose, that is how it is named on AWS
        img2 =  image_path + "phix_standard_cuvre_step_2_v2.png" # :( Wrong cuvre on purpose, that is how it is named on AWS
        image_arr = [img1, img2]
        count_steps = 1
        image_arr.each {|image| 
            show do
                title "Create PhiX Standard Curve"
                separator
                check "Follow the image below to transfer the appropriate amount of PhiX to the appropriate well:"
                image image
            end
            if count_steps == 2
                show do
                    title "Create PhiX Standard Curve"
                    separator
                    check "Cap & Spin down stripwell"
                    check "Place PhiX Standard Curve stripwell near by until later use"
                end
            end
            count_steps += 1
        }
    end
    
    def gather_master_mix_materials(total_rxns)
        # Find illumina qpcr primers
        illumina_qpcr_fwd = find(:item, { sample: { name: "qPCR primer 1.1" }, object_type: { name: "Primer Aliquot" } }).select {|i| i.location != 'deleted'}.first
        illumina_qpcr_rev = find(:item, { sample: { name: "qPCR primer 2.1" }, object_type: { name: "Primer Aliquot" } }).select {|i| i.location != 'deleted'}.first
        
        take [illumina_qpcr_fwd, illumina_qpcr_rev], interactive: true
        
        primer_aliquot_vol_hash = show do
            title "Is There Enough Primer Volume to Continue?"
            separator
            select ['Yes', 'No'], var: 'fwd_primer_vol', label: "Is there at least #{total_rxns * 0.25}#{MICROLITERS} in primer aliquot #{illumina_qpcr_fwd.id}?", default: 0
            select ['Yes', 'No'], var: 'rev_primer_vol', label: "Is there at least #{total_rxns * 0.25}#{MICROLITERS} in primer aliquot #{illumina_qpcr_rev.id}?", default: 0
        end
        
        # Create new primer aliquot, but keep the same item number
        if primer_aliquot_vol_hash.values.include? 'No'
            make_new_primer_aliquots(primer_aliquot_vol_hash, illumina_qpcr_fwd, illumina_qpcr_rev)
        end
        total_rxns = round_to_nearest_five((total_rxns + 8))
        log_info 'total_rxns including std curve in gather_master_mix_materials()',total_rxns
        
        master_mix_reagents_hash = {
            'KAPA MM (2X)' => total_rxns*9,#ul
            'EVA Green (20X)' => total_rxns*1,#ul
            "Primer Aliquot #{illumina_qpcr_fwd}" => total_rxns*0.2,#ul
            "Primer Aliquot #{illumina_qpcr_rev}" => total_rxns*0.2,#ul
            "MG H2O" => total_rxns*7.6,#ul
        }
        show do
            title "Gather qPCR Master Mix Reagents"
            separator
            note "Gather the following materials, defrost at room temperature then, immediately place on ice!"
            master_mix_reagents_hash.each {|reg, vol| check "You will need about <b>#{vol}#{MICROLITERS}</b> of #{reg}"}
            bullet "Continue on to the next step"
        end
        return master_mix_reagents_hash
    end
    def make_new_primer_aliquots(primer_aliquot_vol_hash, illumina_qpcr_fwd, illumina_qpcr_rev)
        dilution_hash = {}
        (primer_aliquot_vol_hash[:fwd_primer_vol] == "No") ? dilution_hash[find(:item, { sample: { name: "qPCR primer 1.1" }, object_type: { name: "Primer Stock" } }).select {|i| i.location != 'deleted'}.first] = illumina_qpcr_fwd : nil
        (primer_aliquot_vol_hash[:rev_primer_vol] == "No") ? dilution_hash[find(:item, { sample: { name: "qPCR primer 2.1" }, object_type: { name: "Primer Stock" } }).select {|i| i.location != 'deleted'}.first] = illumina_qpcr_rev : nil
        
        take dilution_hash.values, interactive: true
        
        show do
            title "Creating New Primer Aliquots"
            separator
            check "Gather <b>#{dilution_hash.length}</b> - 1.5mL Microfuge tubes"
            check "Label tubes: #{dilution_hash.keys.map {|i| i.id}}"
            check "Gather MG H2O"
        end
        show do
            title "Creating New Primer Aliquots"
            separator
            check "Add 45#{MICROLITERS} of MG H2O to each tube"
            dilution_hash.each {|stk, aliquot| check "Take 5#{MICROLITERS} from Item #{stk} and dilute into new Item #{aliquot}"}
            check "Vortex and spin down to collect primer dilution."
            bullet "Use the remaining volume in the old primer aliquot and replace with the new dilution when storing."
        end
        
    end
    
    def dilute_cDNA_libraries_to_linear_range(input_str)
        dilution_factor = 0.001
        in_collections = operations.map {|op| op.input(input_str).collection}.uniq
        in_collections.each {|in_coll| 
            show do
                title "Diluting Indexed Libraries to Linear Range"
                separator
                check "Gather a new, clean 96 Deep Well Plate"
                check "Label the new item: <b>Dilution_#{in_coll.id}</b>"
                check "Gather #{in_coll.get_non_empty.length + 2}mL of 0.1% Tween-20"
                note "Using a multichannel pipette, aliquot 0.1% Tween-20 to the appropriate wells:"
                table highlight_alpha_non_empty(in_coll) {|r,c| "1mL"}
            end
            take [in_coll], interactive: true
            show do 
                title "Diluting Indexed Libraries to Linear Range"
                separator
                check "Gather plate <b>#{in_coll}</b>"
                check "Transfer #{1000*dilution_factor.round(2)}#{MICROLITERS} of each well in <b>#{in_coll}</b> to its corresponding well in <b>Dilution_#{in_coll.id}</b>."
                check "Place a seal on top of the plate and set on plate shaker for 1 min at 500 rpm."
                check "Place on bench until needed."
            end
            # Associate dilution factor to part_items in collection
            in_coll.get_non_empty.each {|r,c| in_coll.set_part_data(key=:dilution_factor, r, c, dilution_factor)}
        }
    end
    def direct_tech_to_transfer_diluted_cdna(qpcr_transfer_hash)
        qpcr_transfer_hash.keys.sort {|k_x, k_y| k_x.id <=> k_y.id}.each {|in_coll|
            qpcr_transfer_hash[in_coll].keys.sort {|k_x, k_y| k_x.id <=> k_y.id}.each {|q_coll| 
                # Transfer hash for this q_coll
                in_coll_to_qpcr_plate_hash = qpcr_transfer_hash[in_coll][q_coll]
                # Always create multichannel stripwell per q_coll
                show_multichannel_stripwell(collection=q_coll, reagent_name='qPCR Master Mix', rxn_vol=20) # Will fill q_coll with 18ul/rxn
                # Add DNA to qPCR plate
                add_qpcr_master_mix_to_q_collection(q_coll)
                add_standard_curve_to_q_collection(q_coll)
                add_exp_triplicate_samples_to_q_coll(q_coll, in_coll, in_coll_to_qpcr_plate_hash)
            }
        }
    end
    def add_exp_triplicate_samples_to_q_coll(q_coll, in_coll, in_coll_to_qpcr_plate_hash)
        q_rc_list = in_coll_to_qpcr_plate_hash.keys.map {|q_coord| q_coord}
        show do
            title "Adding Experimental Samples to #{q_coll}"
            separator
            note "Transfer samples from <b>Dilution_#{in_coll}</b> to pre-filled <b>#{q_coll}</b>."
            note "Follow the alpha coordinates to tranfer the appropriate row of wells from the input to the qPCR plate:"
            bullet "Try to avoid creating bubbles at the bottom of the well."
            bullet "The alpha numeric coordinates represent the wells from <b>Dilution_#{in_coll}</b>"
            table highlight_alpha_rc(q_coll, q_rc_list){|r,c| "#{ get_alpha_coord( in_coll_to_qpcr_plate_hash[[r,c]] ) }" }
        end
        show do
            title "Adding Experimental Samples to #{q_coll}"
            separator
            check "Finally, seal with see through seal and place on ice."
        end
        q_coll.location = 'On Ice'
        q_coll.save
    end
    
    
    
    def add_qpcr_master_mix_to_q_collection(q_coll)
        show do
            title "Aliquoting qPCR Master Mix to #{q_coll}"
            separator
            check "Gather a clean new #{q_coll.object_type.name} and label it: <b>#{q_coll}</b>"
            note "Use a multichannel pipette and follow the table below to aliquot #{"qPCR Master Mix"}:"
            table highlight_alpha_non_empty(q_coll){|r,c| "18#{MICROLITERS}"}
        end
    end
    def add_standard_curve_to_q_collection(q_coll)
        std_rc_display_matrix = Array.new(8) { Array.new(3) {-1} } 
        std_rc_list = q_coll.get_non_empty.select {|r,c| [0,1,2].include? c }
        std_rc_list.each {|r,c| std_rc_display_matrix[r][c] = "STD\n#{r + 1}" }
        show do
            title "Adding Standard Curve to #{q_coll}"
            separator
            note "<b>MAKE SURE TO HAVE STRIPWELL IN THE CORRECT ORIENTATION</b>"
            note "Use a multichannel pipette to transfer <b>2#{MICROLITERS}</b> of each standard curve dilution to the appropriate well:"
            bullet "Try to avoid creating bubbles at the bottom of the well."
            table highlight_alpha_rc(q_coll, std_rc_list){|r,c| "#{ std_rc_display_matrix[r][c]}" }
        end
    end
    def centrifuge_qpcr_plates(qpcr_collections)
        show do
            title "Centrifuge qPCR Plates"
            separator
            check "Centrifuge the following qPCR plates at 500 x g for  to collect all reagents to the bottom of the well and make sure there are no bubbles"
            qpcr_collections.each {|q_coll| bullet "<b>#{q_coll}</b>"}
            check "Finally, place on ice until qPCR thermocycler workspace is is ready"
        end
    end

end # Module QPCR_Preparation
