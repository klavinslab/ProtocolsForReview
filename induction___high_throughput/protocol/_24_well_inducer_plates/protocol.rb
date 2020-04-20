# prepare strains with 8 inducer conditions in 4x24-well format
#
# note: 1 input starter -> 8 output starter+condition, so 1 half-plate (12 starters) -> 4 full plates
#
# NOT A GOOD IDEA TO BATCH THIS!!!
#
# TO DO: retrieve plate within loop - need location

needs "Standard Libs/Debug"  
needs "Induction - High Throughput/HighThroughputHelper"        
    
class Protocol

    include Debug     
    include HighThroughputHelper               
    
    # i/o names
    INPUT_NAME="24 well plate"        
    OUTPUT_NAME="inducer plates"   
    
    MEDIA_VOL=210 # mL, for full plate. need 200, so have some spare
    DISPENSE_VOL=25 # mL, for each inducer condition
    TRANSFER_VOL=6 # mL, Kan -> Kan+Spec for same inducer condition
    
    # checkable version - not needed
    #INDUCER_TABLE = [ [ {content: "1: no inducer", check: true}, {content: "2: IPTG", check: true}, {content: "3: aTc", check: true}, {content: "4: aTc + IPTG", check: true}, {content: "5: Lara", check: true}, {content: "6: Lara + IPTG", check: true}, {content: "7: Lara + aTc", check: true}, {content: "8: Lara + aTc + IPTG", check: true}] ] 
    
    # standard version
    INDUCER_TABLE = [ ["1: no inducer", "2: IPTG", "3: aTc", "4: aTc + IPTG", "5: Lara", "6: Lara + IPTG", "7: Lara + aTc", "8: Lara + aTc + IPTG"] ] 
    
    # labels for inducer plates 
    # Plate A: (A-Left) no inducer         (A-Right) IPTG+
    # Plate B: (B-Left) aTc+               (B-Right) aTc+ IPTG+
    # Plate C: (C-Left) Lara+              (C-Right) Lara+ IPTG+
    # Plate D: (D-Left) Lara+ aTc+         (D-Right) Lara+ aTc+ IPTG+
    LABELS=[["1: no inducer","3: aTc+","5: Lara+","7: Lara+ aTc+"],["2: IPTG+","4: aTc+ IPTG+","6: Lara+ IPTG+","8: Lara+ aTc+ IPTG+"]] # LEFT 1-4, RIGHT 1-4
    VALS_aTc=[[0, 2, 0, 2],[0, 2, 0, 2]] # LEFT 1-4, RIGHT 1-4     [0,2]ng/mL
    VALS_Lara=[[0, 0, 5, 5],[0, 0, 5, 5]] # LEFT 1-4, RIGHT 1-4    [0,5]mM
    VALS_IPTG=[[0, 0, 0, 0],[1, 1, 1, 1]] # LEFT 1-4, RIGHT 1-4    [0,1]mM
    LEFT=0
    RIGHT=1

    # parameters for display
    NUM_PLATES=5
    NUM_FALCONS=16
    
    # columns for culture transfer display
    SOURCE_COL=[4,5,6]
    DEST_COL=[[1,2,3],[4,5,6]]
    
  def main
     
    # creates empty 24 well plate outputs
    operations.make
    
    operations.each { |op|  
    
        # visually check that plate with culture exists before starting
        show do
            title "Before you begin..."
            note "You will be preparing multiple inducer conditions for a plate of bacterial cultures."
            check "I see 24 well plate #{op.input(INPUT_NAME).item.id} in #{op.input(INPUT_NAME).item.location}"
            warning "Do NOT retrieve plate at this point! Leave plate in shaker."
        end
    
        # collect stuff 
        show do
            title "Gather the following items:"
            # freezer stuff first - needs to defrost
            check "Kanamycin (50mg/mL stock) containing at least 220 µL from B1.165"
            check "Spectinomycin (50mg/mL stock) containing at least 50 µL from B1.165"
            check "aTc (2µg/mL stock) containing at least #{4*1*DISPENSE_VOL} µL from box labeled 'DARPA' in small freezer"
            check "Lara (1M stock) containing at least #{4*1*DISPENSE_VOL} µL from box labeled 'DARPA' in small freezer"
            check "IPTG (1M stock) containing at least #{4*5*DISPENSE_VOL} µL from box labeled 'DARPA' in small freezer"
            check "1 aliquot of 1xPBS + 2mg/mL Kan from old -20C freezer (defrost on bench, this will be used in ~5 hrs)"
            # fridge stuff
            check "M9-glucose containing at least #{MEDIA_VOL} mL from fridge"
        end
        show do
            title "Gather these additional items:"
            # other stuff
            check "#{NUM_FALCONS} 50mL falcons"
            check "a rack for #{NUM_FALCONS} falcons"
            check "#{NUM_FALCONS} sterile reservoirs (for 20mL volume or higher)"
            check "#{NUM_PLATES} autoclaved 24-well plates"
            check "#{NUM_PLATES-1} aerated seals" # do not need seal for intermediate plate
            check "#{NUM_FALCONS/2} 10mL serilogical pipettes" # for Kan+Spec transfer
            check "1 25mL serilogical pipette"
            check "Preprinted sticker labels (ask a lab manager for these)" 
        end
        
        # prepare odd-row-only boxes of tips
        # 1mL: less than 1 box needed
        # 100uL: 1 box needed
        oddRowOnlyTips(1*operations.length, 1000)
        oddRowOnlyTips(1*operations.length, 100) 
        
        # label inducer plates 
        show do
            title "Prepare and label 24-well inducer plates"
            check "Cover the autoclaved 24-well plates with aerated seals"
            warning "Please label carefully! The labels contain information for the LEFT and RIGHT sides of each plate."
        end
        show do
            op.output_array(OUTPUT_NAME).items.each_with_index { |item, ii| 
                # convert index to A,B,C,D so not to confuse with condition numeric lables
                plateName="A".ord.to_i + ii # asscii value for A,B,etc., use .chr to convert to asscii character
                
                # OLD VERSION - before stickers
                #check "Label a new 24-well plate: #{item.id} + 'Plate #{plateName.chr}', on front side of plate"
                #check "Label the LEFT side of plate #{item.id}:'LEFT' + '#{LABELS[LEFT][ii]}'"
                #check "Label the RIGHT side of plate #{item.id}: 'RIGHT' + '#{LABELS[RIGHT][ii]}'"
                
                # NEW VERSION - with stickers
                check "Label a new 24-well plate: #{item.id}"
                check "Stick the preprinted label 'Plate #{plateName.chr}' on plate #{item.id}"
                # associate name to plate
                Item.find(item.id).associate :plateName, plateName.chr
            } 
        end
        show do
            note "The labeled plates should look something like this:"
            image "Actions/Induction_High_Throughput/inducer_plate_labels_cropped.jpg" 
        end
    
        # prepare inducer media - Kan
        show do 
            title "Prepare M9-glucose media with inducers and Kan"
            check "Pour #{MEDIA_VOL} mL of M9-glucose media into autoclaved flask" 
            check "Add #{MEDIA_VOL} µL of Kanamycin (50mg/mL stock)"
            check "Place #{NUM_FALCONS/2} falcons in the back row of rack"
            check "Dispense #{DISPENSE_VOL} mL M9-glucose into each of the #{NUM_FALCONS/2} 50mL falcons with a serilogical pipette" 
            check "Using the preprinted stickers, label the  #{NUM_FALCONS/2} falcons with <b>'Kan'</b> and the following  #{NUM_FALCONS/2} inducer conditions, from left to right:"
            table INDUCER_TABLE
        end
        show do 
          title "Prepare M9-glucose media with inducers and Kan"
          table INDUCER_TABLE
          warning "In the following, use a fresh tip for each volume added!"
          warning "Briefly vortex induer stocks before pipetting"
          check "Add #{1*DISPENSE_VOL} µL of <b>IPTG</b> (1M stock) to the falcons with label containing  <b>IPTG</b> (4 falcons total, at <b>positions 2,4,6,8</b>)" 
          check "Add #{1*DISPENSE_VOL} µL of <b>aTc</b> (2µg/mL stock) to the falcons with label conatining  <b>aTc</b> (4 falcons total, at <b>positions 3,4,7,8</b>)" 
          check "Add #{5*DISPENSE_VOL} µL of <b>L-ara</b> (1M stock) to the falcons with label containing  <b>Lara</b> (4 falcons total, at <b>positions 5,6,7,8</b>)"
          check "Briefly vortex all <b>'Kan'</b> falcons"
        end
        
        # prepare inducer media - Kan+Spec 
        show do 
          title "Prepare M9-glucose media with inducers and Kan+Spec"
          check "Place the  #{NUM_FALCONS/2} empty falcons in the front row of the rack"
          check "Using the preprinted stickers, label these falcons <b>'Kan+Spec'</b> and the following  #{NUM_FALCONS/2} inducer conditions, from left to right:"
          table INDUCER_TABLE
          #image "Actions/Induction_High_Throughput/falcon_contents_cropped.jpg"
          check "Add #{TRANSFER_VOL}µL of Spectinomycin (50mg/mL stock) to each of the empty <b>'Kan+Spec'</b> falcons in the front row"
          check "Make sure that the inducer label of each falcon in the back row matches the inducer label of the falcon directly in front of it"
          warning "In the following, use a fresh serilogical pipette for each volume transfered!"
          check "Transfer #{TRANSFER_VOL}mL with serilogical pipette from each <b>'Kan'</b> falcon in the back row to the <b>'Kan+Spec'</b> falcon with the same inducer label in the front row"
          check "Briefly vortex all <b>'Kan+Spec'</b> falcons"
        end
        
        # prepare plates - verything EXCEPT cells
        op.output_array(OUTPUT_NAME).items.each_with_index { |item, ii| 
        
            # LEFT half of plate
            show do 
              title "Prepare 24-well inducer plates"
              warning "You will now be working with the LEFT side of plate #{item.id}"
              check "Locate the 'Kan' falcon with inducer label '#{LABELS[LEFT][ii]}'"
              check "Pour contents of falcon labeled 'Kan' + '#{LABELS[LEFT][ii]}' into a 25mL sterile reservoir"
              check "Dispense 740 µL into columns <b>1-2</b> of plate #{item.id} using 4 1mL odd-row tips (8 wells total, see below)"
              image  "Actions/Induction_High_Throughput/cols1-2_shaded_cropped.jpg"
              check "Trash the tips and the reservoir"
            end
            show do
              title "Prepare 24-well inducer plates"
              warning "Continue with inducer plate #{item.id} labeled 'Plate #{ii+1}', LEFT side"
              check "Locate the 'Kan+Spec' with inducer label '#{LABELS[LEFT][ii]}'"
              check "Pour contents of falcon labeled 'Kan+Spec' + '#{LABELS[LEFT][ii]}' into a 25mL sterile reservoir"
              check "Dispense 740 µL into column <b>3</b> of the plate using 4 1mL odd-row tips (4 wells total, see below)"
              image  "Actions/Induction_High_Throughput/col3_shaded_cropped.jpg"
              check "Trash the tips and the reservoir"
            end

            # RIGHT half of plate
            show do
              title "Prepare 24-well inducer plates"    
              warning "You will now be working with the RIGHT side of plate #{item.id}"
              check "Locate the 'Kan' falcon with inducer label '#{LABELS[RIGHT][ii]}'"
              check "Pour contents of falcon labeled 'Kan' + '#{LABELS[RIGHT][ii]}' into a 25mL sterile reservoir"    
              check "Dispense 740 µL into columns <b>4-5</b> of the plate using 4 1mL odd-row tips (8 wells total, see below)" 
              image  "Actions/Induction_High_Throughput/cols4-5_shaded_cropped.jpg"
              check "Trash the tips and the reservoir"
            end
            show do
              title "Prepare 24-well inducer plates"
              warning "Continue with inducer plate #{item.id}, RIGHT side"     
              check "Locate the 'Kan+Spec' falcon with inducer label '#{LABELS[RIGHT][ii]}'"
              check "Pour contents of falcon labeled 'Kan+Spec' + '#{LABELS[RIGHT][ii]}' into a 25mL sterile reservoir"
              check "Dispense 740 µL into column <b>6</b> of the plate using 4 1mL odd-row tips (4 wells total, see below)" 
              image  "Actions/Induction_High_Throughput/col6_shaded_cropped.jpg"  
              check "Trash the tips and the reservoir"
            end       
        }
        
        # FINALLY ready to get plate from shaker!
        show do
            title "Gather 24 well culture plate"
            check "Get 24 well culture plate #{op.input(INPUT_NAME).item.id} from #{op.input(INPUT_NAME).item.location}"
        end
        
        # intermediate dilution of cells before transfer
        show do
            title "Intermediate dilution of culture"
            check "Grab a new autoclaved 24-well plate"
            check "Label plate on front side: <b>'Intermediate Plate'</b>+ (your initials)"
            note "This plate does not need an aerated seal"
            check "Pour 15mL M9-glucose into a 25mL sterile reservoir"
            check "Load 4 1mL odd-row-only tips on 8-channel pippete"
            check "Dispense 740 µL M9-glucose to all wells in columns <b>4-6</b> of <b>'Intermediate Plate'</b>"
            check "Trash the tips and the reservoir"
        end
        show do
            title "Dilute culture"
            check "Grab a box of 100 µL odd-row-only tips"
            SOURCE_COL.length.times do |ii|
                check "Load 4 100 µL odd-row-only tips on 8-channel pipette"
                check "Transfer 60 µL from plate #{op.input(INPUT_NAME).item.id}, column <b>#{SOURCE_COL[ii]}</b> to <b>'Intermediate Plate'</b>, column <b>#{SOURCE_COL[ii]}</b>"
                check "Trash the tips"
            end
        end
        
        # add cells from 'dilution' plate to 'inducer' plates
        show do 
            title "Add diluted cell culture to inducer plates"
            warning "In the following, you will transfer cells between plates, 1 column at a time. Use 4 new tips for every column!"
            check "Locate the boxes of 100 µL odd-row-only tips"
            check "Orient <b>'Intermediate Plate'</b> with A1 at top left"
        end
        op.output_array(OUTPUT_NAME).items.each_with_index { |it, ii|  
            show do
                check "Orient plate #{it.id} correctly"
                warning "In the following, you will transfer cells between plates, 1 column at a time. Use 4 new tips for every column!"
                warning "To keep track of columns: the remaining tips in the box correspond to columns that did NOT YET receive culture"
                SOURCE_COL.length.times do |ii|
                    check "Transfer 12 µL from column <b>#{SOURCE_COL[ii]}</b> in <b>'Intermediate Plate'</b> to column <b>#{DEST_COL[LEFT][ii]}</b> of plate #{it.id}"
                end
            end
            show do
                SOURCE_COL.length.times do |ii|
                    check "Transfer 12 µL from column <b>#{SOURCE_COL[ii]}</b> in <b>'Intermediate Plate'</b> to column <b>#{DEST_COL[RIGHT][ii]}</b> of plate #{it.id}"
                end
                check "Seal 'Inducer' plate #{it.id}" 
            end
        } # op.output_array 
            
        # initialize the inducer plates: item ids, hash of associated info for all wells  
        op.output_array(OUTPUT_NAME).collections.each_with_index { |outcol, ii| 
            #initializeInducerPlate(incol, outcol, left_Lara, left_aTc, left_IPTG , right_Lara, right_aTc, right_IPTG)
            initializeInducerPlate(op.input(INPUT_NAME).collection, outcol, VALS_Lara[LEFT][ii], VALS_aTc[LEFT][ii], VALS_IPTG[LEFT][ii],  VALS_Lara[RIGHT][ii], VALS_aTc[RIGHT][ii], VALS_IPTG[RIGHT][ii])
        }
        
        # set location of input, output plates
        op.output_array(OUTPUT_NAME).items.each { |plate| 
            # set location     
            plate.move('Bench')
            plate.save    
        }
        op.input(INPUT_NAME).item.mark_as_deleted # morning dilution plate
        
    } # operations.each  
    
    # plates will be left on bench
    operations.store
    show do
        title "Cleanup"
        check "Please move 'Intermediate Plate(s)' to the washing station"
    end
    
    return {}
    
  end # def main
 
end # Protocol