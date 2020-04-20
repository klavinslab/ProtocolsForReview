def precondition(op)
    if op.plan
        # associate plate id if possible
        plate = op.output("Lysate").sample.in("Yeast Plate").last
        op.plan.associate "yeast_plate_#{plate.sample.id}", plate.id if plate
    end
    
    id = op.plan.get("yeast_plate_#{op.output("Lysate").sample.id}") || op.plan.get(:yeast_plate)
    plate = Item.find_by_id(id)
    return op.plan.blank? || ( plate && plate.get(:num_colonies) && plate.get(:num_colonies) != 0)
end