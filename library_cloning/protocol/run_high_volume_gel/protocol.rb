# modified by SG for high-volume extraction
# batching: NOT to be batched with other operations at this point
needs "Cloning Libs/Cloning" # for check_concentrations
needs "Standard Libs/UploadHelper" # for image upload

class Protocol
    
    include UploadHelper   
    include Cloning
    
    # I/O
    LENGTH = "Fragment length (bp)" # needed for choice of ladder
    VOLTAGE = "Voltage (V)"
    TIME = "Time (min)"
    GEL="Gel"
    STRIPWELL="Reactions"   
    UNCUT="Parent plasmid" # control
    OUTPUT="Fragment"
    
    MIN_PLASMID_QUANTITY=500.0 # ng
    THRESHOLD_LENGTH=500 # bp, threshold for decision between 1Kb and 500bp ladders
    LADDER_VOL=7 # uL
    DYE_VOL=5 # uL, less than used for 50uL to avoid losing material when loading 
    MIN_VOL=2 # uL, for uncut plamid 
    MIN_DYE_VOL=2 # uL, for dye for uncut plamid
    SPARE_VOL = 2
    NORMAL_RUN_TIME = 45 # min
    GEL_DIR="/bioturk/Dropbox/GelImages/" # dir where gel images are saved on computer

    COLOR="#e6e6ff" # light purple 
    GEL_TABLE=[ ["uncut plasmid","ladder",{ content: "1", style: {background: COLOR} } ,{ content: "2", style: {background: COLOR}} ,{ content: "3", style: {background: COLOR}} ,{ content: "4", style: {background: COLOR}} ],
                ["uncut plasmid","ladder",{ content: "5", style: {background: COLOR} }, { content: "6", style: {background: COLOR}} ,{ content: "7", style: {background: COLOR} },{ content: "8", style: {background: COLOR} }] ]

    def main
        
        # get stuff: gel, reaction
        operations.retrieve 
        # get more stuff
        dye = Item.where(sample_id: (Sample.find_by_name("6X Loading Dye").id)).select { |i| !i.deleted? }.first
        ladder_100bp=nil
        ladder_1K=nil
        need_100bp = operations.map { |op| (op.input(LENGTH).val < THRESHOLD_LENGTH) }.include?(true) 
        need_1K = operations.map { |op| (op.input(LENGTH).val >= THRESHOLD_LENGTH) }.include?(true) 
        items=[dye]
        if(need_100bp)
            ladder_100bp = Sample.find_by_name("100 bp Ladder").in("Ladder Aliquot").first
            items.push(ladder_100bp)
        end
        if(need_1K)
            ladder_1K = ladder = Sample.find_by_name("1 Kb Ladder").in("Ladder Aliquot").first
            items.push(ladder_1K)
        end
            
        take items, interactive: true
        
        # make output item(s)
        operations.make
        
        # no real batching here because we assume reactions will take up full gel  
        operations.each do |op| 
            
            # ladders for display
            ladder=ladder_1K
            GEL_TABLE[0][1]="1 Kb Ladder"
            GEL_TABLE[1][1]="1 Kb Ladder"
            if(op.input(LENGTH).val < THRESHOLD_LENGTH)
                ladder=ladder_100bp
                GEL_TABLE[0][1]="100 bp Ladder"
                GEL_TABLE[1][1]="100 bp Ladder"
            end
            
            # set up power supply
            show do
                title "Set up the power supply"
                note  "In the gel room, obtain a power supply and set it to <b>#{op.input(VOLTAGE).val} V</b> and with a <b>#{op.input(TIME).val} min</b> timer."
                note  "Attach the electrodes of an appropriate gel box lid from A7.525 to the power supply."
                image "Items/gel_power_settings.JPG" 
            end
            
            # set up gel
            show do
                title "Set up the gel box(es)"
                check "Remove the casting tray(s) (with gel(s)) and place it/them on the bench."
                check "Using the graduated cylinder at A5.305, fill the gel box(s) with 200 mL of 1X TAE from J2 at A5.500. TAE should just cover the center of the gel box(es)."
                check "With the gel box(es) electrodes facing away from you, place the casting tray(s) (with gel(s)) back in the gel box(s). The top lane(s) should be on your left, as the DNA will move to the right."
                check "Using the graduated cylinder, add 50 mL of 1X TAE from J2 at A5.500 so that the surface of the gel is covered."
                check "Remove the comb(s) and place them in the appropriate box(s) in A7.325."
                check "Put the graduated cylinder back at A5.305."
                image "Items/gel_fill_TAE_to_line.JPG"
            end
            
            # uncut plasmid - positions (1,1) and (2,1) 
            conc = op.input(UNCUT).item.get(:concentration)
            if(op.input(UNCUT).item.get(:concentration).nil? || op.input(UNCUT).item.get(:concentration).to_f == 0)
                # measure concentration of combine sample
                data=show do 
                    title "Measure concentration of uncut plasmid <b>#{op.input(UNCUT).item}</b> on nanodrop"
                    check "Vortex sample <b>#{op.input(UNCUT).item}</b> and spin down"
                    get "number", var: "conc", label: "Enter concentration of <b>#{op.input(UNCUT).item}</b> (ng/µL)", default: 0
                end
                conc=data[:conc]
                # associate concentration
                op.input(UNCUT).item.associate :concentration, conc
            end
            if(debug)
                op.input(UNCUT).item.associate :concentration, "101"
            end
            conc = op.input(UNCUT).item.get(:concentration).to_f
            
            # calculate: want 500ng at least of uncut plasmid, at least MIN_VOL uL in volume
            vol = [ (MIN_PLASMID_QUANTITY/conc).round(1), MIN_VOL].max 
            dye_vol = [(vol.to_f/5).round(2), MIN_DYE_VOL].max 
            show do
                title "Prepare aliquot of uncut plasmid control (C)"
                check "Grab an empty 1.5 mL tube and label it <b>C</b>. It will hold the uncut plasmid (control)." 
                check "Transfer <b>#{2*vol} µL</b> of uncut plasmid #{op.input(UNCUT).item} to the tube labeled <b>C</b>" 
            end
            
            # add dye to fragments, assume 1 PCR or digest reaction in each tube
            show do 
                title "Add loading dye to samples and control"
                check "Add <b>#{DYE_VOL} µL</b> of dye #{dye} to all non-empty wells in stripwell #{op.input(STRIPWELL).item}"
                check "Add <b>#{2*dye_vol + SPARE_VOL} µL</b> of dye #{dye} to the tube labeled <b>C</b>"
                note "Make sure samples and dye are well mixed"
            end
            
            # load samples
            show do
                title "Load control, ladder, samples, and on gel"
                check "Pipette <b>#{vol+dye_vol} µL</b> from the tube labeled <b>C</b> to positions (1,1) and (2,1) of gel #{op.input(GEL).item}"
                check "Pipette <b>#{LADDER_VOL} µL</b> of the ladder #{ladder} to positions (1,2) and (2,2) of gel #{op.input(GEL).item}"
                note "Load the samples from the stripwells into the shaded gel lanes in the following table:"
                table GEL_TABLE
                check "Transfer the entire contents of each stripwell into an empty gel lane"
                note "You should be able to get each full reaction volume into 1 lane. You may combine material from different stripwell wells in the same lane - all stripwells contain the same sample."   
            end
            
            # run gel
            show do
                title "Start electrophoresis"
                note "Carefully attach the gel box lid(s) to the gel box(es), being careful not to bump the samples out of the wells. Attach the red electrode to the red terminal of the power supply, and the black electrode to the neighboring black terminal. Hit the start button on the power supply - usually a small running person icon."
                note "Make sure the power supply is not erroring (no E* messages) and that there are bubbles emerging from the platinum wires in the bottom corners of the gel box on the left side"
                #image "Actions/Gel/" # nit sure what to show here!!!
            end
            
             # cleanup
            show do 
                title "Discard stripwells, control"
                note "Discard all the empty stripwells and tube labeled <b>C</b>"
                op.input(STRIPWELL).item.mark_as_deleted
            end
        
            run_time = op.input(TIME).val.to_f
            loop_ind=0
            
            # loop over gel run
            loop do
                
                # stopping condition
                break if((run_time<10) || (loop_ind>3))
            
                #  timer
                show do
                    title "Set a timer"
                    check "When you get back to your bench, set a <b>#{[run_time, NORMAL_RUN_TIME].min} min</b> timer" 
                end
                
                # update run time (may be negative)
                run_time = run_time - NORMAL_RUN_TIME
                
                # take image of gel and upload if will be running longer
                if(run_time >= 10)
                    show do
                        title "Take image of gel"
                        check "When the timer is up, image the gel. Save the image on the local computer as <b>gel_image_#{loop_ind}_#{op.input(GEL).item}</b>"
                    end
                    ups = uploadData("#{GEL_DIR}gel_image_#{loop_ind}_#{op.input(GEL).item}", 1, 3) # 1 image, 3 tries
                    if(ups.nil?) # should not happen!
                        show {note "no uploads, nothing to associate..."}
                        #return
                    end
                    if(!ups.nil?)
                        if(!ups[0].nil?)
                            op.plan.associate "gel_image_#{loop_ind}", "combined gel fragment", ups[0]
                            op.output(OUTPUT).item.associate "gel_image_#{loop_ind}", ups[0]
                        end
                    end
                end
                
                # update index for image
                loop_ind = loop_ind+1 
                
            end # loop
            
            #  timer
            show do
                title "Cleanup"
                check "When the timer is up, turn off the power supply" 
                note "An image will be taken in the next protocol"
            end
            
        end # operations.each
    
        release items, interactive: true 
    
        return {}
    
    end # main  
 
end # protocol
