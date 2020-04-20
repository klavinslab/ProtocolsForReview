require 'date'

def precondition(op)
    return true
  # Set harvests to days 2,3,etc.
  input_fv_name = op.inputs.first.name
  
    ops = op.inputs.collect do |input|
      input.wires_as_dest.collect do |wire|
        wire.from.successors.collect { |pred| pred.operation }
      end
    end
    ops.flatten!
    
  ops.select! { |o| o.operation_type == op.operation_type }
  ops.sort! { |o| o.id }
  ops.each { |o| o.input(input_fv_name).retrieve }
  ops.each.with_index do |o, i| 
    input_fv = o.input(input_fv_name)
    input_item = input_fv.item
    ready_in_hours = 24.0 + 8.0 + 24.0*i # Days 2,3,...
    ready_in_seconds = 3600.0 * ready_in_hours
    if input_item
        ready_time = input_item.created_at + ready_in_seconds
        o.associate :harvest_day, (ready_in_seconds/3600.0/24.0).floor
        o.associate :chained_harvest_operation_ids, ops.map { |op| op.id }.join(", ")
        o.associate :precondition_status, "Lentivirus harvesting will be ready on #{ready_time.strftime("%a %y-%m-%d")}"
        o.associate :ready_on, "#{ready_time.strftime("%a %y-%m-%d")}"
    end
  end
  r = op.get(:ready_on)
  if r
    r = Date.parse(r).to_time
    if r > Time.now
        return false
    end
  end
  o.associate :precondition_status, "Ready"
  true
end