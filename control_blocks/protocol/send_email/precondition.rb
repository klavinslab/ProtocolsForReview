def precondition(_op)
  _op = Operation.find(_op)
  plan = _op.plan
  subject = _op.input("Subject").val
  message = _op.input("Message").val
  aq_url = Parameter.get("URL")
  message += "<br><a href='#{aq_url}/plans?plan_id=#{plan.id}'>#{plan.id} - #{plan.name}</a>"
  user = _op.user
  user.send_email subject, message
  _op.status = "done"
  _op.save
end