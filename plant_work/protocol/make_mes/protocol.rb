#Xavaar
#11/15/2019

class Protocol

    BOTTLES = "Number of Bottles (400 mL)"
    
    OUTPUT = "MES Solution"
    
  def main
      
        operations.make
        
        gather_materials
        
        weighAndMeasure
        
        pHProbe    
        
        finishUp
        
        operations.store
        
        {}

  end
  
    def gather_materials
        
        $totalBottles = 0 #This is so if multiple jobs are submittted all the reagent can be made at once

        
        operations.each do |op|
            $totalBottles +=1
        end
        
        show do
            title "Gather materials"
            note "Gather the following items:"
            if $totalBottles == 1
                check "A 600 mL beaker"
            else
                check "The large 2000 mL beaker"
            end
            check "#{$totalBottles} 400 mL bottles"
            check "MES (Orlando Shelf)" # 1.56g
            check "Mannitol (Orlando Shelf)" # 29.12g
            check "Potassium Chloride (Across from the fumehood)"#0.596 g
        end
        
        return $totalBottles
    end
   
    def weighAndMeasure
       
      partialFill = $totalBottles * 400 * 0.75
       
      show do
          title "Prep Beaker"
          note "Fill the beaker with water to approximatley #{partialFill}, this is aproximately 3/4 the final volume."
          check "Add Stirbar"
          note "Place it on the mixy machine and turn it on"
           
      end
       
      show do
          title "Measure Reagents"
          warning "Make Sure your weigh boats are large enough before you begin to measure!"
          note "Measure out the following reagents and add them to the beaker"
          check "#{0.596 * $totalBottles} potassium Chloride"
          check "#{1.56 * $totalBottles} MES"
          check "#{29.12 * $totalBottles} Mannitol"
        end
        
    end
    
    def pHProbe
        show do
            title "Prepare to Measure pH"
            check "Aquire and Prepare the pH meter"
            check "Get a bottle of 0.1M NaOH from where you can find it" # Find details
            check "Grab a 1000 uL pipetter with tips"
            note "When the reagents have fully disolved move on to the next step"
        end
        
        show do
            title "Measure pH"
            note "Open the NaOH and place it in a tube rack"
            note "With the stir bar still running Submerge the pH probe in the solution note the pH and begin adding small amounts of NaOH until the pH reads 5.7"
            check "The pH of the solution is within 0.02 of 5.7"
        end
        
        show do 
            title "Top off Solution"
            note "Using DI water fill the beaker to </b>#{$totalBottles*400} mL</b>"
        end
        
        show do
            title "Return pH Adjustment supplies"
            check "Return pH meter"
            check "Return NaOH"
            check "Return Pipetter"
        end
    end
    
    def finishUp
        
        show do
            title "Transfer Solution to Bottles"
            note "Either pour or use the the serilogical pipette to dispense 400 mL of reagent into each bottle"
        end
        
        show do
            title "Prep and Label"
            check "Loosely screw a cap onto each bottle and mark it with autoclave tape."
            note "label the bottles with the following"
            operations.each do |op|
                check "#{op.output(OUTPUT).collection.id}"
            end
            note "Place the bottles in the Autoclave to be autoclaved"
        end
        
        show do
            title "Return materials"
            note "Return the following items:"
            check "Take the Beaker to the sink"
            check "MES (Orlando Shelf)" # 1.56g
            check "Mannitol (Orlando Shelf)" # 29.12g
            check "Potassium Chloride (Across from the fumehood)"#0.596 g
        end
    end
    

end

