# DEF
INPUT = "Culture Condition"
OUTPUT = "Culture Plate"
TEMPERATURE = "Temperature (°C)"
REPLICATES = "Replicates"
def precondition(_op)
    true
end
# def precondition(_op)
#   # use the precondition to determine how many fv need to be planned in the output array of this operation
#   # gain access to operation instance methods
#   op = Operation.find(_op.id)
#   # Find the total amount of cultures that need to be generated
#   condition_replicates = op.input_array(INPUT).map do |fv|
#     condition_op = FieldValue.find(fv.wires_as_dest.first.from_id).operation # predecessor operation
#     replicate_num = condition_op.input(REPLICATES).val.to_i
#   end
#   total_replicates = condition_replicates.reduce(0, :+)
#   # Next find the number of experimental plates planned in this operation
#   output_array = op.output_array(OUTPUT)
#   planned_num_of_collections = output_array.length
#   oti = AllowableFieldType.find(op.outputs[0].allowable_field_type_id).object_type_id
#   ot = ObjectType.find(oti)
#   # Finally, compare the values and allow the operation to go to pending or error with a message to replan/update
#   required_num_of_collections = total_replicates > 96 ? (total_replicates/(ot.rows*ot.columns)).ceil : 1 # Will always need at least one plate
#   if planned_num_of_collections == required_num_of_collections
#     op.get_association("CANNOT RUN, experiment definition is incomplete").delete if op.get_association("CANNOT RUN, experiment definition is incomplete")
#     return true;
#   else
#     op.associate("CANNOT RUN, experiment definition is incomplete", "This experiment has a total of #{total_replicates} replicates that requires #{required_num_of_collections} #{ot.name} to be planned, but this operation only has #{planned_num_of_collections}.")
#     return false;
#   end
# end

