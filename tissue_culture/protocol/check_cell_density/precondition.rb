def precondition(op)
    same_object_type = (op.output("Plate").allowable_field_type.object_type_id == op.input("Plate").allowable_field_type.object_type_id)
    return same_object_type
    # # op.asssociate
    # if !same_object_type
    #     op.associate('precondition_status', 'Input and output object_type_id must be the same')
    # else:
    #     op.associate('precondition_status', 'Passing')
    # end
    
    # return same_object_type
end