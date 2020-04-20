# TODO: OR if cells haven't been checked in awhile, use predicted cell growth rate
def precondition(op)
    return true
    successors = op.successors || []
    used_for = successors.map { |s| s.operation_type.name }.join(', ') || "?"
    op.associate :used_for, "Trypsinized cells will be used for #{used_for}."
    
  # Wait until input plate is > threshold confluent
    fv = op.input("Cell Plate")
    if not fv.object_type.name == "Plate Request"
        fv.retrieve
        plate = fv.item
        r = plate.get :confluency_history if plate
        cr = r.last if r
        confluency = cr[:confluency] if cr
        if confluency
            if confluency > plate.sample.properties["Confluency Threshold"]
                op.associate :plate_status, "Plate is ready. Plate is at #{confluency}%"
                return true
            else
                op.associate :plate_status, "Plate is not ready. Plate is at #{confluency}%"
                return false
            end
        else
            return false
        end
    else
        return true
    end
#   op.input("Cell Plate").retrieve
#   plate = 
#   r = op.input("Cell Plate").item.get :confluency_history
#   cr = r.last if r
#   confluency = cr[:confluency] if cr
  op.associate :plate_status, "Plate is ready. Plate is at #{confluency}%"
  true
  # Here, you will autobatch scheduled on-the-fly jobs if they
  # have the same input item
end