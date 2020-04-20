# inoculate in 24-well format. 
#
# written for:
# 3 strains (pos. control, neg. control, test strain) 
# 4 colonies per strain (4 biological replicates)
#
# NOTE: code is ok for batching, but batching does not make sense: 
# you would not want so many colonies from the positive and negative controls
# batching does NOT ensure that same experiment is in same shaker
#
# TO DO:
# get antibiotic resistances from plates themselves, make generic (any 3 strains)  
# # STORE PLATES using wizard
needs "Standard Libs/Debug" 
needs "Induction - High Throughput/HighThroughputHelper" 

class Protocol
    
  include Debug    
  include HighThroughputHelper     
  
  # i/o item names 
  POS_NAME='Positive control'
  NEG_NAME='Negative control'
  TEST_NAME='Test strain'
  OUT_NAME='Overnight plate'
  
  DUPS_PER_STRAIN=4 # biological replicates
   
  def main

    # get all plates at oncewarn
    operations.retrieve.make

    # get stuff
    show do
        title "Gather the following:"
        check "#{operations.length} autoclaved 24-well plate(s)"
        check "#{operations.length} aerated seal(s)"
        check "#{operations.length} 5mL serilogical pipette(s)"
        check "#{operations.length} 25mL serilogical pipette(s)"
        check "#{2*operations.length} autoclaved flasks that can hold #{20*operations.length} mL"   
        check "#{2*operations.length} 25mL sterile reservoirs"   
        check "#{15*operations.length} mL M9-glucose media"
        check "Kanamycin aliquot (50mg/mL stock) containing at least #{operations.length*20} µL" 
        check "Spectinomycin aliquot (50mL/mL stock) containing at least #{operations.length*5} µL"
        check "8-channel pipette"
    end
    
    # prepare media
    show do 
      title "Prepare M9-glucose media with antibiotics"
      check "Label one flask: M9-glucose + Kan"
      check "Label the other flask: M9-glucose + Kan + Spec"
      check "Transfer #{20*operations.length} mL of M9-glucose media into the 'M9-glucose + Kan' flask"
      check "Add #{20*operations.length} µL of Kanamycin (50 mg/mL stock) to the flask labeled 'M9-glucose + Kan'"
      check "Mix the contents of the 'Kan' flask (swirl gently)"
      check "Transfer #{5*operations.length} mL of M9-glucose+Kan from the 'M9-glucose + Kan' into the 'M9-glucose + Kan + Spec' flask" 
      check "Add #{5*operations.length} µL of Spectinomycin (50 mg/mL stock) to the 'M9-glucose + Kan + Spec' flask"
      check "Mix the contents of the 'Kan+Spec' flask (swirl gently)"
    end
    
    # prepare odd-row-only tips
    # 1000L volume
    # 12 tips for 3 strains x 4 duplicates, 1/8 of 96-tip box 
    oddRowOnlyTips( ((operations.length+1)*(12.to_f/96)).ceil , 1000 )     
    
    # dispense media
    show do 
      title "Dispense media" 
      check "Take an empty 24-well plate"
      check "Pour 20 mL of 'M9-glucose + Kan' into a sterile 25 mL reservoir"
      check "Load 4 tips on 8-channel pippette from odd-row-only 1 mL tip box, at odd positions"
      check "Transfer 800 Ls of M9-glucose + Kan into each well of columns <b>1,2</b> of the 24-well plate (see positions below)"
      image "Actions/Induction_High_Throughput/cols1-2_shaded_cropped.jpg"
      note "Replenish 'M9-glucose + Kan' in the reservoir as needed"
      check "Trash tips and reservoir"
    end # breaking show here to break long display
    show do
      title "Dispense media (cont.)"
      check "Pour contents of 'M9-glucose + Kan + Spec' into a new 25 mL sterile reservoir"
      check "Transfer 800 Ls of M9-glucose + Kan + Spec into each well of column <b>3</b> of the 24-well plate (see positions below)"
      image "Actions/Induction_High_Throughput/col3_shaded_cropped.jpg"
      check "Trash tips and reservoir"
      check "Seal the 24-well plate with an aerated seal" # no need to label, all plates are still identical 
    end
 
    # inoculate each 24-well plate
    operations.each_with_index { |op, ii|
    
        # add cells
        show do 
          title "Inoculate 24-well plate"
          check "Take an unlabeled media-containing 24-well plate (#{ii+1} of #{operations.length} plate(s))"
          check "Unwrap plate #{op.input(POS_NAME).item.id}. Select 4 colonies from this plate, inoculate into wells A1,B1,C1,D1 of the 24-well plate, using 1mL tips (see positions below)"
          warning "Use a fresh tip for each colony"
          image "Actions/Induction_High_Throughput/col1_shaded_cropped.jpg"
        end # breaking show here to break long display
        show do
          title "Inoculate 24-well plate (cont.)"
          check "Unwrap plate #{op.input(NEG_NAME).item.id}. Select 4 colonies from this plate, inoculate into wells A2,B2,C2,D2 of the 24-well plate, using 1mL tips (see positions below)"
          warning "Use a fresh tip for each colony"
          image "Actions/Induction_High_Throughput/col2_shaded_cropped.jpg"
        end # breaking show here to break long display
        show do
          title "Inoculate 24-well plate (cont.)"    
          check "Unwrap plate #{op.input(TEST_NAME).item.id}. Select 4 colonies from this plate, inoculate into wells A3,B3,C3,D3 of the 24-well plate, using 1mL tips (see positions below)"
          warning "Use a fresh tip for each colony"
          image "Actions/Induction_High_Throughput/col3_shaded_cropped.jpg"
        end # breaking show here to break long display
        show do
          title "Inoculate 24-well plate (cont.)"
          check "Seal 24-well plate with aerated seal"
          check "Label seal: #{op.output(OUT_NAME).item.id} + 'Overnight' + your initials + #{Time.zone.now.to_date}" 
        end # end of long show
        
        # set location of plates to 4C
        op.input(POS_NAME).item.move("DFP")
        #op.input(POS_NAME).item.store
        #op.input(POS_NAME).item.save
        op.input(NEG_NAME).item.move("DFP")
        #op.input(NEG_NAME).item.save
        op.input(TEST_NAME).item.move("DFP")
        #op.input(TEST_NAME).item.save
        
        # set location of overnight plate
        op.output(OUT_NAME).item.move("Bench")
        #op.output(OUT_NAME).item.save
         
        # initialize plate ids, associated hash with strain, replicate number info
        initializeMultiwell(op.output(OUT_NAME).collection, DUPS_PER_STRAIN, op.input(POS_NAME).sample.name, op.input(NEG_NAME).sample.name, op.input(TEST_NAME).sample.name)
    }
    
    # return plates to 4C, leave 24-well on bench
    operations.store
    
    return {}
    
  end

end
