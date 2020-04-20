

module RNAkits
    
    QIAGEN = {'mirneasy_kit' => ['Buffer RWT', 'miBuffer RPE'], 'rneasy_kit' => ['Buffer RLT', 'Buffer RW1', 'Buffer RPE']}
    
    def prepare_lysate(rna_kit, ops)
        case rna_kit
        when 'miRNeasy_Kit'
            show do
                title "Preparing Lysate"
                separator
                
                check "To the aqueous phase, add <b>500ul</b> of 100% Ethanol and resuspend by pipetting."
                note "Next, pipette <b>700ul</b> of the sample, including any of the the precipitate into a pink miRNeasy column."
                table ops.start_table
                .custom_column(heading: "2nd Tube #") { |op| op.temporary[:tube]}
                .custom_column(heading: "Transfer to", checkable: false ) { |op| "====>"}
                .custom_column(heading: "#{rna_kit} Columns") { |op| op.temporary[:tube] }
                .end_table
                separator
                note centrifuge()
                note "Repeat step using the remainder of the sample, if any."
            end
        when rna_kit == 'RNeasy_Kit'
            show do
                title "Preparing Lysate"
                separator
                
                note "Using a new filter tip each time, add <b>350 ul</b> of ice cold EtOH to each lysate and resuspend throughly."
                ops.each {|op| check "#{tube_name(op)}"} # tube_name takes op and determines what methods were used to process determining what its tube name is
                note "Place on ice after mixing."
            end
            show do
                title "Isolating RNA"
                separator
                
                note "The addition of EtOH to our lysate, in the previous step, allows the nucleic acids (RNA) to bind to the silica based RNeasy column."
                # check "Add <b>350 uL</b> of ice cold Ethanol to each lysate and mix by pipetting."
                check "For each sample, transfer all <b>700 ul of lysate</b> to new RNeasy column"
                table ops.start_table
                .custom_column(heading: "Cell Lysing Tube") { |op| tube_name(op)}
                .custom_column(heading: "Transfer to", checkable: false ) { |op| "====>"}
                .custom_column(heading: "#{rna_kit} Columns") { |op| op.temporary[:tube] } 
                .end_table
                separator
                check "Next, use a centrifuge <b>(8000g for 15s)</b> or apply vacuum to pull lysate through column."
                note "Discard the flow-through and reuse the collection tube."
            end
        end
    end

    # Centrifuge settings for QIAGEN RNA kits
    def centrifuge(time="~15s")
        speed="> 8,000 x g"
        return  "Close lid, centrifuge at <b>#{speed}</b> for <b>#{time}</b>, and discard flow through."
    end

    
    # Directs tech using QIAGEN kit protocol - Assumes that all sample have been processed to yeast lysates ready to be placed into the qiagen columns
    # Which is why there are no variables for this func
    def qiagen_kit()
        # Determines which kits will be used 
        rna_kits = operations.map {|op| op.input('RNA Kit').val}.uniq
        rna_kits.each {|rna_kit|
            ops = operations.select {|op| op.input('RNA Kit').val == rna_kit}
            prepare_lysate(rna_kit, ops)
        }
        
        show do
            title "DNase I Digest"
            separator
            
            note "<b>Follow the table to dispense the correct buffer:</b>"
            table operations.start_table
            .custom_column(heading: "Qiagen Column") {|op| op.temporary[:tube]}
            .custom_column(heading: "Add 350ul", checkable: true ) { |op| "<===>"}
            .custom_column(heading: "Qiagen Buffer", checkable: false ) { |op| op.input('RNA Kit').val == 'miRNeasy_Kit' ? 'Buffer RW-T' : 'Buffer RW-1'}
            .end_table
            check "Next, use a centrifuge <b>(8000g for 15s)</b> or apply vacuum to pull buffer through column."
        end
        
        show do
            title "DNase I Digest"
            separator
            
            # DNase I step
            note "To prevent any genomic DNA from contaminating our RNA, we will use DNase I to digest any lingering gDNA."
            separator
            check "Next, add <b>80ul of DNase I + RDD</b> mixture directly onto each of the column membranes - use a new tip each time."
            check "Incubate at room temperature (on bench) for 15 mins"
            ### Google timer 15 mins
            separator
            note "<b>When timer is complete, follow the table to dispense the correct buffer:</b>"
            table operations.start_table
            .custom_column(heading: "Qiagen Column") {|op| op.temporary[:tube]}
            .custom_column(heading: "Add 350l", checkable: true ) { |op| "<===>"}
            .custom_column(heading: "Qiagen Buffer", checkable: false ) { |op| op.input('RNA Kit').val == 'miRNeasy_Kit' ? 'Buffer RW-T' : 'Buffer RW-1'}
            .end_table
            check "Next, use a centrifuge <b>(8000g for 15s)</b> or apply vacuum to pull buffer through column."
        end
        
        washes = 0
        (2).times do
            show do 
                title "Washing RNA on RNeasy Column"
                separator
                
                note "<b>Follow the table to dispense the correct buffer:</b>"
                table operations.start_table
                .custom_column(heading: "Qiagen Column") {|op| op.temporary[:tube]}
                .custom_column(heading: "Add 500l", checkable: true ) { |op| "<===>"}
                .custom_column(heading: "Qiagen Buffer", checkable: false ) { |op| op.input('RNA Kit').val == 'miRNeasy_Kit' ? 'miBuffer RPE' : 'Buffer RPE'}
                .end_table
                check "Next, add buffer let stand for 1 min."
                check "Next, use a centrifuge <b>(8000g for 15s)</b> or apply vacuum to pull buffer through column."
                (washes > 0) ? (note "Discard collection tube and gather a clean one from the Qiagen Kits") : (note "Discard the flow-through and as before, reuse the collection tube.")
            end
            washes += 1
        end

        show do
            title "Removing Excess Buffer"
            separator
            
            note "From, the Qiagen Kits gather <b>#{operations.length}</b> clean 2mL collection tubes."
            check "Place the pink RNeasy columns into the new collection tubes."
            check "Centrifuge for <b>1 min at full speed</b> to remove excess buffer."
        end
        
        show do
            title "Eluting RNA with Water"
            separator
            
            # check "Get #{num_ops} new 1.5-mL RNeasy collection tubes and label each collection tube with a number from 1 to #{num_ops}"
            check "Remove the spin columns from the 2-mL collection tubes or from vacuum and place them in the new RNase-Free 1.5-mL tubes"
            table operations.start_table
            .custom_column(heading: "Qiagen Column") {|op| op.temporary[:tube]}
            .custom_column(heading: "Transfer to", checkable: true ) { |op| "====>"}
            .custom_column(heading: "Final Tube", checkable: false ) { |op| op.output('Total RNA').item.id }
            .end_table
            note "Using a new filter tip, directly pipette <b>30ul RNase-free water</b> to the spin column membrane."
            note "Let stand for 3 mins"
            check "Close the lid gently and centrifuge for 1 minute at 8000g (10,000 rpm) to elute the RNA."
            # check "Close the lid gently and centrifuge again to elute the RNA."
        end
    end
    


    
end # module