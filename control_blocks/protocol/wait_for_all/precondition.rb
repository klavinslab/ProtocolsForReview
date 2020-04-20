def precondition(_op)
    plan = _op.plan
    if plan
        
        # select operations of same operation type
        ops = plan.operations.select { |op| op.operation_type.id == _op.operation_type.id }
        
        # experiment
        experiment = _op.input("Experiment Number").val.to_i
        
        # message key
        key = "Experiment #{experiment} (\"Waiting for All\")"
        ops = ops.select { |op| op.input("Experiment Number").val.to_i == experiment }

        _op.plan.associate("debug", "found #{ops.length} operations for experiment #{experiment}")
        
        waiting_ops = ops.reject { |op| ["delayed", "pending", "done"].include? op.status }
        _op.plan.associate("debug2", "found #{waiting_ops.length} operations")
        if waiting_ops.length == 0
            ops.each do |op|
                message = "Experiment #{experiment} is ready."
                ops.each do |op|
                    op.associate(key, message)
                end
                _op.plan.associate(key, message)
                
                # re-route inputs to outputs
                op.output("Output").set(item: op.input("Input").item)
                op.status = 'done'
                op.save()
            end
            return true
        else
            message = "Experiment #{experiment} is waiting for other operations #{waiting_ops.map { |op| op.id}} to complete."
            ops.each do |op|
                op.associate(key, message)
            end
            _op.plan.associate(key, message)
        end
    end
    return false
end