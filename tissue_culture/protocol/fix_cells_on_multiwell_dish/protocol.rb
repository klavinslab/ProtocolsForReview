needs "Tissue Culture Libs/TissueCulture"

class Protocol
    include TissueCulture
    
    INPUT = "Multiwell Dish"
    INCUBATION_TIME = 10 # minutes
    
  def volume_calculations ops
    ops.each do |op|
      op.temporary[:PFA_vol] = op.input(INPUT).item.working_volume * 0.5
      op.temporary[:PBS_vol] = op.input(INPUT).item.working_volume
    end
  end
  
  def main
    operations.running.retrieve
    
    volume_calculations operations.running
    
    show do
        title "Remove media"
        
        check "Using a glass pipette and aspirator, remove media from the following highlighted wells."
        note "You can reuse the glass pipette in the next step."
        
        operations.running.each do |op|
            collection = op.input(INPUT).collection
            table highlight_non_empty(collection)
        end
    end
    
    show do
        title "Rinse with #{PBS}"
        
        check "Add #{PFA} to the following wells"
        check "Gently swirl"
        check "Aspirate off #{PBS}"
        
        operations.running.each do |op|
            fv = op.input(INPUT)
            table highlight_non_empty(fv.collection) { |r,c| "#{fv.item.working_volume} mL" }
        end
    end
    
    show do
        title "Incubate #{PFA}"
        
        check "Add #{PFA} to the following wells"
        check "Wait #{INCUBATION_TIME} minutes"
        
        operations.running.each do |op|
            fv = op.input(INPUT)
            table highlight_non_empty(fv.collection) { |r,c| "#{fv.item.working_volume * 0.5} mL" }
        end
    end
    num_washes = 2
    
    num_washes.times.each do |i|
        show do
            title "Rinse #{i+1}: #{PBS}"
            
            check "Apirate off liquid"
            check "Add #{PBS} to the following wells"
            check "Gently swirl"
            
            operations.running.each do |op|
                fv = op.input(INPUT)
                table highlight_non_empty(fv.collection) { |r,c| "#{fv.item.working_volume} mL" }
            end
        end
    end
    
    show do
        title "Add #{PBS}"
        
        check "Aspirate off liquid"
        check "Add #{PBS} to the following wells"
        check "Gently swirl"
        
        operations.running.each do |op|
            fv = op.input(INPUT)
            table highlight_non_empty(fv.collection) { |r,c| "#{fv.item.working_volume} mL" }
        end
    end
    
    operations.store
    return {}
    
  end

end
