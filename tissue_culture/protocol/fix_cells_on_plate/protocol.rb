needs "Tissue Culture Libs/TissueCulture"

class Protocol
    include TissueCulture
    
    INPUT = "Plate"
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
    
    put_in_hood [PFA, PBS]
    
    show do
        title "Remove media"
        
        check "Using a glass pipette and aspirator, remove media from the following plates."
        
        table operations.running.start_table
            .input_item(INPUT)
            .custom_column(heading: "Vol (mL)") { |op| op.temporary[:PBS_vol] }
            .end_table
    end
    
    show do
        title "Rinse with #{PBS}"
        
        check "Add #{PFA} to the following plates"
        check "Gently mix on the plate"
        check "Aspirate off #{PBS}"
        
        table operations.running.start_table
            .input_item(INPUT)
            .custom_column(heading: "Vol (mL)") { |op| op.temporary[:PBS_vol] }
            .end_table
    end
    
    show do
        title "Incubate #{PFA}"
        
        check "Add #{PFA} to the following wells"
        check "Wait 10 minutes"
        
        table operations.running.start_table
            .input_item(INPUT)
            .custom_column(heading: "Vol (mL)") { |op| op.temporary[:PFA_vol] }
            .end_table
    end
    num_washes = 2
    
    num_washes.times.each do |i|
        show do
            title "Rinse #{i+1} with #{PBS}"
            
            check "Apirate off liquid"
            check "Add #{PBS} to the following wells"
            check "Gently swirl"
            
            table operations.running.start_table
                .input_item(INPUT)
                .custom_column(heading: "Vol (mL)") { |op| op.temporary[:PBS_vol] }
                .end_table
        end
    end
    
    show do
        title "Add #{PBS}"
        
        check "Aspirate off liquid"
        check "Add #{PBS} to the following wells"
        check "Gently swirl"
        
        table operations.running.start_table
            .input_item(INPUT)
            .custom_column(heading: "Vol (mL)") { |op| op.temporary[:PBS_vol] }
            .end_table
    end
    
    # operations.running.each do |op|
    #     op.output(OUTPUT).item.move "4C Fridge"
    # end
    
    operations.store interactive: false
    return {}
    
  end

end
