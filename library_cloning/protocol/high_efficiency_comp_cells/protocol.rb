# Devin Strickland
# dvn.strcklnd@gmail.com
# edited by SG for batching
needs 'Yeast Display/YeastDisplayHelper'

class Protocol 
    
    include YeastDisplayHelper
    
    # I/O
    INPUT="Yeast Culture"
    OUTPUT_1="Comp Cells 1"
    OUTPUT_2="Comp Cells 2"
    OUT_STR="Comp Cells %d"
    
    WATER = "<b>sterile water</b>"
    SORBITOL_CACL = "<b>1 M sorbitol + 1 mM CaCl2</b>"
    CULTURE_WASH_VOL = { qty: 25, units: 'ml' }
    CULTURE_WASH_BUFFERS = [WATER, WATER, SORBITOL_CACL] 
    SUSPENSION_WASH_VOL = { qty: 10, units: 'ml' }
    SUSPENSION_BUFFER = SORBITOL_CACL
    TRANSFORMATION_VOL = { qty: 180, units: 'ul' }
    
    INCUBATION_FLASK = 'prewarmed 250 ml <b>baffled</b> flask'
    
    ON_ICE = { style: 'bg-color: powderblue', temp: 'ON ICE' }
    ROOM_TEMP = { style: 'bg-color: lightorange', temp: 'AT ROOM TEMPERATURE' }
    
    ADD_WASH_BUFFER = "Add %{vol} of chilled %{liquid} to each tube with a <b>cold</b> serological pipette."
    RESUSPEND_CELLS = 'Resuspend the pellets with a new <b>%{temp}</b> serological pipette.'
    SPIN_CELLS = 'Spin the tubes for 3 min at 3000 rpm in the 4°C large centrifuge.'
    REMOVE_BUFFER = 'Pour off the supernatant, being careful to not disturb the cell pellets.'
    CONICAL = '50 ml conical tube'
    SPLIT_INTO_CONICALS_POUR = "Transfer %{vol} of the %{liquid} into each #{CONICAL} (you may pour)"
    SPLIT_INTO_CONICALS_PIPETTE = "Transfer %{vol} of the %{liquid} into each #{CONICAL} using a <b>chilled</b> serological pipette"
    
    RECOVERY_MEDIA="YPAD (peptone)"
    DTT="1mM DTT"
    LIAC_DTT="0.1M LiAc + 1mM DTT"
    LIAC="0.1M LiAc"
    
    WORK_LOC="the BIOFAB station closest to the large centrifuge"
    DTT_VOL={ qty: 210, units: 'ul' }
    LiAc_VOL={ qty: 21, units: 'ml' }
    LIAC_DTT_VOL={ qty: 10, units: 'ml' } 
    SPARE_VOL={ qty: 4, units: 'ml' } 
    SHAKE_TIME={ hr: 0, min: 30, sec: 0 } 
    NANODROP_DIL_VOL={ qty: 900, units: 'µl' } 
    NANODROP_SAMPLE_VOL={ qty: 100, units: 'µl' } 
    
    TARGET_OD=1.6
    MAX_OD=1.8
    NANODROP_FAC=100
    
    INCUBATOR="30C incubator"
    FREEZER="SF2 or M20"
    COMP_ALIQUOTS_PER_OP = 2
    

    def main
        
        intro
        
        operations.retrieve.make
        
        measure_OD
        
        centrifuge_cultures({ vol: '50 ml', liquid: 'culture'}, SPLIT_INTO_CONICALS_POUR, 0)
        
        wash_cultures
        
        resuspend_in_lithium_acetate
        
        centrifuge_cultures({ vol: '10 ml', liquid: 'suspension'}, SPLIT_INTO_CONICALS_PIPETTE, 1)
        
        wash_with_sorbitol
        
        resuspend_in_sorbitol
        
        operations.each { |op|
            op.input(INPUT).item.mark_as_deleted
            op.output(OUTPUT_1).item.move_to("Bench, on ice")
            op.output(OUTPUT_2).item.move_to("Bench, on ice")
        }
        
        # operations.store
        
        return {}
    
    end
    
    #--------------------------------------------------------------------------------
    
    def intro
        
        show do
            title "Before starting..."
            note "You should be working at #{WORK_LOC}"
            note " "
            note "All materials needed for this protocol are ready at one of the following locations:"
            note "The bench (possibly on ice)"
            note "The #{INCUBATOR}"
            note "#{FREEZER}"
            note " "
            note "This protocol and the following one (High Efficiency Transformation) take a few hours to run!"
        end
        
    end
    
    def measure_OD
        
        show do
            title "Dilute and Measure OD of culture(s)"
            check "Grab an empty (room temperature) #{CONICAL} and label it #{RECOVERY_MEDIA}"
            check "Grab #{operations.length} empty 1.5 mL tube(s) and label them <b>dilution</b>"
            if(operations.length>1)
                check "Additionally label the <b>dilution</b> tubes <b>#{operations.map { |op| op.input(INPUT).item}.to_sentence}</b>"
            end
            check "Pour approximately #{SPARE_VOL[:qty] + operations.length} #{SPARE_VOL[:units]} of #{RECOVERY_MEDIA} into the labeled #{CONICAL}"
            check "Transfer #{NANODROP_DIL_VOL[:qty]} #{NANODROP_DIL_VOL[:units]} of #{RECOVERY_MEDIA} from the #{CONICAL} to each of the labeled <b>dilution</b> tubes"
            check "Transfer #{NANODROP_SAMPLE_VOL[:qty]} #{NANODROP_SAMPLE_VOL[:units]} of each of the cultures: <b>#{operations.map { |op| op.input(INPUT).item}.to_sentence}</b> to the corresponding <b>dilution</b> 1.5mL tube"
            check "Take the <b>dilution</b> tubes and the #{RECOVERY_MEDIA} #{CONICAL} to the nanodrop, make sure you are on the <b>Cell Culture</b> setting"
            check "Blank with #{RECOVERY_MEDIA}"
            check "Enter the OD of the culture(s) in the following table <b>EXACTLY</b> as it appears on nanodrop:"
            table operations.start_table
              .input_item(INPUT)
              .get(:input_OD, type: 'number', heading: "OD", default: 0) 
              .end_table 
            note "If any cultures have not yet reached OD #{TARGET_OD} (#{(TARGET_OD.to_f/NANODROP_FAC).round(3)} on nanodrop), return them to 30ªC, 250 rpm shaking for an additional #{SHAKE_TIME[:qty]} #{SHAKE_TIME[:units]} and remeasure. Do not let cells grow past OD #{MAX_OD}."
        end
        
        # associate some numbers in debug
        operations.each { |op| op.temporary[:input_OD]="0.017"} if debug
        
        operations.each { |op|
            op.input(INPUT).item.associate :input_OD, op.temporary[:input_OD].to_f
        }
        
        # TO DO: make sure all cultures are of the same type first!!!
        show do
            title "Mix Cultures"
            check "Mix the cultures by combining them in one flask and swirling the flask gently for a few seconds"
        end 
        
    end
    
    
    def centrifuge_cultures(substitutions, str, doRemove)
        show do
            title "Centrifuge %{liquid}" % substitutions
            note temp_instructions(ON_ICE)
            if(doRemove>0)
                check REMOVE_BUFFER
            end
            check str % substitutions
            note "The cultures are identical at this point - there is no need to label"
            check SPIN_CELLS
        end
    end
    
    def wash_cultures
        substitutions = { vol: qty_display(CULTURE_WASH_VOL), temp: 'cold' }
        
        CULTURE_WASH_BUFFERS.each_with_index do |wash_buffer, ii|
            substitutions[:liquid] = wash_buffer
            wash_cells(substitutions, "(wash #{ii + 1} of #{CULTURE_WASH_BUFFERS.length})", 1 )
        end
    end
    
    def wash_with_sorbitol
        substitutions = { vol: qty_display(SUSPENSION_WASH_VOL), temp: 'cold', liquid: SORBITOL_CACL }
        wash_cells(substitutions, "(Sorbitol)", 1)
    end
    
    def wash_cells(substitutions, str, doRemove)
        show do
            title "Wash pellets #{str}"
            note temp_instructions(ON_ICE)
            if(doRemove>0)
                check REMOVE_BUFFER
            end
            check ADD_WASH_BUFFER % substitutions 
            check RESUSPEND_CELLS % substitutions
            check SPIN_CELLS
        end
    end
    
    def resuspend_in_lithium_acetate
        show do
            title 'Prepare lithium acetate (LiAc)'
            note temp_instructions(ROOM_TEMP)
            check "Grab <b>prewarmed #{LIAC}</b> from #{INCUBATOR} and relabel it <b>#{LIAC_DTT}</b>"
            check "Add #{operations.length*DTT_VOL[:qty]} #{DTT_VOL[:units]} (#{operations.length} aliquots) of <b>room temperature #{DTT}</b> to the container labeled <b>#{LIAC_DTT}</b>"
            check "Mix <b>#{LIAC_DTT}</b> container briefly"
        end
        show do
            title 'Resuspend pellets in lithium acetate (LiAc)'
            warning "In the following, you may use a single <b>room temperature</b> serological pipette"
            check REMOVE_BUFFER
            check "Add #{LIAC_DTT_VOL[:qty]} #{LIAC_DTT_VOL[:units]} of the <b>prewarmed #{LIAC_DTT}</b> to each #{CONICAL} tube containing pellet"
            check RESUSPEND_CELLS % { temp: 'room temperature' }
            check 'Using the same pipette, transfer all cell suspensions to a <b>single</b> %s' % INCUBATION_FLASK
            check 'Place the flask in an incubator to shake at 250 rpm and 30ªC. Start the timer.'
            timer initial: { hours: SHAKE_TIME[:hr], minutes: SHAKE_TIME[:min], seconds: SHAKE_TIME[:sec]}
        end 
    end
    
    def resuspend_in_sorbitol
        cc_ids=[]
        operations.each_with_index { |op, ii|
            COMP_ALIQUOTS_PER_OP.times do |jj|
                cc_ids=[cc_ids, op.output("#{OUT_STR % (jj + 1)}").item].flatten
            end
        }
        substitutions = { vol: qty_display(TRANSFORMATION_VOL), temp: 'cold', liquid: SORBITOL_CACL }
        show do
            title 'Resuspend pellets'
            note temp_instructions(ON_ICE)
            check REMOVE_BUFFER
            check ADD_WASH_BUFFER % substitutions
            check 'Resuspend the pellets with a new <b>%{temp}</b> 1mL tip or <b>brief</b> vortex' % substitutions 
            check "Label the #{CONICAL}s: <b>#{(1..(COMP_ALIQUOTS_PER_OP*operations.length)).to_a.to_sentence}</b>" # previously #{cc_ids.to_sentence} 
            warning "Keep aliquots on ice and proceed <b>immediately</b> to High-Efficiency Transformation" 
        end
    end

end
