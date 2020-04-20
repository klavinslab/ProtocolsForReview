def precondition(_op)
  # gain access to operation instance methods 
  op = Operation.find(_op.id)
  
  conditions = op.input_array("Culture Condition")
  experimental_plates = op.output_array("Overnight Experimental Prep Plate")
  
  # ensure all inputs represent valid induction condition definitions
  conditions.each do |condition|
    input_wire = condition.wires_as_dest.first
    dic_op = FieldValue.find(input_wire.from_id).operation if input_wire
    if !(input_wire && dic_op.name == "Define Culture Conditions")
      op.associate("CANNOT RUN, experiment definition is incomplete", "All inputs must be wired from a 'Define Induction Condition' block")
      return false;
    end
  end
  
  # ensure the amount of outputs and inputs makes sense
  expected_plate_amount = (conditions.size / 96.0).ceil
  if (expected_plate_amount != experimental_plates.size)
    op.associate("CANNOT RUN, experiment definition is incomplete", "With #{conditions.size} conditions, #{expected_plate_amount} output plates would be needed, but this operation has #{experimental_plates.size} outputs")
    return false;
  end
  
  # experiment seems well defined, remove error messages from op and affirm precondition
  op.get_association("CANNOT RUN, experiment definition is incomplete").delete if op.get_association("CANNOT RUN, experiment definition is incomplete")
  return true;
end