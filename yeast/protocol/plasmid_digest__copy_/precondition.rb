def precondition(op)
    ops = op.plan.operations.select { |o| o.name == "Yeast Transformation" } 
    return true if ops.blank?
    s = ops.select{ |o| o.input("Genetic Material").sample.id == op.input("Integrant").sample.id }.collect { |opr| opr.inputs.select { |i| i.name == "Parent" }.first }.first
    s && Item.where(sample_id: s.sample.id, object_type_id: 457).first
    #true
end