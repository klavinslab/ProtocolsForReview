def precondition(_op)
  plan = _op.plan
  plan.associate('debug', Time.zone.now)
  if plan
    _op = Operation.find(_op)
    #
    t = _op.input("Time").val
    unit = _op.input("Unit").val
    target_time = {unit.to_sym => t}
    num_seconds = (target_time[:minutes] || 0) * 60 +
        (target_time[:hours] || 0) * 60 * 60 +
        (target_time[:days] || 0) * 60 * 60 * 24

    key = "Time remaining (Delay)"
    plan_key = "#{key} [#{_op.id}]"

    input_fv = _op.input("Input")

    t1 = nil
    if input_fv.predecessors.any?
      t1 = input_fv.predecessors.first.updated_at
    elsif
    log_status(_op, "no predecessors found!")
      return false
    end
    t2 = Time.now
    delta_t = t2 - t1
    remaining_seconds = num_seconds - delta_t
    ready = compare_time(delta_t, {unit.to_sym=>t})

    if ready
      _op.pass("Input", "Output")
      _op.change_status "done"
      _op.save()
      # _op.save
      log_status(_op, "#{0} #{unit}")
      return false
    end

    delta_t = t2 - t1
    msg = "#{remaining_seconds} #{unit}"
    log_status(_op, msg)
  end
  return false
end

def log_status(op, msg)
  key = "Time remaining (Delay)"
  plan_key = "#{key} [#{op.id}]"
  op.associate(key, msg)
  op.plan.associate(plan_key, msg)
end

def compare_time delta_time, target_time

  num_seconds = (target_time[:minutes] || 0) * 60 +
      (target_time[:hours] || 0) * 60 * 60 +
      (target_time[:days] || 0) * 60 * 60 * 24
  return delta_time >= num_seconds
end

def get_t1 input_fv
  if input_fv.predecessors.any?
    pred = input_fv.predecessors.first
    if pred.status == 'done'
      return pred.updated_at
    else
      # return -1 if still waiting for predecessors
      return -1
    end
  else
    return false
  end
end