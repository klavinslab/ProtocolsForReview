eval Library.find_by_name("ControlBlock").code("source").content
extend ControlBlock

#TODO add check for output possibilities number matches the number of conditions
def precondition(op)
  op = Operation.find(op.id)
  input = op.input("Case Sample")
  outputs = op.array_output("Route Possibilites")
  cases = op.input("Branch Conditions").val
  
  # Concern about field value arrays: are they mutable? Is the ordering of field value arrays always the same??
  # 1: doesn't matter if the fv arrays are mutable since we are only effecting the field values themselves which are held in that array as references (setting an item field)
  #         an immutable arry
  # 2: Not sure, but some experiments, and some inspection in codebase on how fv arrays are built and filled could answer this
  
  good_outputs = []
  
  # evaluate a user given condition for each route
  cases.each do |route_idx, condition|
    condition = if condition[0..2] == ':::'
        condition[3..-1]
    else
        'input.' + condition
    end
    
    if eval(condition)
        good_outputs << outputs[route_idx]
    end
  end
  
  DynamicBranching::affirm_branches(good_outputs)
  DynamicBranching::cancel_branches(outputs - good_outputs)
  
  op.status = "done"
  op.save
end
