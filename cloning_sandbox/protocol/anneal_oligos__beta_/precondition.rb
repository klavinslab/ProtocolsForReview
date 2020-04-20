def precondition(_op)
    ot1 = _op.input("Forward Primer").object_type.id
    ot2 = _op.input("Reverse Primer").object_type.id

    warning_key = "precondition_warning"
    plan_key = "#{warning_key} [#{_op.id}]"
    if ot1 != ot2
        _op.associate(warning_key, "Container types for inputs must be the same in order to anneal oligos") 
        _op.plan.associate(plan_key, "Container types for inputs must be the same in order to anneal oligos") if _op.plan
        return false
    end
    
    _op.associate(warning_key, "resolved") 
    _op.plan.associate(plan_key, "resolved") if _op.plan
    # _op.get_association(warning_key).delete
    # _op.plan.get_association(plan_key).delete
    true
end