# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
needs "Tissue Culture Libs/PlateTransfectionLib"

class Protocol
  include PlateTransfectionLib
  
  DNA = "Lentivirus DNA Complex"
  CELLS = "Packaging Cell Line"
  OUTPUT = "Packaging Plate"

  def main

    operations.retrieve.make

    # if debug
    #   operations.running.each do |op|
    #     op.input(DNA).item.associate :part_associations, FAKE_DNA_COMPLEX_DATA
    #   end
    # end

    transfer_data_to_temporary(operations.running) {|op| op.input(DNA)}

    # Make sure input and outputs are routed correctly
    operations.running.each do |op|
      op.output(OUTPUT).set object_type: op.input(CELLS).object_type
    end

    show do
      title "Add transfection reagent to cells"

      table operations.running.start_table
              .input_item(CELLS, heading: "Plate")
              .custom_column(heading: "DNA Complex Tube") {|op| op.temporary[:C_tube]}
              .custom_column(heading: "Vol (ul)") {|op| op.temporary[:total_vol]}
              .end_table
    end

    operations.running.make

    show do
      title "Relabel plates"

      check "Label old plate with new plate id"
      check "Cross out old plate id"
      warning "Add the following warning to each plate: <b>\"LENTIVIRUS!!!\"</b>"

      table operations.running.start_table
              .input_item(CELLS, heading: "Old Label")
              .output_item(OUTPUT, heading: "New Label")
              .custom_column(heading: "Warning Label") { |op| "LENTIVIRUS!!!" }
              .end_table
    end

    operations.running.each do |op|
      op.input(CELLS).item.mark_as_deleted
      op.input(DNA).item.mark_as_deleted
    end

    operations.store

    return {}

  end

end