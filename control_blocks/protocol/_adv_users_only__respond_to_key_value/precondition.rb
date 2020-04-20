eval Library.find_by_name("ControlBlock").code("source").content
extend ControlBlock


def precondition(_op)
  if _op.plan
    input_fv = "Input"
    yes_fv = "True Response"
    no_fv = "False Response"
    yes_output = "True"
    no_output = "False"

    # level = _op.input("Response Level").val
    level = "Plan"
    yes = _op.input(yes_fv).val.downcase
    no = _op.input(no_fv).val.downcase
    choices = [yes, no]
    message = _op.input("Response").val
    precondition_key = "Respond to Key-Value Association (\"#{message}\" for #{level})"
    plan_key = "(#{_op.id}) " + precondition_key

    #   res = ""
    case level
    when "Plan"
      res = _op.plan.get(message)
    when "Operation"
      res = _op.get(message)
    when "Sample"
      res = _op.input(input_fv).sample.properties[message].to_s
      _op.associate("debug", res)
    when "Item"
      res = _op.input(input_fv).item.get(message)
    end
    res ||= ""
    response_message = "No true or false response found."
    if res.downcase == yes.downcase
      response_message = "True response found (#{yes})."
      _op.output(yes_output).set(item: _op.input(input_fv).item)
      _op.output(no_output).set(item: nil)
      cancel_branches [_op.output(no_output)]
      _op.pass("Input", "True")
      op = Operation.find(_op.id)
      op.status = "done"
      op.save()
    elsif res.downcase == no.downcase
      response_message = "False response found (#{no})."
      _op.output(no_output).set(item: _op.input(input_fv).item)
      _op.output(yes_output).set(item: nil)
      cancel_branches [_op.output(yes_output)]
      op = Operation.find(_op.id)
      op.status = "done"
      op.save()
    end
    _op.associate(precondition_key, response_message)
    _op.plan.associate(plan_key, response_message)
  end
  return false
end