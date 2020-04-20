# Purify High-Volume Gel 
# 
# This protocol purfies gel slices into DNA fragment stocks.
# edited by SG for low melting temperature gel, promega wizard kit. not sure if this is compatible with qiagen kit/protocol.
# high volume extraction: expect 5 microgram in each gel slice, ~2 slices per 1.5mL tube, so 10,000ng/35µL ~ 285 ng/µL without losses
# max capacity of wizard columns is 40 µg, see promega technical bulletin TB308
# second elution should also give reasonable yield (~50ng/µL)
# 
# TO DO:
# 1) in y/n discard loop - CHANGE TO LOOP OVER FRAGMENTS ONLY!!! 
needs "Library Cloning/PurificationHelper"
needs "Standard Libs/PrinterHelper"
class Protocol 
    
    include PurificationHelper
    include PrinterHelper
  
    # I/O
    SLICES="Gel slices" # multiple slices
    FRAGMENT1="Fragment first round"
    FRAGMENT2="Fragment second round"
    
    # other
    DEFAULT_NUMBER_TUBES=4
    
    KIT="Promega" # "Qiagen" or "Promega". must match a key in KIT_SETTINGS hash in Library Cloning/PurificationHelper.
      
    def main
        
        # get gel slices 
        operations.retrieve
        
        # make outputs
        operations.make
        
        # While testing, assign random weight, number_of_tubes 
        operations.each{ |op| op.set_input_data(SLICES, :weight, (Random.rand / 2 + 0.1).to_s )  } if debug
        operations.each{ |op| op.set_input_data(SLICES, :number_of_tubes, (4 + (2.0*Random.rand).ceil).to_s )  } if debug
        
        # number_of_tubes should be defined! if not set to DEFAULT_NUM_TUBES
        operations.each { |op|
            if(op.input(SLICES).item.get(:number_of_tubes).nil?)
                op.input(SLICES).item.associate "number_of_tubes", DEFAULT_NUMBER_TUBES.to_s
            end
        }
           
        heatElutionBuffer(SLICES,KIT)
        
        # based on input type will display correct table    
        volumeSetup(SLICES,KIT) 

        # based on input type will display correct table     
        addLoadingBuffer(SLICES, KIT) 
        
        meltGel(SLICES,KIT) 
        
        loadMultiGelSample(SLICES,KIT)
        
        washSample(KIT)
        
        printLabels([FRAGMENT1,FRAGMENT2])  
        
        eluteMultipleGelSample(SLICES, FRAGMENT1, FRAGMENT2, KIT) 
            
        measureConcentration(FRAGMENT1,"output")
        measureConcentration(FRAGMENT2,"output")
        saveOrDiscard(FRAGMENT1)
        saveOrDiscard(FRAGMENT2)
    
        # trash input tubes
        operations.each { |op|    
            op.input(SLICES).item.mark_as_deleted
            op.input(SLICES).item.save # needed?
        } # operations.each
        
        # store fragments
        operations.store
        
        return {}
        
    end # main
  
end # protocol

