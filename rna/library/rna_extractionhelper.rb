# By: Eriberto Lopez
# elopez3@uw.edu
# 03_09_18
# µl
# Updated: 08/15/18

module RNA_ExtractionHelper
    # QIAGEN = {'mirneasy_kit' => ['Buffer RWT', 'miBuffer RPE'], 'rneasy_kit' => ['Buffer RLT', 'Buffer RW1', 'Buffer RPE']}
    # DNASE_LOC = {'dnase' => '-20C freezer', 'rdd' => '4C Mini Fridge'}
    
    HOMOGENIZER = {'settings' =>"1800 rpm for 120 secs", "location" =>"Baker Lab"}
    METHOD = "RNA Kit" # Type of kit used determines the protocol used
    CELL_LYSIS = "Lysis Method"
    
    INPUT = "Yeast Pellet"
    OUTPUT = "Total RNA"
    
    
    
    # TODO: lysing_container() and tube_name() are very similar code refactor and use one
    # Determines tube label based on cell lysis method
    #
    # @parms op [operation obj] single operation that is being labeled
    def lysing_container(op)
        # log_info op.input(CELL_LYSIS).val
        if op.input(CELL_LYSIS).val == 'Enzymatic'
            return "ZD_#{op.temporary[:tube]}"
        elsif op.input(CELL_LYSIS).val == 'Mechanical'
            return "Screw cap-#{op.temporary[:tube]}"
        end
    end
    
    # Deterimines tube label based on cell lysis method, rna kit, and object type
    #
    # @parms op [operation obj] single operation that is being labeled
    def tube_name(op)
       cell_lysis = op.input(CELL_LYSIS).val
       method = op.input(METHOD).val
       object_type = op.input('Yeast Pellet').object_type.name
       
       if object_type == 'Yeast Overnight Suspension'
           cell_lysis == 'Mechanical' ? "Screw Cap-#{op.temporary[:tube]}" : "ZD_#{op.temporary[:tube]}"
       else
           op.input('Yeast Pellet').item.id
       end
    end
    
    def nanodrop_rna_extracts(input_str, output_str)
        # measure RNA concentration on nanodrop
        # nanodrop and get concentration - Example
        show do 
            title "Nanodrop and Enter Concentration"
            separator
            warning "BE SURE YOU BLANK AND USE THE RNA MODE ON THE NANODROP"
            note "Nanodrop each RNA extract and enter the concentration below:"
            table operations.start_table
                .output_item(output_str)
                .get(:concentration, type: "number", heading: "Concentration", default: 000)
            .end_table
        end
        
        # set concentration of isolate RNA - taken from mini prep protocol
        operations.running.each do | op |
            op.set_output_data "Total RNA", :concentration, op.temporary[:concentration]
            op.set_output_data "Total RNA", :from, op.input(input_str).item.id
            op.plan.associate "yeast_#{op.input(input_str).sample.id}".to_sym, op.input(input_str).item.id
            op.plan.associate :total_rna, op.output(output_str).item.id
            op.input(input_str).child_item.store
        end
    end


    
    # Directs tech on how to quench yeast overnight suspensions
    #
    # @params overnight_ops [Array] array of input overnight operationss 
    # @params input [string] string describing the input from the protocol definitions
    def quenching(overnight_ops, input)
        items = overnight_ops.map { |op| op.input(input).item}
        # typical overnight is 2mLs (1:1 cult:60%meoh)
        
        # Preps the amount of MeOH and 1XPBS necessary and prefills tubes
        meoh_vol = (overnight_ops.length + 0.5) * 2#mL
        pbs_vol = (overnight_ops.length + 0.5) * 1#mL
        show do
            title "Gather Quenching Materials"
            separator
            note "For this step, you will need <b>#{meoh_vol}mL</b> of ice cold 60% MeOH (location: <b>-20°C Freezer</b>)"
            note "For this step, you will need <b>#{pbs_vol}mL</b> of ice cold 1X PBS (location: <b>4°C Fridge</b>)"
            check "<b>Pre-chill the 15mL falcon tubes listed below on ice.</b>"
            items.each {|i| bullet "#{i.id}"}
            check "Fill each tube with <b>2mL</b> of 60% MeOH."
            note "Once filled proceed to the next step."
        end
        
        # Gathers overnights and transfers culture to prefilled tubes
        take items, interactive: true
        show do
            title "Quenching Cells in Methanol (MeOH)"
            separator
            check "Transfer <b>2mL</b> of overnight to the same numbered Falcon tube."
            check "Once cells are quenched, centrifuge in large centrifuge for <b>5 min at 4,800 g</b>."
            check "Once pelleted, aspirate supernatant."
            check "Resuspend pellet in <b>1mL</b> ice cold 1X PBS and transfer to the <b>Cell Lysing Tube</b>."
            table overnight_ops.start_table
                .custom_column(heading: "Quenching Tube") { |op| op.input(input).item.id}
                .custom_column(heading: "Transfer to", checkable: true ) { |op| "====>"}
                .custom_column(heading: "Cell Lysing Tube") { |op| lysing_container(op)}
            .end_table
            check "Finally, centrifuge at 12,000 g for 2mins and aspirate supernantant."
        end
    end
    
    # Directs tech to lyse cells based on lysis method - 
    # 
    # @param lys_arr [array] an array that was grouped by lysis method ie: ['lysis method string', [array of operations]]
    def cell_lysis(lys_arr)
        lys_method = lys_arr[0] # string
        ops = lys_arr[1] # arr of ops
        
        case lys_method
        when 'Enzymatic'
            generating_sphereo(ops)
            
        when "Mechanical"
           bead_beating(ops)
           
           # NOTE: There are samples that are extracted mechanically that do not require phase separation
           chloro_ops = ops.select {|op| op.input(METHOD).val == 'miRNeasy_Kit'}
           (!chloro_ops.empty?) ? phase_separtion(chloro_ops) : nil
        end
    end
    
    # Directs tech to use an enzymatic approach to lyse yeast cells
    #
    # @params ops [array] an array of operations that will be lysed Enzymatically
    def generating_sphereo(ops)
        # Count cells???/ retrieve OD info
        show do 
            title "Generating Spheroplasts"
            separator
            note "Spheroplasts are yeast cells that do not have a cell walls."
            note "They are easily lysed through osmotic pressure created by RLT Buffer in the following steps."
            separator
            check "Centrifuge samples <b>12,000g for 2mins</b> and remove supernatant - <b>if necessary</b>."
            check "Next, resuspend cell pellet in <b>100µl</b> of Buffer Y1 throughly by pipetting up and down - avoid foaming."
            table ops.start_table
            .custom_column(heading: 'Cell Lysing Tube') { |op| "ZD_#{op.temporary[:tube]}"}
            .custom_column(heading: 'Buffer Y1 (µl)', checkable: true) {|op| '100'}
            .end_table
            check "Once all samples have been resuspended, incubate the tubes in the 30°C incubator."
            check "Start timer for <b>25 minutes</b> to generate spheroplasts and every ~10-15 mins check and flick tube to keep cells suspended."
            note "<b>Proceed to the next step while timer is going.</b>"
        end
        
        show do
            title "Collecting Spheroplats"
            separator
            
            note "When timer has finished, centrifuge samples <b>300g for 5 mins</b> to collect spheroplasts"
            # check "Remove the supernatant and avoid disturbing sphereoplast pellet."
            check "Pipette off the supernatant and be careful to not lose or disturb the sphereoplast pellet at the bottom."
        end
        
        show do 
            title "Lysing Spheroplasts"
            separator
            warning "During the following steps, keep sample on ice and as cold as possible!"
            note "Using a new filter tip each time, use <b>350 uL</b> of ice cold RLT buffer to resuspend sphereoplast pellet(s)."
            bullet "To ensure cell lysing, make sure to resuspend sphereoplast pellet(s) throughly - resuspend at least 10 times."
            table ops.start_table
            .custom_column(heading: "Yeast Pellet") { |op| tube_name(op)}
            .custom_column(heading: "Lysis Buffer", checkable: false ) { |op| op.input(METHOD).val == 'RNeasy_Kit' ? 'RLT' : 'QIAzol'}
            .custom_column(heading: "Vol (µl)", checkable: false ) { |op| op.input(METHOD).val == 'RNeasy_Kit' ? '350' : '700' }
            .end_table
            note "Vortex and place tubes on ice until the next step."
            check "Once all samples have been resuspeneded and lysed, incubate on ice for 1 min before continuing to the next step."
            ### google timer - 1 mins
        end
    end

    # Directs tech on how to prepare samples for homogeniger/bead beater
    #
    # @params ops [Array] an array of operations that will be lysed Mechanically
    def bead_beating(ops)
        items = ops.map {|op| op.input(INPUT).item.id}
        img1 = 'Actions/RNA/miRNeasy_kit/tube_with_beads_2.png'
        img2 = 'Actions/RNA/miRNeasy_kit/lyse_homogenize.png'
        img3 = 'Actions/RNA/homogenizer_layout.jpg'
        # samples being taken out of freezer have different tube labeling than ones prepared from fresh cultures
        fresh_pellets = ops.select {|op| op.input(INPUT).object_type.name == 'Yeast Overnight Suspension'}.map {|op| "Screw Cap-#{op.temporary[:tube]}"}
        freezer_pellets = ops.select {|op| op.input(INPUT).object_type.name == '2 mL Screw Cap Tube'}.map {|op| op.input(INPUT).item.id}
        screw_cap_tubes = (!fresh_pellets.empty?) ? fresh_pellets : []
        (!freezer_pellets.empty?) ? screw_cap_tubes.concat(freezer_pellets) : nil
        # log_info 'fresh_pellets', fresh_pellets, 'freezer_pellets', freezer_pellets
        # log_info 'screw_cap_tubes', screw_cap_tubes
        show do 
            title "Preparing Samples for Homogenizer"
            separator
            
            image img1
            note "Fill the following tubes with approximately the same amount of beads:"
            screw_cap_tubes.flatten.each {|t| note "#{t}"}
            warning "Keep cell pellets on ice!"
        end
        
        show do
            title "Aliquoting Lysis Reagent"
            separator
            
            image img2
            warning "The next step should be done in the fumehood."
            note "Take ice bucket and the following samples into fumehood:"
            table ops.start_table
            .custom_column(heading: "Yeast Pellet") { |op| tube_name(op)}
            .custom_column(heading: "Lysis Buffer", checkable: false ) { |op| op.input(METHOD).val == 'RNeasy_Kit' ? 'RLT' : 'QIAzol'}
            .custom_column(heading: "Vol (µl)", checkable: false ) { |op| op.input(METHOD).val == 'RNeasy_Kit' ? '350' : '700' }
            .end_table
            note "When done make sure caps are screwed tight to prevent spilling and place back on ice."
        end
        
        show do
            title "MP Biomedical Homogenizer"
            separator
            
            warning "The next step will be done in the #{HOMOGENIZER['location']} in the Homogenizer Room."
            check "Check the image below to ensure samples are secure."
            image img3
            # Image of bead beater setup
            check "Set Homogenizer to: <b>#{HOMOGENIZER['settings']}</b>"
            bullet "For this experiment, do 2 min ON, 1 min OFF (on ice), and 2 mins ON"
            note "After lysing cells, place samples back on ice."
        end
        
        show do
            title "Homogenized Lysate"
            separator
            
            check "Bring samples back to bench and vortex for <b>10s</b>."
            warning "<b>It is no longer important to keep samples on ice. Proceed to the next step.</b>"
            check "Incubate samples at room temperature for <b>5 mins</b>."
            ### timer 5 mins
        end
    end
    
    # Directs tech on how to identify and collect the aqueous phase where RNA is found
    #
    # @params chloro_ops [Array] an array of operations that were lysed mechanically and require phase separation
    def phase_separtion(chloro_ops)
        # samples being taken out of freezer have different tube labeling than ones prepared from fresh cultures
        fresh_pellets = chloro_ops.select {|op| op.input(INPUT).object_type.name == 'Yeast Overnight Suspension'}.map {|op| "Screw Cap-#{op.temporary[:tube]}"}
        freezer_pellets = chloro_ops.select {|op| op.input(INPUT).object_type.name == '2 mL Screw Cap Tube'}.map {|op| op.input(INPUT).item.id}
        screw_cap_tubes = (!fresh_pellets.empty?) ? fresh_pellets : []
        (!freezer_pellets.empty?) ? screw_cap_tubes.concat(freezer_pellets) : nil
        img3 = 'Actions/RNA/miRNeasy_kit/add_chloroform.png'
        img4 = 'Actions/RNA/miRNeasy_kit/phase_separation_1.png'
        img5 = 'Actions/RNA/miRNeasy_kit/phase_separation_2.png'

        show do
            title "Phase Separation"
            separator
            
            image img3
            warning "The next step should be done in the fume hood."
            note 'Take samples to the fumehood:'
            screw_cap_tubes.each {|op| note "#{op}"}
            note '<b>Make sure to equilibrate pipette before transferring volatile liquids.</b>'
            note 'Carefully, dispense <b>200µl</b> of Chloroform to each sample and cap tightly.'
            check 'Vortex samples for <b>15s</b>.'
            check 'Incubate samples at room temperature for <b>2 mins</b>.'
            ### timer 2 mins
            check 'Finally, centrifuge for <b>15 mins</b> at <b>12,000 x g</b> at <b>4C</b>'
        end
        
        show do 
            title "Phase Separation"
            separator
            
            image img4
            warning "The next step should be done in the fume hood."
            warning 'Obtaining clean pure RNA is more important than amount. In the next step take care not to pipette any of the organic phase.'
            note 'From the top aqueous phase, take <b>~130µl</b> and place in a new, clean tube.'
            table chloro_ops.start_table
            .custom_column(heading: "Yeast Lysate") { |op| op.input(INPUT).object_type.name == 'Yeast Overnight Suspension' ? "Screw Cap-#{op.temporary[:tube]}" : op.input(INPUT).item.id}
            .custom_column(heading: "Transfer to", checkable: false ) { |op| "====>"}
            .custom_column(heading: "1st Tube #") { |op| op.temporary[:tube] }
            .end_table
        end
        
        show do 
            title "Phase Separation"
            separator
            
            image img5
            warning "The next step should be done in the fume hood."
            note 'Next, add <b>240µl of Chloroform</b> to each new tube, screw cap on tight, and vortex for <b>15s</b>.'
            check 'Finally, centrifuge for <b>8 mins</b> at <b>12,000 x g</b> at <b>4C</b>'
            warning 'Obtaining clean pure RNA is more important than amount. In the next step take care not to pipette any of the organic phase.'
            note 'From the top aqueous phase, take <b>~100µl</b> and place in a new, clean tube.'
            table chloro_ops.start_table
            .custom_column(heading: "1st Tube #") { |op| op.temporary[:tube]}
            .custom_column(heading: "Transfer to", checkable: false ) { |op| "====>"}
            .custom_column(heading: "2nd Tube #") { |op| op.temporary[:tube] }
            .end_table
        end
    end

    
    
    
    # Directs tech to clean Fume Hood safetly 
    def clean_fumehood()
        show do
            title "Fume Hood Cleanup"
            separator
            check "Make sure that the any bottle is securely capped, and put away in its proper storage cabinet."
            check "Fold the absorbent pad from the outside edges inward, and dispose it in the gallon waste bag."
            check "Wipe the outside of any containers used, the buffer aliquot container(s), pipettes, and the fume hood surface with 70% ethanol."
            check "Remove gloves using proper technique and dispose in the waste bag. Leave the waste bag and waste jar in the fume hood. Make sure everything is tidy and close the fume hood."
        end
    end

 
    # Gives directions on how to setup fume hood before working with volatile reagents
    #
    # @params reagents [string] reagents being used in experimental method (miRNeasy_Kit) separated by commas
    def prepare_fumehood(reagents)
        show do
            title "Prepare the Fume Hood for Working With #{reagents}"
            separator
            
            warning "The following steps must be done in the fume hood!"
            warning 'These reagents are very volatile and can cause serious harm!'
            note "Wear the appropriate PPE and properly dispose of any waste properly to <b>prevent contamination of other lab equiptment</b>."
            note "If need be, please review the #{reagents} SOP for more safety and procedural documentation."
            note "Make sure the ventilation fan is on and that the glass barrier is open just enough to work comfortably."
            check "Double glove, then wipe down the fume hood work surface with ethanol and line with an absorbent pad."
            check "Retrieve the #{reagents} container from the storage cabinet and set aside."
        end 
    end    
    
    # Aliquot of ethanol
    def get_etoh()
        tot_vol = (operations.length + 1) * 0.350
        # create 70% EtOH for RNeasy
        etoh_vol = (tot_vol * 0.7).round(1) #mL
        h2o_vol = (tot_vol * 0.3).round(1) #mL
        show do
            title "Aliquot 70% Ethanol (EtOH)"
            separator
            
            note "In the fume hood aliquot the necessary amount of 100% EtOH."
            note "Molecular Grade EtOH is under the fume hood in the flame proof cabinet."
            note "<b>Materials needed:</b>"
            # check "Serological pipette & pipetter"
            check (tot_vol < 1.51) ? '1.5mL Eppie' : '15mL Falcon'
            check "Dispense <b>#{etoh_vol}mL of 100% EtOH</b> into the tube."
            check "Dispense <b>#{h2o_vol}mL of Mol. Grade H2O</b> into the tube."
        end
    end    
end # Module