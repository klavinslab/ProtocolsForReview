# Dilute cell culture to desired volume
# Used for morning DOUBLE dilution of overnight cultures 
#
# ok to batch, dilution can be different for each plate
#
# TO DO: 
# 1) calculate tip size for media, overnight culture instead of assuming 1000, 100 uL
# 2) get antibiotic resistances of wells instead of assuming them
needs "Standard Libs/Debug"  
needs "Induction - High Throughput/HighThroughputHelper"

class Protocol
     
  include Debug    
  include HighThroughputHelper    
  
   # i/o names
   INPUT_NAME="24 well plate"
   OUTPUT_NAME="diluted 24 well plate"
   CULTURE_VOL="culture volume (µL)" # per well
   MEDIA_VOL="media volume (µL)"  # per well
   SAFETY_FACTOR=1.1

  def main 

    # get 24-well plates
    operations.retrieve.make 
    
    # caluclate total volumes of media needed for all 12 wells x 2 dilution steps
    tot_media_vol=0 # µL
    tot_kan=0   # µL
    tot_spec=0  # µL
    operations.each { |op|
        tot_media_vol=tot_media_vol + SAFETY_FACTOR*24*op.input(MEDIA_VOL).val # 24 wells
        tot_kan=tot_kan + SAFETY_FACTOR*12*op.input(MEDIA_VOL).val.to_f/1000 # only 2nd dilution has antibiotics added (12 wells)
        tot_spec=tot_spec + SAFETY_FACTOR*4*op.input(MEDIA_VOL).val.to_f/1000 # only 1 strain has Spec (4 wells)
    }
    tot_media_mL= (tot_media_vol.to_f/1000).ceil # mL
    if(tot_media_mL<10)
        tot_media_mL=10
    end

     # collect/prepare consumable stuff 
    show do
        title "Gather the following items:"
        check "#{ tot_media_mL } mL of M9-glucose from R3, bottom right shelf (bottle wrapped in foil)"
        check "#{3*operations.length} sterile 25mL reservoirs"
        check "#{operations.length} autoclaved 24-well plate(s)"
        check "#{operations.length} aerated seal(s) for well plate(s)"
        check "#{2*operations.length} autoclaved flasks (large enough for #{ (tot_media_mL.to_f/2).ceil } mL)"
        check "Kanamycin (50mg/mL stock) containing at least #{ (tot_kan.to_f).ceil } µL from B1.165"  
        check "Spectinomycin (50mg/mL stock) containing at least #{ (tot_spec.to_f).ceil } µL from B1.165" 
    end
    
    # prepare odd-row-only tips: 1000µL for fresh media, 100µL for overnight culture
    # 12 tips for 3 strains x 4 duplicates, 1/8 of 96-tip box
    # 12 tips spare of each
    oddRowOnlyTips( ((operations.length+1).to_f/8).ceil, 1000) 
    oddRowOnlyTips( ((operations.length+1).to_f/8).ceil, 100) 
    
    # media prep
    show do
        title "Prepare media+antibiotics"
        check "Label the 2 flasks 'M9+Kan' and 'M9+Kan+Spec'"
        check "Transfer #{ (tot_media_mL.to_f/2).ceil }mL M9-glucose + #{(tot_media_mL.to_f/2).ceil}µL Kan (50mg/mL stock) into the flask labeled 'M9+Kan'"
        check "Mix flask 'M9+Kan' (swirl gently)"
        check "Using stripette, transfer #{(tot_media_mL.to_f/6).ceil}mL M9-glucose + Kan into the flask labeled 'M9+Kan+Spec'"
        check "Add #{(tot_media_mL.to_f/6).ceil}µL Spec (50mg/mL stock) to the flask labeled 'M9+Kan+Spec'"
        check "Mix flask 'M9+Kan+Spec' (swirl gently)"
    end

    # label all 'Dilution' plates so already labeled when pippeting. NEED LABEL: may have different dilution volumes
    show do
        title "Label 'Dilution' plate(s)"
        operations.each { |op|
            check "Seal empty autoclaved 24-well plate with an aerated seal"
            check "Label seal: 'Dilution' + #{op.output(OUTPUT_NAME).item.id} + your initials + #{Time.zone.now.to_date}"  
        }
    end 
    
    # add fresh media with no antibiotics to cols 1-3 of all plates 
    show do
        title "Add fresh media WITHOUT antibiotics to 'Dilution' plate(s)"
        check "Pour M9-glucose media into a sterile 25mL reservoir"
        check "Load 4 1mL tips from odd-row-only tip box on 8-channel pipette"
        operations.each { |op|
            check "Dispense #{op.input(MEDIA_VOL).val} µL of M9-glucose into <b>columns 1,2,3</b> of 'Dilution' plate #{op.output(OUTPUT_NAME).item.id}"
            #note "Add M9-glucose to reservoir, as needed"
            image "Actions/Induction_High_Throughput/cols1-3_shaded_cropped.jpg" 
        } 
        check "Trash tips and reservoir"
    end
    
    # add fresh media with Kan to cols 4-5 of all plates 
    show do
        title "Add fresh media with Kan to 'Dilution' plate(s)"
        check "Pour media from 'M9+Kan' flask into a sterile 25mL reservoir"
        check "Load 4 1mL tips from odd-row-only tip box on 8-channel pipette"
        operations.each { |op|
            check "Dispense #{op.input(MEDIA_VOL).val} µL of M9+Kan into <b>columns 4,5</b> of 'Dilution' plate #{op.output(OUTPUT_NAME).item.id}"
            #note "Add M9+Kan to reservoir, as needed (see below)"
            image "Actions/Induction_High_Throughput/cols4-5_shaded_cropped.jpg"
        }
        check "Trash tips and reservoir"
    end

    # add fresh media with Kan+Spec to col 6 of all plates 
    show do
        title "Add fresh media with Kan+Spec to 'Dilution' plate(s)"
        check "Pour media from 'M9+Kan+Spec' flask into a sterile 25mL reservoir"
        check "Load 4 1mL tips from odd-row-only tip box on 8-channel pipette"
        operations.each { |op|
            check "Dispense #{op.input(MEDIA_VOL).val} µL of M9+Kan+Spec into <b>column 6</b> of 'Dilution' plate #{op.output(OUTPUT_NAME).item.id} (see below)"
            image "Actions/Induction_High_Throughput/col6_shaded_cropped.jpg"
            #note "Add M9+Kan+Spec to reservoir, as needed" 
        }
        check "Trash tips and reservoir"
    end
   
    # add overnight culture to dilute plates
    # breaking show into prts foro display purposes only
 
    operations.each { |op|
        show do
            title "Add overnight culture to 'Dilution' plate(s)"
            # left side of dilution plate (no antibiotics)
            check "Locate 'Overnight' plate #{op.input(INPUT_NAME).item.id}" 
            check "Locate 'Dilution' plate #{op.output(OUTPUT_NAME).item.id}" 
            warning  "Make sure 'Overnight' and 'Dilution' plates are both oriented with A1 at top left"
        end
        [1,2,3].each_with_index do |cc|  
            show do
                title "Add overnight culture to 'Dilution' plate(s) (cont.)"
                warning "In the following, use fresh tips for each column"
                check "Load 4 100 µL tips from odd-row-only tip box on 8-channel pipette"
                check "Transfer #{op.input(CULTURE_VOL).val} µL from all wells in <b>column #{cc}</b> of 'Overnight' plate #{op.input(INPUT_NAME).item.id} to <b>column #{cc}</b> of 'Dilution' plate #{op.output(OUTPUT_NAME).item.id} (see below)"
                    image "Actions/Induction_High_Throughput/col#{cc}_shaded_cropped.jpg" 
                check "Trash tips"
            end
        end
        show do
            title "Add overnight culture to 'Dilution' plate(s) (cont.)"
            #note "You should now have cells in the LEFT half of plate #{op.output(OUTPUT_NAME).item.id}"
            check "Seal 'Overnight' plate #{op.input(INPUT_NAME).item.id} and place it aside"
        end
  
        # right side of dilution plate (with antibiotics)
        [1,2,3].each_with_index do |cc|
            show do
                title "Add overnight culture to 'Dilution' plate(s) (cont.)"
                check "Load 4 100 µL tips from odd-row-only tip box on 8-channel pipette"
                check "Transfer #{op.input(CULTURE_VOL).val} µL from <b>column #{cc}</b> of 'Dilution' plate #{op.output(OUTPUT_NAME).item.id} to <b>column #{cc+3}</b> of the same plate (see below)"
                image "Actions/Induction_High_Throughput/dilution_left_to_right_cropped.jpg"
                check "Trash tips (take fresh tips for each column)"
            end
        end
        show do
            title "Add overnight culture to 'Dilution' plate(s) (cont.)" 
            check "Label 'LEFT' and 'RIGHT' sides of 'Dilution' plate #{op.output(OUTPUT_NAME).item.id}, on aerated seal"
        end
    } # operations.each

    
    # background stuff: sample matrix and associated hash for all dilution plates, locations of all plates  
    operations.each { |op|
        # initilize dilution plate id, hash, item_info_names
        initializeDilutionPlate(op.input(INPUT_NAME).collection, op.output(OUTPUT_NAME).collection)
        
        # update locations for all overnight and dilution plates
        op.input(INPUT_NAME).item.move('Bench') 
        op.input(INPUT_NAME).item.save
        op.output(OUTPUT_NAME).item.move('Bench')
        op.output(OUTPUT_NAME).item.save
    } 
    
    # stuff will be left on bench
    operations.store 
    
    return {}
    
  end

end
