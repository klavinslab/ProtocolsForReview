# SG
# Combine fragments
# Useful for conserving material when running multiple identical reactions
needs "Library Cloning/PurificationHelper"

class Protocol
    
    include PurificationHelper # for measureConcentration
 
    # I/O
    INPUT="Fragment (array)"  
    OUTPUT="Combined Fragment"

    def main
      
        # make output item
        operations.make.retrieve
        
        # combine 
        operations.each { |op|
            # estimate total volume
            data = show do
                title "Estimate total volume of inputs"
                note "You will be combining the following samples:"
                op.input_array(INPUT).items.each { |it|
                        note "#{it}"    
                }
                select [ "Yes", "No"], var: "choice", label: "Is the combined volume of the samples <b>more</b> than 1.5 mL?", default: 1
            end
            
            # volume too high
            if(data[:choice]=="Yes")
                show do
                    title "Problem combining samples: volume too high! Exiting."
                end
                return
            end
            
            # combine
            show do
                title "Combine inputs"
                check "Label a 1.5mL eppi #{op.output(OUTPUT).item}"
                note "Combine the <b>ENTIRE</b> contents of the following input items into the tube labeled #{op.output(OUTPUT).item}:"
                    op.input_array(INPUT).items.each { |it|
                        note "#{it}"    
                    }
            end
        }
        
        # measure concentration of combined sample
        measureConcentration(OUTPUT,"output")
        
        # delete original samples
        operations.each { |op|
            op.input_array(INPUT).items.each { |it|
                it.mark_as_deleted
            }
        }
        operations.store
        
        return {}
    
    end
  
end

