def precondition(_op)
  if _op.plan
      _op = Operation.find(_op.id)
      status_key = "Recieve from Operation status"
      plan_status_key = "#{status_key} (#{_op.id})"
      
      output = _op.output("Output")
      other_op_id = _op.input("Operation Id").val.to_i
      other_op = Operation.find(other_op_id)
      
      if other_op.nil?
        msg = "No Operation with id #{other_op_id} found"
        _op.plan.associate(plan_status_key, msg)
        _op.associate(status_key, msg)
        return false
      end
      
      other_output_fv_name = _op.input("Output Field Value Name").val
      other_output_fv = other_op.output(other_output_fv_name)
      if other_output_fv.nil?
        msg = "No Field value with name #{other_output_fv_name} found. Available outputs: #{other_op.outputs.map { |fv| fv.name }}"
        _op.plan.associate(plan_status_key, msg)
        _op.associate(status_key, msg)
        return false
      end
      
      other_output_sample = other_output_fv.sample
      if other_output_sample.id != output.sample.id
        msg = "Output sample #{output.sample.id}: #{output.sample.name} does not match output sample #{other_output_sample.id} #{other_output_sample.name}"
        _op.plan.associate(plan_status_key, msg)
        _op.associate(status_key, msg)
        return false
      end
      
      other_output_ot = other_output_fv.object_type
      if other_output_ot.id != output.object_type.id
        msg = "Output object type #{output.object_type.id}: #{output.object_type.name} does not match output sample #{other_output_ot.id} #{other_output_ot.name}"
        _op.plan.associate(plan_status_key, msg)
        _op.associate(status_key, msg)
        return false
      end
      
      other_output_item = other_output_fv.item
      if other_output_item.nil?
        msg = "Waiting for item from Operation #{other_op.id} in Plan #{other_op.plan.id}"
        _op.plan.associate(plan_status_key, msg)
        _op.associate(status_key, msg)
        return false
      else
        msg = "Item #{other_output_item.id} found from operation #{other_op.id}"
        _op.plan.associate(plan_status_key, msg)
        _op.associate(status_key, msg)
        _op.output("Output").set(item: other_output_item)
        _op.status = "done"
        _op.save()
        return true
      end
      
      return false
  end
  return false
end