# Devin Strickland
# dvn.strcklnd@gmail.com
#
# edited by SG
#
# NOTES:
# 1) need to make multiple dilutions if want more than 2 transformations (depending on operations.length)
needs "Standard Libs/SortHelper"
needs "Yeast Display/YeastDisplayShows"

class Protocol

    include SortHelper
    include YeastDisplayShows
    
    # I/O
    INPUT="Yeast Culture"
    OUTPUT="Yeast Culture"    
    # MIX1="DNA Mix 1"
    # MIX2="DNA Mix 2"
    
    # other - current dilution 
    MAX_OPS=4 # limit on dilutions from single starting culture. do not have enough overnight culture for more than this, ODs bef/after = (~3*50)/(0.4*100) = 3.75
    FLASK_500 = "500 mL <b>baffled</b> flask"
    DIL_MEDIA="YPD (peptone)"
    DIL_VOL=100 # mL
    OD_TARGET=0.4 # for 1cm
    DIL_FACTOR=10 # 10 for 1mm-1cm conversion. ASSUMES WE ARE MEASURING IN THE BIOFAB.
    SHAKER="30C shaker"
    SHAKE_TIME={ hr: 1, min: 30} # hr
    SAFETY_FAC=1.2 # for extra volume
    DEBUG_ODS=[0.45,0.36,0.2]
    
    # other - prep for later protocols
    
    # temperature conditions
    WARMED = "<b>AT 30C (in incubator)</b>"
    ROOM_TEMP = "<b>AT ROOM TEMPERATURE (on bench)</b>"
    ON_ICE = "<b>ON ICE (in bucket on bench)</b>"
    
    # locations
    ICE_LOCATION="the Seelig lab"
    DTT_LOC="M20 (cardboard box labeled 'DTT aliquots')"
    FREEZER="SF2 or M20"
    
    # containers, labware
    INCUBATION_FLASK = '250 ml <b>baffled</b> flask'
    CONICAL = '50 ml conical tube'
    CONICAL_VOL=50 # mL
    CUVETTE = 'eppendorf 2mm gap electroporation cuvette' 
    PIPETTE = '25 mL serological pipette'
    TIP = '1000 µL tip'
    FLASK_250B="250 mL <b>baffled</b> flask"
    FLASK_250NB="250 mL <b>non-baffled</b> flask"
    FLASK_500B="500 mL <b>baffled</b> flask"
    
    # media
    WATER ='sterile water'
    YPD="YPD (peptone)"
    SELECTION_MEDIA="C-His-Trp-Ura"
    SORBITOL='Sorbitol 1M'
    CACL='CaCl2 1M'
    SORBITOL_CACL ='1M Sorbitol + 1mM CaCl2'
    SORBITOL_YPD = '1M Sorbitol:YPD 1:1'
    DTT="DTT 1M"
    LIAC="Lithium acetate (LiAc) 1M"
    LIAC_DIL="Lithium acetate (LiAc) 0.1M"
    
    DILUTION_MEDIA=YPD
    DILUTION_PLATE_MEDIA = "C-His-Trp-Ura"
    
    # quantities per single dilution op (2 transformations)
    TIPS_PER_BOX=96
    TIPS_PER_OP=20
    PIPETTES_PER_OP=12
    CUVETTES_PER_OP=2
    CONICALS_PER_OP=4
    DILUTION_PLATES_PER_OP = 6 # 3 per transformation
    FLASK_250B_WARMED_PER_BATCH=1  # for batched growth in LiAc before transformation
    FLASK_250NB_PER_OP=2 # recovery, 1 per transformation
    FLASK_500B_PER_OP=2  # final overnight in selective media, 1 per transformation

    # media
    WATER_VOL = { qty: 110, units: 'ml'} 
    SELECTION_MEDIA_VOL = { qty: 230, units: 'ml' } 
    
    LIAC_VOL = { qty: 2.1, units: 'ml'}         # LiAc 1M
    LIAC_DIL_VOL = { qty: 19, units: 'ml' }    # water 
    DTT_VOL = { qty: 210, units: 'µL'} 
    
    SORBITOL_VOL = { qty: 55, units: 'ml'} 
    CACL_VOL ={ qty: SORBITOL_VOL[:qty], units: 'µl'} # 1:1000
    SORBITOL_CACL_VOL = { qty: 55, units: 'ml'}
    
    SORBITOL_FOR_YPD_VOL = { qty: 10, units: 'ml'}
    SORBITOL_YPD_VOL = { qty: 20, units: 'ml'}
    YPD_VOL=SORBITOL_FOR_YPD_VOL # need 1:1
    
    
    def main 
        
        # one overnight is good for up to ~4 morning dilutions - so errror any operations past this
        if(operations.length > MAX_OPS)
            first_ops=operations[0..(MAX_OPS-1)]
            err_ops=operations.select { |op| !(first_ops.include? op) }
            err_ops.each { |op|
                op.error :not_enough_culture, "There is not enough overnight culture to run this operation." 
            }
            show do
                title "Too many Dilution operations, limit is #{MAX_OPS}."
                note "Errored the following operations: #{err_ops.map{|op| op.id}.to_sentence}"
            end
        end
        ops=operations.running 
        # sort by input culture for sequential ordering of outputs
        sorted = sortByMultipleIO(operations.running, ["in"], [INPUT], ["item"], ["io"])
        operations=sorted
         
        #show { note "ops.len=#{operations.length}"}
        
        operations.make
        
        # prep flasks
        show do
            title "Prepare flasks for dilution"
            note "Grab #{operations.length} #{FLASK_500}(s)"
            note "Get #{DIL_MEDIA} (containing at least #{(SAFETY_FAC*operations.length*DIL_VOL).round(1)} mL)"
            check "Label the flask(s): <b>#{operations.map { |op| op.output(OUTPUT).item}.to_sentence}</b>"
            check "Pour #{DIL_VOL} mL of #{DIL_MEDIA} into each labeled flask"
            check "Prepare holders for #{operations.length} #{FLASK_500}(s) in #{SHAKER}"
        end
        
        # get cultures only
        take operations.map { |op| op.input(INPUT).item }.uniq, interactive: true
        
        # OD
        measure_culture_ods(operations)
        
        # associate some numbers in debug
        operations.each { |op| op.temporary[:od]=DEBUG_ODS.rotate!.first } if debug
        show { note "ODs = #{operations.map { |op| op.temporary[:od] }.to_sentence}" } if debug
        
        operations.each { |op|
            op.input(INPUT).item.associate :od, op.temporary[:od].to_f
        }
        
        # dilute - now into approximately 100mL, for ease of prep
        # into 100 mL exactly:
        # culture: (DIL_VOL*OD_TARGET/(DIL_FACTOR*op.input(INPUT).item.get(:od).to_f)).round(1) 
        # media:   (DIL_VOL-DIL_VOL*OD_TARGET/(DIL_FACTOR*op.input(INPUT).item.get(:od).to_f) ).round(1) 
        show do
            title "Dilute"
            note "Transfer the following volumes of culture and #{DILUTION_MEDIA} to the indicated #{FLASK_500}, according to the table:"
            table operations.start_table
                .input_item(INPUT)
                .custom_column(heading: "Culture Volume (mL)", checkable: true) { |op| 
                    od_one_over=1/(DIL_FACTOR*op.input(INPUT).item.get(:od).to_f)
                    (DIL_VOL*OD_TARGET*od_one_over/(1-OD_TARGET*od_one_over)).round(1) 
                }  
                .custom_column(heading: "#{DIL_MEDIA} Volume (mL)") { |op| 
                    DIL_VOL 
                }  
                .output_item(OUTPUT)
                .end_table
            check "Place flask(s) <b>#{operations.map { |op| op.output(OUTPUT).item.id}.to_sentence}</b> in #{SHAKER}"
            # check "Start #{SHAKE_HR} hr timer. When it finishes, OD will be measured (in next protocol)."
            timer initial: { hours: SHAKE_TIME[:hr], minutes: SHAKE_TIME[:min], seconds: 0}
            note "OD600 will be measured (in next protocol) when timer finishes. Continue to next steps."
        end
         
        # cleanup - cultures
        show do 
            title "Cleanup"
            check "Dispose of overnight culture(s) <b>#{operations.map { |op| op.input(INPUT).item}.uniq.to_sentence}</b>"
        end
        
        prep_for_later
        
        # get DNA mixes
        # mixes=[operations.map { |op| op.input(MIX1).item }, operations.map { |op| op.input(MIX2).item }].flatten
        # take mixes, interactive: true #, method: "boxes"  
        
        # prep for later
        gather_materials()
        
        operations.each { |op|
            op.input(INPUT).item.mark_as_deleted
            op.output(OUTPUT).item.move_to(SHAKER)
            # op.input(MIX1).item.move_to("ice bucket")
            # op.input(MIX2).item.move_to("ice bucket")
        }
    
    end
    
    #---------------------------------------------------------------------------------
    
    def prep_for_later
        
        liac_container=CONICAL
        sorbitol_ypd_container=CONICAL
        
        if( (SAFETY_FAC*operations.length*LIAC_DIL_VOL[:qty]).ceil > CONICAL_VOL )
            liac_container="sterile glass bottle (with cap) with volume of at least #{(SAFETY_FAC*operations.length*LIAC_DIL_VOL[:qty]).ceil} #{LIAC_DIL_VOL[:units]}"
        end
        if( (SAFETY_FAC*operations.length*SORBITOL_YPD_VOL[:qty]).ceil > CONICAL_VOL)
            sorbitol_ypd_container="sterile glass bottle (with cap) with volume of at least #{(SAFETY_FAC*operations.length*SORBITOL_YPD_VOL[:qty]).ceil} #{SORBITOL_YPD_VOL[:units]}"
        end
        
        show do
            title "Prepare the following for later"
            check "Lower the large centrifuge to 4ªC. Leave a note so that it is left at 4ªC for the whole day."
            check "Bring a large bucket of ice (from #{ICE_LOCATION})"
            check "Grab #{operations.length} aliquot(s) of #{DTT} from #{DTT_LOC} and allow to defrost at room temperature"
            
            check "Prepare <b>#{SORBITOL_CACL}</b> as follows:"
            note "Get a sterile glass bottle (with cap) with volume of at least #{(SAFETY_FAC*operations.length*SORBITOL_CACL_VOL[:qty]).ceil} #{SORBITOL_CACL_VOL[:units]}. Label it <b>#{SORBITOL_CACL}</b>."
            note "Add #{(SAFETY_FAC*operations.length*SORBITOL_VOL[:qty]).round(1)} #{SORBITOL_VOL[:units]} of #{SORBITOL}" 
            note "Add #{(SAFETY_FAC*operations.length*CACL_VOL[:qty]).round(1)} #{CACL_VOL[:units]} of #{CACL}"
            note "Close cap and shake briefly to mix"
            
            # no SAFETY_FAC for LiAc because need to add exactly 1 210uL aliquot of DTT to each 21mL LiAc 
            check "Prepare <b>#{LIAC_DIL}</b>, as follows:"
            note "Get a #{liac_container}. Label it <b>#{LIAC_DIL}</b>"
            note "Add #{(operations.length*LIAC_DIL_VOL[:qty]).round(1)} #{LIAC_DIL_VOL[:units]} of #{WATER}"
            note "Add #{(operations.length*LIAC_VOL[:qty]).round(1)} #{LIAC_VOL[:units]} of #{LIAC}"
            note "Close cap and shake briefly to mix"
            
            check "Prepare <b>#{SORBITOL_YPD}</b>, as follows:"
            note "Get a #{sorbitol_ypd_container}. Label it <b>#{SORBITOL_YPD}</b>"
            note "Add #{(SAFETY_FAC*operations.length*SORBITOL_FOR_YPD_VOL[:qty]).round(1)} #{SORBITOL_FOR_YPD_VOL[:units]} of #{SORBITOL}"
            note "Add #{(SAFETY_FAC*operations.length*YPD_VOL[:qty]).round(1)} #{YPD_VOL[:units]} of #{YPD}"
            note "Close cap and shake briefly to mix" 
        end
    end 
    
    def gather_materials()
        
        # how many tip needed? ~10 per transformation, or 20 per operation
        n_boxes=((TIPS_PER_OP*operations.length).to_f./TIPS_PER_BOX).ceil
        
        show do
            title "Gather the following"
            
            warning "All items (except those requiring incubator) should be gathered to the bench closest to the large centrifuge"
            
            note "The following items should be #{ON_ICE}" 
            # check "Mixed-DNA sample(s): <b>#{mixes.to_sentence}</b>"
            check "#{WATER} (at least #{(SAFETY_FAC*operations.length*WATER_VOL[:qty]).round(1)} #{WATER_VOL[:units]})" 
            check "#{SORBITOL_CACL} (you should have #{(SAFETY_FAC*operations.length*SORBITOL_CACL_VOL[:qty]).round(1)} #{SORBITOL_CACL_VOL[:units]})"
            check "#{CONICALS_PER_OP*operations.length} #{CONICAL}s"
            check "#{n_boxes} box(es) of #{TIP}s (keep in #{FREEZER} until you need them)"
            check "#{PIPETTES_PER_OP*operations.length} #{PIPETTE}s (keep in #{FREEZER} until you need them)"
            check "#{CUVETTES_PER_OP*operations.length} #{CUVETTE}s (keep in #{FREEZER} until you need them)"
            
            note "The following items should be #{WARMED}" 
            check "#{LIAC_DIL} (you should have #{(operations.length*(LIAC_DIL_VOL[:qty] + LIAC_VOL[:qty])).round(1)} #{LIAC_DIL_VOL[:units]})"
            check "#{SORBITOL_YPD} (you should have #{(SAFETY_FAC*operations.length*SORBITOL_YPD_VOL[:qty]).round(1)} #{SORBITOL_YPD_VOL[:units]})"
            check "#{FLASK_250B_WARMED_PER_BATCH} #{FLASK_250B}(s)"
 
            note "The following items should be #{ROOM_TEMP}" 
            check "#{operations.length} #{DTT_VOL[:qty]} #{DTT_VOL[:units]} aliquot(s) of #{DTT}"
            check "#{DILUTION_PLATES_PER_OP*operations.length} #{DILUTION_PLATE_MEDIA} plates"
            check "#{SELECTION_MEDIA_VOL[:qty]*operations.length} #{SELECTION_MEDIA_VOL[:units]} of #{SELECTION_MEDIA}"
            check "#{FLASK_500B_PER_OP*operations.length} #{FLASK_500B}(s)"
            check "#{FLASK_250NB_PER_OP*operations.length} #{FLASK_250NB}(s)"
        end 
    end

end