# TODO: After you put 
needs "Tissue Culture Libs/TissueCulture"
needs "Tissue Culture Libs/DNA"

class Protocol
  include TissueCulture
  include DNA
  INPUT = "Lentivirus Harvest"
  OUTPUT = "Concentrated Lentivirus Harvest"
  
  SPINSPEED = 1500 # x g
  SPINTIME = 30 # minutes
  SPINTEMP = 4
  
  def main
    lentivirus_warning()
    prepcentrifuge()
    operations.retrieve
    volume_calculations()
    check_lentivirus_volumes()
    cleanup_outputs()
    spindown()
    endprotocol()
    return {}
  end
  
  def check_lentivirus_volumes()
    items_need_volume_validation = operations.running.select { |op| op.input(INPUT).item.volume.nil? }.map { |op| op.input(INPUT).item }
    check_volumes(items_need_volume_validation, with_contamination: false, unit: "mL", min: 0, max: 100) if items_need_volume_validation.any?
  end
  
  def prepcentrifuge()
    prep_centrifuge(SPINTIME, SPINTEMP)
  end
  
  def spindown()
    samples = operations.running.map { |op| op.input(INPUT).item }
    centrifuge_samples(samples, SPINSPEED, SPINTIME, SPINTEMP, with_return=false, with_prep=false)
  end
  
  def volume_calculations()
      operations.running.each do |op|
        op.input(INPUT).item.volume = rand(13..50) if debug
      end
  end
  
  def cleanup_outputs()
    operations.running.make
    operations.running.each do |op|
      op.output(OUTPUT).item.volume = op.input(INPUT).item.volume
      op.output(OUTPUT).item.move HOOD
      op.input(INPUT).item.mark_as_deleted
    end
    show do
        title "Relabel tubes"
        check "For each tube, cross out old label and add new label."
        table operations.running.start_table
            .input_item(INPUT, heading: "Old Label")
            .output_item(OUTPUT, heading: "New Label")
            .end_table
    end
  end
  
  def endprotocol()
    show do
        title "Proceed immediately to Aliquot Concentrated Lentivirus protocol"
    end
    operations.store interactive: false
  end

end
