def precondition(op)
    if op.plan
        # associate plate id if possible
        plate = op.input("PCR").sample.in("Yeast Plate").last
        op.plan.associate "yeast_plate_#{plate.sample.id}", plate.id if plate
    end
    
    return op.input("PCR").sample.properties["QC_length"].present?
end