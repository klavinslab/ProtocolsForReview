def precondition(op)
    true
    
    # Validate the json
    # validate molar ratio matches plasmids
    # validate number of wells matches number of transfections
    
    
#   json = op.input("Transfection Parameters").val
#   ready = true
#   ready = false if json.include? :error
#   plan = op.plan
#   op.error :precondition_status, "JSON was not formatted correctly." if not ready
#   op.associate :misformatted_JSON, "#{json}" if not ready
#   op.error :preconditions_statu, "OK" if ready
#   if plan
#       plan.associate "precondition_status_#{op.id}".to_sym, "JSON was not formatted correctly." if not ready
#       plan.associate "precondition_status_#{op.id}".to_sym, "OK" if ready
#   end
#   ready
end