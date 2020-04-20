def precondition(op)
    
    overnight = op.input("Overnight").item
    
    if overnight.nil?
        # op.plan.associate :nil_item, "nil input item for yeast antibiotic plating. Should not happen, try step all"
        return false
    end
    
    spin_off = Operation.find(overnight.get(:spin_off))
    if spin_off.nil?
        # op.plan.associate :no_MAP, "spin off operation does not exist. This error should not be thrown, try doing a step-all"
        return false
    end
    
    if spin_off.status == "done"
        return true
    else
        #spin off operation is not done
        return false
    end
end