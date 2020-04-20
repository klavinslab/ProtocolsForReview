needs "Tissue Culture Libs/TissueCulture"

class Protocol
    include TissueCulture
    
    INPUT = "Lentivirus Plate"
    OUTPUT = "Lentivirus Harvest"
    
  def main

    operations.retrieve.make
    
    required_ppe STANDARD_PPE
    
    open_hood
    
    required_items = [
        "15mL conical tube rack",
        "#{operations.running.size} X 15mL conical tubes"
    ]
    
    put_in_hood required_items
    
    show do
        title "Label conical tubes"
        
        table operations.running.start_table
            .output_item(OUTPUT)
            .end_table
    end
    
    show do
        title "Place the following plates in the #{HOOD}"
        warning "Lentivirus is hazardous!"
        
        table operations.running.start_table
            .input_item(INPUT)
            .end_table
    end
    
    show do
        title "Pipette media from plate into conical tube"
        warning "Lentivirus is hazardous! Clean up spills immediately with #{ENVIROCIDE}!"
        
        table operations.running.start_table
            .input_item(INPUT, heading: "Plate")
            .output_item(OUTPUT, heading: "Tube")
            .custom_column(heading: "Vol (mL)") { |op| op.input(INPUT).item.working_volume }
            .end_table
    end
    
    show do
        title "Place conical tubes in leak-proof container"
        
        check "While still in the #{HOOD}, sterilize the outside of the tube with #{ENVIROCIDE}"
        check "Place leak proof container into fridge"
        check "Sterilize the outside of the container with #{ENVIROCIDE}"
        check "Remove container from #{HOOD}"
        warning "Clearly label the container as biohazardous!"
    end
    
    show do
        title "Store container with lentivirus in 4C fridge."
    end
    
    operations.running.each do |op|
        op.output(OUTPUT).item.move "4C in leak proof container"
        op.output(OUTPUT).item.volume = op.input(INPUT).item.working_volume
    end
    
    operations.store
    
    return {}
    
  end

end
