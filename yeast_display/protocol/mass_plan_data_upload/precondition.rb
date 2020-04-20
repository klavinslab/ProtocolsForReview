def precondition(operation)
  # this protocol only begins if all other operations in the plan have completed
  all_ops = operation.plan.operations - [operation]
  if all_ops.empty? || !(all_ops.all? { |op| op.status == 'done' || op.status == 'error'})
    operation.associate("Waiting on rest of plan", "This operation is meant to be run after all other operations in the plan are finished")
    return false
  else
    operation.get_association("Waiting on rest of plan").delete if operation.get_association("Waiting on rest of plan")
    return true
  end
end