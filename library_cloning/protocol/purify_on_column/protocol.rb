# SG
# Purify liquid reaction on column 
# This protocol purifies liquid reactions into DNA fragment stocks
needs "Library Cloning/PurificationHelper"
needs "Standard Libs/PrinterHelper"

class Protocol
    
    include PurificationHelper
    include PrinterHelper
    
    # I/O
    FRAGMENT="Fragment"  
    LIQUID="Liquid sample"
    KIT="Promega" # "Promega" # "Qiagen" or "Promega". must match a key in KIT_SETTINGS hash in Library Cloning/PurificationHelper.
  
    # other
    DNA_LIB="DNA Library"
  
    def main

        if debug
           operations.shuffle! 
        end
      
        # sort by increasing item id. takes care of stripwell+column too.
        sortOperations(LIQUID, "input")
        
        operations.make
        
        heatElutionBuffer(LIQUID,KIT)
        
        volumeSetup(LIQUID,KIT) 
        
        addLoadingBuffer(LIQUID, KIT)
        
        loadSample(LIQUID,KIT)
        
        washSample(KIT)
        
        printLabels(FRAGMENT)
        
        eluteSample(FRAGMENT, KIT, 0) # ==1 for two rounds of elution
        
        measureConcentration(FRAGMENT,"output") 
        
        saveOrDiscard(FRAGMENT)
        
        operations.each { |op|
            if(op.input(LIQUID).sample_type.name==DNA_LIB)
                op.output(OUT).item.associate :template, op.input(LIQUID).item.get(:template)
                op.output(OUT).item.associate :primer_F, op.input(LIQUID).item.get(:primer_F)
                op.output(OUT).item.associate :primer_R, op.input(LIQUID).item.get(:primer_R)
                op.output(OUT).item.associate :variants, op.input(LIQUID).item.get(:variants)
            end
        }
        
        operations.each do |op|
          op.input(LIQUID).item.mark_as_deleted
        end
        operations.store
        
        return {} 
    
    end
  
end

