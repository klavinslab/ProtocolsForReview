# SG
# note: the 50mL in a single "Innoc. Library Preculture" is enough for 5 "Dilute Library Preculture" ops. 
class Protocol

    # I/O
    INPUT="Yeast Plate"
    OUTPUT="Yeast Culture"
    N_TRANS="number of transformations (up to 6)"
    
    # other - innoculation
    SAFETY_FAC=1.2
    TRANS_PER_OP=6
    INNOC_VOL=50 # mL
    INNOC_MEDIA="YPAD"
    SHAKER_30C="30C Shaker"
    RPM=250
    FLASK="250 mL <b>baffled</b> flask"
    FRIDGE="DFP"
    
    # other - prep for tomorrow 
    # media
    WATER ='sterile water'
    YPAD="YPAD (peptone)"
    SORBITOL='Sorbitol 1M'
    CACL='CaCl2 1M'
    DTT="DTT 1M"
    LIAC="Lithium acetate (LiAc) 1M"
    SDO_MEDIA='C-His-Trp-Ura liquid media'
    SDO_PLATE_MEDIA = "C-His-Trp-Ura agar plate"
    # container
    FLASK_250_NB="sterile 250 mL <b>non-baffled</b> flask"
    FLASK_250_B="sterile 250 mL <b>baffled</b> flask"
    FLASK_500_B="sterile 500 mL <b>baffled</b> flask"
    CUVETTE="2mm gap electroporation cuvette"
    # locations
    DTT_LOCATION="in M20, in cardboard box labeled 'DTT aliquots'"
    SORBITOL_LOCATION="R1"
    CUVETTE_LOCATION="SF2"
    
    # quantities for 1 transformation operation == 2 transformations 
    # media (some spare taken)
    WATER_VOL = { qty: 330, units: 'ml'}
    LIAC_VOL = { qty: 3, units: 'ml'}
    SORBITOL_VOL = { qty: 130, units: 'ml'} 
    CACL_VOL ={ qty: 120, units: 'µl'}
    YPAD_VOL={ qty: 150, units: 'ml'}
    LIAC_DIL_VOL = { qty: 20, units: 'mL' }
    DTT_VOL = { qty: 1, units: 'aliquot (210 µL)'}
    SDO_MEDIA_VOL = { qty: 250, units: 'mL'}
    # other
    SDO_PLATE_PER_OP={ qty: 6, units: 'plates'} 
    FLASK_250_NB_PER_OP={ qty: 2, units: 'flasks'}
    FLASK_250_B_PER_OP={ qty: 2, units: 'flasks'}
    FLASK_500_B_PER_OP={ qty: 2, units: 'flasks'}
    CUVETTE_PER_OP={ qty: 2, units: 'cuvettes'}
     
    def main
         
        show do
            title "Before you start..."
            note "This protocol should be run before 9AM (so that cells will reach the proper OD by tomorrow morning). Notify a lab manager if you start any later."
        end
         
        num_trans=0
        operations.each { |op| 
            if(op.input(N_TRANS).val > TRANS_PER_OP) 
                show do
                    title "Problem!"
                    note "There is not enough material in an overnight for #{op.input(N_TRANS).val} transformations. Maximum is #{TRANS_PER_OP}. Please check operation #{op.id} in plan #{op.plan.id}!"
                end
            end
            num_trans=num_trans + op.input(N_TRANS).val
        }
        if(debug)
            num_trans=6
        end
        
        operations.retrieve.make
        
        show do
            title "You will also need"
            check "#{(operations.length*INNOC_VOL).round(1)} mL #{INNOC_MEDIA}"
        end
        
        show do
            title "Prepare flasks for innoculation"
            note "Grab #{operations.length} #{FLASK}(s)"
            check "Label the flask(s): <b>#{operations.map { |op| op.output(OUTPUT).item.id}.to_sentence}</b>"
            check "Pour #{INNOC_VOL} mL of #{INNOC_MEDIA} into each labeled flask"
        end
        
        show do
            title "Innoculate for overnight shaking"
            note "Innoculate by picking a single colony from the each plate with a tip and dipping into the corresponding flask, according to the table:"
            table operations.start_table
                .input_item(INPUT)
                .output_item(OUTPUT)
                .end_table
        end
        
        show do
            title "Label plates for future disposal"
            check "Label plate(s) #{operations.map{|op| op.input(INPUT).item}.to_sentence} clearly (with tape): <b>DISPOSE AFTER #{Date.today+2}<b>"
            
        end
        operations.each { |op|
            #op.input(INPUT).item.mark_as_deleted
            op.input(INPUT).item.move_to(FRIDGE)
            op.output(OUTPUT).item.move_to(SHAKER_30C)
        }
        operations.store
        
        num_ops = (num_trans.to_f/2).ceil
        header = ["material", "quantity"]
        tab = [["", WATER, YPAD, SORBITOL, CACL, LIAC, DTT, SDO_MEDIA, SDO_PLATE_MEDIA, FLASK_250_NB, FLASK_250_B, FLASK_500_B, CUVETTE],  
               ["", convert(WATER_VOL,num_ops), convert(YPAD_VOL,num_ops), convert(SORBITOL_VOL,num_ops), convert(CACL_VOL,num_ops), convert(LIAC_VOL,num_ops), convert(DTT_VOL,num_ops), convert(SDO_MEDIA_VOL,num_ops), convert(SDO_PLATE_PER_OP,num_ops), convert(FLASK_250_NB_PER_OP,num_ops), convert(FLASK_250_B_PER_OP,num_ops), convert(FLASK_500_B_PER_OP,num_ops), convert(CUVETTE_PER_OP,num_ops)] ]
        tab=tab.transpose
        tab[0]=header
        
        show do
            title "Prepare materials for tomorrow"
            warning "It is important to check for these materials the day <b>before</b> the High Efficiency Transformation!"
            table tab
            note "Notes:"
            note "<b>(1)</b> DTT aliquots (210 µL) are stored in #{DTT_LOCATION}"
            note "<b>(2)</b> Sorbitol 1M is stored in #{SORBITOL_LOCATION}"
            note "<b>(3)</b> Electroporation cuvettes are stored in #{CUVETTE_LOCATION}"
            warning "Notify a lab manager if any materials are missing or running low!"
        end 
        
    end # main
    
    def convert(obj,num_ops)
       return "#{obj[:qty]*num_ops} #{obj[:units]}"  
    end    

end