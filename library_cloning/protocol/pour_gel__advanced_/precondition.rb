def precondition(op)
    if op.plan
      pcrs = op.plan.operations.select { |o|
          (o.operation_type.name == "Make PCR Fragment") || (o.operation_type.name == "Make qPCR Fragment")
      }
      pcrs.length == 0 || pcrs[0].status == 'done'
    else 
      true
    end
end