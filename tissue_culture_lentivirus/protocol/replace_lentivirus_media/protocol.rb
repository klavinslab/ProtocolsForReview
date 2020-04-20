needs "Tissue Culture Libs/TissueCulture"

class Protocol
  include TissueCulture
  
  INPUT = "Transfected Plate"
  OUTPUT = "Packaging Plate"

  def main
    operations.retrieve
    lentivirus_warning()
    required_ppe(STANDARD_PPE)
    replace_media_show()
    operations.running.each { |op| convert_input_to_output(op, INPUT, OUTPUT) }
    debug_shows()
    operations.store()
    return {}
  end
  
  def convert_input_to_output op, fv_input, fv_output
    input_item = op.input(fv_input).item
    op.output(fv_output).set item: input_item
    convert_object_type input_item, op.output(fv_output).object_type
  end
  
  def convert_object_type item, new_object_type
    item.object_type_id = new_object_type.id
    item.save
  end
  
  def replace_media_show
    show do
      title "Replace media for the following items"
        
      table operations.running.start_table
        .input_item(INPUT)
        .end_table
    end
  end
  
  def debug_shows
    if debug
        show do
            title "Debug"
            operations.running.each do |op|
                note "#{op.output(OUTPUT).item}"
                note "#{op.output(OUTPUT).item.object_type.name}"
            end
        end
    end
  end

end
