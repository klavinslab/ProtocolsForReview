def precondition(op)
    ready = true
    items = Item.where(object_type_id: ObjectType.find_by_name("ordered").id).reject { |i| i.deleted? }
    ready = items.any?
    if not ready
        op.associate :precondition_warning, "There are no outstanding orders."
    else
        op.associate :precondition_warning, nil
    end
    ready
end