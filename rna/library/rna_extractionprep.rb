# Eriberto Lopez
# elopez3@uw.edu
# Updated 08/15/18


needs 'RNA/RNAkits'
module RNA_ExtractionPrep
    
    include RNAkits
    
    ICE_LOC = "Seelig Lab".freeze
    DNASE_LOC = {'dnase' => '-20C freezer', 'rdd' => '4C Mini Fridge'}
    
    def rna_extraction_prepartion(input_str, output_str, method_str, cell_lysis_str)
        # Get ice 
        get_ice() 
        # Clean area
        sanitize
        # Assigns each operation a tube num to coordinate tubes
        assign_tube_nums
        # Assigns an extraction obj for each operation
        assign_extraction_obj(cell_lysis_str, method_str, input_str)
        # operations.each {|op| log_info op.temporary[:rna_params][:rna_kit]}
        # Prepares and labels tubes for processing samples and final collection tubes, in order to coordinate sample transfers in protocol
        prep_tubes(input_str, output_str, cell_lysis_str, method_str)
        # Gathers buffers from Qiagen kits that will be used in this experiment
        qiagen_buffs
        # Prepare required tubes & buffers based on the qiagen kit used
        prep_lysis_buffs(method_str)
        # Create DNase I and place on ice
        onColumn_dnase(operations.length)
        # Good stopping point if people need to leave or tech transfer
        stopping_point
    end
    
    
    def stopping_point
        show do
            title "Stopping Point"
            separator
            warning "This is a good stopping point."
            note "Make sure that all tubes are labeled."
            note "Be sure to place any buffers that contain enzymes on ice"
        end
    end

    #µl
    # Gives a quick introduction to experiment
    def intro()
        show do 
            title "Introduction - RNA Extraction"
            separator
            
            note "This protocol will guide you to extract and isolate pure total RNA from cells, which can be used in other assays like qPCR and RNA Sequencing."
            note "By isolating the RNA from a culture, we can assess what genes are being actively transcribed."
            separator
            note "<b>1.</b> Prepare tubes and reagents needed for procedure."
            note "<b>2.</b> Lyse cells."
            note "<b>3.</b> Use Qiagen column to isolate and clean RNA."
        end
    end
    
    # Directs tech to get ice and lower centrifuge temp
    def get_ice(cool_centrifuge=true)
        show do
            title "Get Ice"
            separator
            note "<b>Keeping samples and reagents cold is important to slow down enzymes that may diminish nucleic acid integrity.</b>"
            check "Grab a foam bucket from underneath the sink."
            check "Go to the #{ICE_LOC} ice machine and fill up your bucket."
            # check "Fill a foam ice bucket, located underneath sink."
            if cool_centrifuge
                check "Set a benchtop and large centrifuge to 4°C"
            end
        end
    end

    # Directs tech to sanatize working area  
    def sanitize()
        equiptment = ["RNA-P1000","RNA-P200","RNA-P20", "Tube Block", "Bench Top", "Other"]
        show do
            title "Isolating RNA Effectively"
            separator
            warning "<b>Working with RNA can be tricky, since it is very sensitive to RNases.</b>"
            note "To prevent the degradation of our RNA and our hard work we must take care to use our best aseptic technique."
            note ""
            note ""
            check "Wipe down area and equiptment you will be using with <b>70% EtOH</b> & <b>RNase ZAP</B>"
            equiptment.each {|e| bullet "<b>#{e}</b>"}
            separator
            warning "<b>Keep RNase ZAP on hand use whenever necessary.</b>"
        end
    end
    
    
    # assigns each operation a tube id
    def assign_tube_nums
        operations.each_with_index { |op, idx|
          op.temporary[:tube] = idx + 1
        }
    end

    def assign_extraction_obj(cell_lysis_str, method_str, input_str)
        operations.each_with_index { |op, idx|
            op.temporary[:rna_params] = {
                cell_lysis: op.input(cell_lysis_str).val,
                rna_kit: op.input(method_str).val,
                input_object_type: op.input(input_str).object_type.name
            }
        }
    end
    
    # Directs tech to prepare tubes for processing and collecting final sample
    #
    # @params input [string] input from protocol definitions
    # @params output [string] output from protocol definitions
    def prep_tubes(input_str, output_str, cell_lysis_str, method_str) 
        y_overnights = operations.select {|op| op.input(input_str).object_type.name == "Yeast Overnight Suspension" }
        log_info 'y_overnights', y_overnights.each {|op| op.input(input_str).object_type.name}
        
        # Select which operations have specific extraction parameters in order to account for tubes needed in protocol
        zymo_tubes = operations.select {|op| op.input(cell_lysis_str).val == 'Enzymatic'}
        scrw_caps = operations.select {|op| op.input(input_str).object_type.name == 'Yeast Overnight Suspension'}.select {|op| op.input(cell_lysis_str).val == 'Mechanical'}
        ext_tubes = operations.select {|op| op.input(method_str).val == 'miRNeasy_Kit'}
        rneasy_cols = operations.select {|op| op.input(method_str).val == 'RNeasy_Kit'}
        mi_rneasy_cols = operations.select {|op| op.input(method_str).val == 'miRNeasy_Kit'}
        final_tubes = operations.length
        
        # Gathers and labels tubes for samples 
        show do
            title 'Preparing Tubes'
            separator
            note 'Gather the following materials:'
            (!scrw_caps.empty?) ? (note "<b>#{scrw_caps.length}</b> - 2mL Screw Cap tubes and label <b>#{scrw_caps.map { |op| op.temporary[:tube]}}</b>" ) : nil
            (!zymo_tubes.empty?) ? (note "<b>#{zymo_tubes.length}</b> - 1.5mL microfuge tubes and label <b>#{zymo_tubes.map { |op| "ZD#{op.temporary[:tube]}"}}</b>" ) : nil
            (!rneasy_cols.empty?) ? (note "<b>#{rneasy_cols.length}</b> - RNeasy Kit Columns and label <b>#{rneasy_cols.map {|op| op.temporary[:tube]}}</b>" ) : nil
            separator
            (!ext_tubes.empty? || !mi_rneasy_cols.empty?) ? (note "Place the following in a tube rack in the fume hood when ready:" ): nil
            (!ext_tubes.empty?) ? (note "<b>#{ext_tubes.length * 2}</b> - 1.5mL RNase Free tubes and label each pair <b>#{ext_tubes.map {|op| op.temporary[:tube]}}</b>" ) : nil
            (!mi_rneasy_cols.empty?) ? (note "<b>#{mi_rneasy_cols.length}</b> - miRNeasy Kit Columns and label <b>#{mi_rneasy_cols.map {|op| op.temporary[:tube]}}</b>" ) : nil
            note "<b>#{final_tubes}</b> - 1.5mL RNase-Free Tubes and use sticker dots to label <b>#{operations.map {|op| op.output(output_str).item.id}}</b>"
        end
        
        
        
        # Table format of gathering tubes and allows for a visual mapping of which sample will go into what tubes
        headers = ["Item ID", "Zymolase Digest", "2mL Screw Cap", "1st Extract", "2nd Extract", "RNeasy Columns", "miRNeasy Columns", "Final Tube ID"]
        show do
            title 'Preparing Tubes Table'
            separator
            note "<b>This table shows the previous slide in a table format</b>"
            table operations.start_table
                .custom_column(heading: headers[0]) { |op| op.input(input_str).item.id}
                .custom_column(heading: headers[1]) { |op| (op.input(cell_lysis_str).val == 'Enzymatic') ? op.temporary[:tube] : '--'}
                .custom_column(heading: headers[2]) { |op| (op.input(cell_lysis_str).val == 'Mechanical' && op.input(input_str).object_type.name == 'Yeast Overnight Suspension') ? op.temporary[:tube] : '--'}
                .custom_column(heading: headers[3]) { |op| (op.input(method_str).val == 'miRNeasy_Kit') ? op.temporary[:tube] : '--'}
                .custom_column(heading: headers[4]) { |op| (op.input(method_str).val == 'miRNeasy_Kit') ? op.temporary[:tube] : '--' }
                .custom_column(heading: headers[5]) { |op| (op.input(method_str).val == 'RNeasy_Kit') ? op.temporary[:tube] : '--' }
                .custom_column(heading: headers[6]) { |op| (op.input(method_str).val == 'miRNeasy_Kit' ) ? op.temporary[:tube] : '--' }
                .custom_column(heading: headers[7], checkable: true) { |op|  op.output(output_str).item.id}
            .end_table
        end
        
        # Gathers falcon tubes for quenching overnight suspension and/or falcon tubes for organic reagents used in miRNeasy method
        (!y_overnights.empty?) ? falcons = y_overnights.map {|o| o.input(input_str).item.id} : falcons = []
        (!mi_rneasy_cols.empty?) ? falcons = falcons.concat(['QIAzol', '100% Ethanol', 'Chloroform']) : falcons
        if (!falcons.empty?) 
            show do 
                title "Labeling and Preparing Tubes"
                separator
                note "Gather <b>#{falcons.length}</b> 15mL falcon tubes and label:"
                falcons.each {|i| check "<b>#{i}</b>"}
            end
        end
    end

    # Selects buffers used based on which QIAGEN RNA kits are being used in this experiment
    def qiagen_buffs()
        kits = operations.map {|op| op.input('RNA Kit').val}.uniq
        log_info kits
        q_buffs = kits.map {|k| QIAGEN[k.downcase]}
        show do
            title "From the RNA Qiagen Kit"
            separator
            note '<b>Gather:</b>'
            q_buffs.flatten.each {|buff| check "#{buff}"}
            check "Make sure ethanol is added to buffers that require it before use."
            note "<b>Set buffers aside on bench until use.</b>"
        end
    end
    
    def prep_lysis_buffs(method_str)
        group_by_method = operations.map.group_by {|op| op.input(method_str).val}
        group_by_method.each { |meth_arr|
            method = meth_arr[0]
            num_ops = meth_arr[1].length
            # Prepare Buffers and Reagents necessary
            prepare_buffs(method, num_ops)
        }
    end

    # Directs tech to prepare buffers for rna etraction method
    #
    # @params method [string] is the type of QIAGEN rna kit being used for the experiment
    # @params num_ops [integer] how many operations/samples are being processed
    def prepare_buffs(method, num_ops)
        
        case method.downcase
        when 'rneasy_kit'
            # determines how much buffer Y1 to create if there are any operations that are going to use the Enzymatic cell lysing
            enzymatic_ops = operations.select {|op| op.input("Lysis Method").val == 'Enzymatic'}
            (!enzymatic_ops.empty?) ? buff_Y1_b_me = prepare_bufferY1(enzymatic_ops.length) : buff_Y1_b_me = 0
            
            # Aliquots the necessary RLT from kit
            buff_rlt_b_me = prepare_RLT(num_ops)
            
            # Direct tech to dispense b_mercaptoethanol in fume hood
            dispense_b_mercap(buff_Y1_b_me, buff_rlt_b_me)
            
        when 'mirneasy_kit'
            # gather tubes for qiazol and chloroform to take in hood
            prepare_qiazol_chlfrm_etoh(num_ops)
        end
    end
    
    # Directs tech to aliquot RLT buffer 
    #
    # @params num_ops [integer] how many operations/samples are being processed
    # @return b_me [integer] is the amount of microliters to resuspend in RLT in the proceeding steps
    def prepare_RLT(num_ops)
        rlt = (num_ops + 0.2) * 350#ul
        b_me = rlt.to_f/1000.0
        rlt_tab = [
            ["# of Samples", "RLT (mL)"],
            [num_ops].concat([(rlt/1000).round(2)].map { |v| { content: v, check: true } })
        ]
        show do 
            title "Preparing Lysis Buffer (RLT)"
            separator
            if rlt > 15000
                check "Grab a clean 50mL Falcon tube and label => <b>RLT Buffer</b>"
            elsif rlt.between?(1500, 14900)
                check "Grab a clean 15mL Falcon tube and label => <b>RLT Buffer</b>"
            else
                check "Grab a clean 1.5 Eppie tube and label => <b>RLT Buffer</b>"
            end
            
            note "From the RNeasy Kit, grab the RLT reagent and follow the table below:"
            table rlt_tab
            note "Once done, place RLT Buffer on ice until ready for use!"
        end
        return b_me
    end

    # Directs tech to create enzymatic method buffer
    #
    # @params num_ops [integer] how many operations/samples are being processed
    # @return b_me [float] is the amount of microliters to resuspend in RLT in the proceeding steps
    def prepare_bufferY1(num_ops)
        
        # Calculating total volumes for ingrediants in buffer Y1
        tot_vol = 100 * (num_ops + 0.2)
        sorb =  50 * (num_ops + 0.2)
        edta = 20 * (num_ops + 0.2)
        b_me = 0.1 * (num_ops + 0.2)
        zymo_units = (tot_vol.to_f/1000.0) * 100 # 100U per 1mL of buffer
        zymo = zymo_units/5 # total units divided by stock concentration 5U per ul - vol from zymo stock
        h2o = tot_vol - (sorb + edta + b_me + zymo)
        
        buffer_Y1 = show do
            title "Preparing Zymolase Buffer"
            separator
            note "This buffer will be used to breakdown the cell walls of our yeast so they can be easily lysed."
            note "You will need:"
            note "<b>#{sorb} uL</b> of 2M Sorbitol "
            note "<b>#{edta} uL</b> of 0.5M EDTA."
            select [ "Yes", "No"], var: "sorbitol", label: "Is there enough 2M Sorbitol buffer to continue?", default: 0
            select [ "Yes", "No"], var: "edta", label: "Is there enough 0.5M EDTA buffer to continue?", default: 0
        end
        
        if buffer_Y1[:sorbitol] == "Yes" && buffer_Y1[:edta] == "Yes"
            buffer_Y1_tab = [
                ["# of Samples", "Total Vol (uL)", "H2O (uL)", "2M Sorbitol (uL)", "0.5M EDTA (uL)", "Zymolase (uL)"], 
                [num_ops, tot_vol].concat([h2o.round(1), sorb.round(2), edta.round(2), zymo.round(2)].map { |v| { content: v, check: true }})  
            ] 
            show do
                title "Preparing Buffer Y1"
                separator
                check "Grab a clean #{tot_vol < 1501 ? '1.5mL Eppie tube' : '15mL Falcon tube' } and label => <b>Buffer Y1</b>"
                note "Follow the table below to create Buffer Y1:"
                table buffer_Y1_tab
                check "Once Buffer Y1 is made place on ice until noted!"
            end
        else
            # Hieu's recipe if there is not enough buffers made for Buff Y1
            n = num_ops
            show do 
                title "Prepare a #{n * 2 * 1.10} mL solution of Buffer Y1" #1 M sorbitol and 0.1 M EDTA (need 2 ml per extraction)
                separator
                # sorbitol powder (Molar Mass = 182.17 g/mol) and EDTA powder (Molar Mass = 292.24 g/mol)
                #pH 7.4
                check "Obtain a clean, sterile beaker that can hold at least #{n * 2} mL"
                check "Label the beaker 'Buffer Y1'"
                check "Obtain sorbitol powder and EDTA powder from the chemical cabinet."
                #check "Retrieve the zymolyase enzyme from the freezer and keep it on an enzyme block"
                check "Clean two chemical spatulas and one magnetic stirbar with ethanol"
                check "Add the following amounts of reagents into the beaker"
                table [["Sorbitol (g)", {content: n * 0.36434 * 1.10, check: true}],
                      ["EDTA (g)", {content: n * 0.058448 * 1.10, check: true}], 
                      ["Zymolase (uL)", {content: n * 5 * 1.10, check: true}]]
                check "Add DI water up to approximately the #{n * 2 * 1.10} mark"
                check "Drop the magnetic stirbar into the beaker"
                check "Cover the beaker with foil and stir the solution on a magnetic stirplate"
    
                #check "Return zymolase to the freezer after use"
            end
        end
        return b_me
    end
    
    # Directs tech to dispense b-mercaptoethanol into rlt and buff y1 in the fume hood
    #
    # @params buff_Y1_b_me [integer] amount of b-me (ul) this buffer needs
    # @params buff_rlt_b_me [integer] amount of b-me (ul) this buffer needs
    def dispense_b_mercap(buff_Y1_b_me, buff_rlt_b_me)
        buff = 'Beta-Mercaptoethanol'
        
        # Prepares fumehood for working with organics
        prepare_fumehood(buff)
        
        # while in fumehood also aliquot ethanol required
        get_etoh()
        
        # add b-me to both
        b_me_tab = [
            ["Buffer(s)", "#{buff} (uL)"]
        ]
        (buff_Y1_b_me != 0) ? b_me_tab.push(["Buffer Y1"].concat([buff_Y1_b_me].map{ |v| { content: v, check: false }})) : nil
        (buff_rlt_b_me != 0) ? b_me_tab.push( ["RLT Buffer"].concat( [(buff_rlt_b_me * 10)].map{ |v| { content: v, check: false }} )) : nil # 10ulB-E : 1mL RLT
        
        show do 
            title "Dispense Beta-Mercaptoethanol in Fume Hood"
            separator
            # check "Bring the test tube containing <b>Buffer Y1</b> and the test tube containing <b>Buffer RLT<b/> to the fume hood"
            warning "The next step should be done in the fumehood"
            note "Follow table below to and take the listed tubes to the fume hood"
            table b_me_tab
            check "After dispensing B-ME, clean pipettes and gloves with EtOH to prevent B-ME from leaving fume hood."
            check "<b>Place both tubes on ice until later use.</b>"
        end
    end
    
    # Aliquot of ethanol
    def get_etoh()
        # create 70% EtOH for RNeasy
        tot_vol = (operations.length + 1) * 0.350
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
            check "<b>Place both tubes on ice until later use.</b>"
        end
    end    

    # Directs tech on how to work with volatile reagents in the fume hood and prepare them for later use
    #
    # @params num_ops [integer] how many operations/samples are being processed
    def prepare_qiazol_chlfrm_etoh(num_ops)
        reagents = 'QIAzol, Chloroform, & Ethanol'
        
        # prepares fumehood for working with organics
        prepare_fumehood(reagents)
        
        # Calcs the required reagent volumes in mLs
        qia_vol = (num_ops * 0.7) + 0.2#mLs
        chlfrm_vol = (num_ops * 0.44) + 0.2#mLs
        etoh_vol = (num_ops * 0.5) + 0.2#mL
        
        show do
            title "Aliquoting #{reagents} in the Fume Hood"
            separator
            note "Gather a <b>tube rack</b>"
            note "Gather <b>#{reagents.split(',').length}</b> falcon tubes that are able to hold the volumes below."
            reagents_tab = [
                ["# of Samples","QIAzol (ml)", "Chloroform (ml)", "100% Ethanol (ml)"], 
                [num_ops, qia_vol.round(3), chlfrm_vol.round(3), etoh_vol] 
            ] 
            table reagents_tab
            note "Leave #{reagents} in fumehood until needed."
            note "<b>Once finished, cap and store properly.</b>"
        end
    end
    
    # Directs tech to prepare DNase I for later use. Also, gives direction to refill DNase stock if necessary
    #
    # @params num_ops [integer] how many operations/samples are being processed
    def onColumn_dnase(num_ops)
        dnase = (num_ops) * 10#ul
        rdd = (num_ops) * 70#ul
        tot_vol = dnase + rdd
        arr = ['DNase', 'RDD']
        headers = arr.map{|x| "#{x} (µl)"}
        tab = [ headers, [dnase, rdd].map {|i| {content: "#{i}", check: true}} ]
        check_dnase = show do
            title "Preparing DNase I"
            separator
            check "Gather <b>1</b> clean #{(tot_vol > 1501) ? ('15mL Falcon tube') : ('1.5 mL eppie tube')} and label: <b>DNase + RDD</b>"
            check "Gather Qiagen RDD Buffer in #{DNASE_LOC[arr[1].downcase]}, you will need: <b>#{rdd}ul</b>"
            check "Gather <b>#{num_ops}</b> DNase I 10ul Aliquot(s) in #{DNASE_LOC[arr[0].downcase]} and thaw on ice."
            select [ "Yes", "No"], var: "dnase", label: "Are there enough DNase aliquots? If not, select 'No' and proceed to the next step."
            separator
            note 'In an eppendorf tube mix by pipetting:'
            table tab
            note "<b>Once finished set on ice until needed & proceed to the next step.</b>"
        end
        
        # if user selected no then a new DNase I must be openned and prepared   
        # Also, gives instructions to make dnase for current experiment
        if check_dnase[:dnase] == "No"
            show do
                title "Prepare DNase I"
                separator
                
                check "Prepare DNase I stock solution by injecting/dispensing <b>550µl</b> of RNase-free water in to the DNase I vial."
                note "Mix gently by inverting."
                check "Next, aliquot <b>#{num_ops * 10}µl</b> of DNase into a clean 1.5 mL eppie tube."
                check "To the same tube, add <b>#{num_ops * 70}µl</b> of Buffer RDD."
                note "Mix by inverting and centrifuge briefly to collect at the bottom."
                note "<b>Place on ice until ready to use.</b>"
                note "Finally, aliquot the rest of the DNase into a new clean stripwell(s) - <b>10µl</b> in each well."
                check "When finished, store DNase I aliquots at -20C"
            end
        end
    end


end # module