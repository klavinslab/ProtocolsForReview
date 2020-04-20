def precondition(op)
  # if debug
  #    return true
  # end
  
  pending_orders = Operation.where("status IN (?) && operation_type_id IN (?)", ["waiting", "pending", "delayed"], OperationType.where("name = 'Order Primer'").map { |order| order.id })
  total_cost = pending_orders.inject(0) { |sum, order| sum + order.nominal_cost[:materials] }
  
  urgent = op.input("Urgent?").val.nil? || op.input("Urgent?").val.downcase == "yes"
  if (urgent ||
     pending_orders.any? { |order| order.input("Urgent?").val.nil? || order.input("Urgent?").val.downcase == "yes" } ||
     total_cost > 50 ) && op.output("Primer").sample.properties["Overhang Sequence"] && op.output("Primer").sample.properties["Anneal Sequence"]
     return true
  end
  
  return false
end