def precondition(_op)
    _op = Operation.find(_op.id)
    channel = _op.input("Channel").val
    key = "Channel #{channel} status"
    
    plan = _op.plan
  
    if plan
        if _op.inputs.length == 0
            plan.associate(key, "Listening for items...")
            return false
        end
        senders = get_senders(_op)
        selector = _op.input("Selection Method").val
        
        sender = nil
        
        case selector
        when "First"
            sender = senders.first
        when "Last"
            sender = senders.last
        when "Random"
            sender = sender.sample
        end
        
        if sender.nil?
            plan.associate(key, "Listening for items...")
            return false
        end
        
        item = sender.output("Output").item
        plan.associate(key, "Selected #{selector.downcase} item ##{item.id} from operation ##{sender.id}")
        
        _op.set_input("Input", item.sample)
        _op.output("Output").set(item: item)
        _op.status = "done"
        _op.save
        
    end
  
    return false
end

def get_senders(listener_op)
    op_type_name = "[ADV USERS ONLY] Send to Channel"
    send_op_type = OperationType.where({"name": op_type_name, "category": listener_op.operation_type.category}).first
    if send_op_type.nil?
        listener_op.associate("no sender type found", "No OperationType #{op_type_name} found.")
        return []
    end
    
    senders = plan.operations.select { |op| op.operation_type.id == send_op_type.id }
    senders.select! { |op| op.input("Channel").val == listener_op.input("Channel").val }
    senders.select! { |op| op.output("Output").sample.id == listener_op.output("Output").sample.id }
    senders.select! { |op| !op.output("Output").item.nil? }
    return senders
end