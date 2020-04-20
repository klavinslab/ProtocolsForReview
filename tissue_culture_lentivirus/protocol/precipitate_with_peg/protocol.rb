needs "Tissue Culture Libs/TissueCulture"
needs "Tissue Culture Libs/DNA"

class Protocol
  include TissueCulture
  include DNA
  
  INPUT = "Lentivirus Harvest"
  OUTPUT = "Precipitated Lentivirus"
  
  def main
    lentivirus_warning()
    operations.retrieve interactive: false
    grab_lentivirus()
    add_peg()
    cleanup_output() # output associations, move items, delete inputs
    return {}
  end
  
  def grab_lentivirus()
    show do
        title "Grab lentivirus harvest from #{MAINLAB}"
        note "Lentivirus is in a leak proof contained in the 4C in the #{MAINLAB}."
        check "Retrieve container (wear a glove on one hand to carry it, use the ungloved hand to open doors etc.)"
        table operations.running.start_table
            .input_item(INPUT)
            .end_table
        operations.running.each { |op| op.input(INPUT).item.move BSL2 }
    end  
    check_lentivirus_volumes()
    put_in_hood(operations.running.map { |op| op.input(INPUT).item })
    operations.running.each { |op| op.input(INPUT).item.move HOOD }
  end
    
  def check_lentivirus_volumes()
    items_need_volume_validation = operations.running.select { |op| op.input(INPUT).item.volume.nil? }.map { |op| op.input(INPUT).item }
    check_volumes(items_need_volume_validation, with_contamination: false, unit: "mL", min: 0, max: 100) if items_need_volume_validation.any?
  end
  
  def add_peg()
    show do
        title "Add PEG solution"
        table operations.running.start_table
        .input_item(INPUT)
        .custom_column(heading: "40% PEG (mL)") { |op| (op.input(INPUT).item.volume / 5.0).round(1) }
        .end_table
        # add peg (40%) to final concentration of 10%
    end # show
  end
  
  # Output associations
  # Move items
  # Delete inputs
  def cleanup_output()
    operations.running.make
    operations.running.each do |op|
        output_item = op.output(OUTPUT).item
        output_item.move "4C Fridge"
        output_item.volume = op.input(INPUT).item.volume * 1.2
        op.input(INPUT).item.mark_as_deleted
    end
    
    show do
        title "Relabel"
        check "Cross out the old lab and re-label with new label"
        table operations.running.start_table
            .input_item(INPUT, heading: "Old Label")
            .output_item(OUTPUT, heading: "New Label")
            .end_table
    end
    
    show do
        title "Return lentivirus to leak proof container"
        check "Sterilize the outside of the lentivirus tubes with #{ENVIROCIDE}."
        check "Plate lentivirus+PEG tubes into leak proof container."
        check "Seal container"
        check "Sterilize the outside of the container with #{ENVIROCIDE}."
        check "Remove all PPE"
        check "Move container to 4C fridge in #{MAINLAB}"
    end
    operations.store
  end # cleanup_output

end
