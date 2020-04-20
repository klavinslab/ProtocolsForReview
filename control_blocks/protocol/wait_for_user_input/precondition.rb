eval Library.find_by_name("ControlBlock").code("source").content
extend ControlBlock

def precondition(_op)
  plan = _op.plan

  message = _op.input("Response Message").val
  plan_message = "(#{_op.id}) " + message
  precondition_key = "Waiting for User Input"
  plan_key = "(#{_op.id}) " + precondition_key
  yes = _op.input("Expected Yes").val
  no = _op.input("Expected No").val
  default_response = "#{yes}; #{no}"
  choices = [yes.downcase, no.downcase]

  input_fv = "Input"
  yes_fv_name = "Yes Response"
  no_fv_name = "No Response"


  # TODO: set operation children to error

  if plan
    # get response from plan
    plan_response = _op.plan.get(plan_message)
    if plan_response.nil?
      plan_response = default_response
      _op.plan.associate(plan_message, default_response)
    end

    # get response for operation
    op_response = _op.get(message)
    if op_response.nil?
      op_response = default_response
      _op.associate(message, default_response)
    end

    plan_response.downcase!
    op_response.downcase!

    # check for conflicting responses
    if choices.include?(plan_response) and choices.include?(op_response)
      if plan_response != op_response
        error_message = "Conflicting responses between operation #{_op.id} and plan #{_op.plan.id}. Please resolve."
        _op.associate(precondition_key, error_message)
        _op.plan.associate(plan_key, error_message)
        _op.associate(message, default_response)
        _op.plan.associate(plan_message, default_response)
        return false
      end
    end

    # default to plan response
    res = default_response
    if choices.include? plan_response
      res = plan_response
    else
      choices.include? op_response
      res = op_response
    end
    _op.associate(message, res)
    _op.plan.associate(plan_message, res)

    # TODO: somehow set other branch to errored in plan...
    # if YES or NO, reroute and save, finally associate messages
    response_message = "User has not selected either \"yes\" or \"no\"."
    if res.downcase == yes.downcase
      response_message = "User selected \"Yes\" (#{yes})."
      _op.output(yes_fv_name).set(item: _op.input(input_fv).item)
      _op.output(no_fv_name).set(item: nil)
      op = Operation.find(_op.id)

      cancel_branches [op.output(no_fv_name)]

      op.change_status("done")
      op.save()

      # _op.output(no_fv_name).successors.each do |fv|
      #     op_id = fv.operation.id
      #     fv_op = Operation.find(op_id)
      #     fv_op.associate("debug", "set to error")
      #     fv_op.status = "error"
      #     fv_op.save()
      # end
    elsif res.downcase == no.downcase
      response_message = "User selected \"No\" (#{no})."
      _op.output(no_fv_name).set(item: _op.input(input_fv).item)
      _op.output(yes_fv_name).set(item: nil)
      op = Operation.find(_op.id)

      cancel_branches [op.output(yes_fv_name)]

      op.change_status("done")
      op.save()
    end
    _op.associate(precondition_key, response_message)
    _op.plan.associate(plan_key, response_message)
  end
  return false
end