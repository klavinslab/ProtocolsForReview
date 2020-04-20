# TODO: Remove supernatent into waste bucket
# TODO: Warning about viscous solution
# TODO: Get rest of solution with smaller pipette

needs "Tissue Culture Libs/TissueCulture"
needs "Tissue Culture Libs/DNA"

class Protocol
  include TissueCulture
  include DNA
  
  INPUT = "Concentrated Harvest"
  OUTPUT = "Concentrated Aliquot"
 
  def main
      
          
    tin  = operations.io_table "input"
    
    show do 
      title "Input Table"
      table tin.all.render
    end
      
    checkinputs()
    return({}) if operations.running.empty?
    lentivirus_warning()
    gather_and_label_tubes()
    getlentivirus()
    operations.retrieve()
    check_lentivirus_volumes()
    volume_calculations()
    resuspend()
    cleanup_outputs()
    endprotocol()
    return {}
  end
  
  def checkinputs()
    
  end
  
  def getlentivirus()
    return_buckets()
  end
  
  def cleanup_outputs()
    operations.running.each do |op| 
            op.input(INPUT).item.mark_as_deleted
            op.output_array(OUTPUT).each do |outfv|
                outfv.make
                outfv.item.volume = op.temporary[:aliquot_vol]
            end
    end
    operations.running.each do |op|
        show do
            title "Label and aliquot tubes with #{op.input(INPUT).item}"
            check "Label each cryotube with the following Item Id"
            check "Aliquot with the indicated volume using #{op.input(INPUT).item}."
            vops = items_to_vops op.output_array(OUTPUT).map { |fv| fv.item }
            vops.each.with_index { |op, i| op.temporary[:tube] = i+1 }
            table vops.start_table
                .custom_column(heading: "Tube") { |vop| vop.temporary[:tube] }
                .custom_column(heading: "Item Id") { |vop| vop.temporary[:item].id }
                .custom_column(heading: "Aliquot Vol (ul)") { |vop| vop.temporary[:item].volume.round(0) }
                .end_table
            vops.each { |op| op.temporary[:item].move "-80 (BSL2 Room)" }
            destory_virtual_operations
        end
    end
    alltubes = operations.running.map { |op| op.output_array(OUTPUT).map { |fv| fv.item } }.flatten
    vops = items_to_vops alltubes
    alltubetable = vops.start_table
                    .custom_column(heading: "Cryotube", checkable: true) { |op| op.temporary[:item] }
                    .end_table
    show do
        title "Flash freeze"
        check "???"
        table alltubetable
    end
    show do
        title "Put in -80C"
        table alltubetable
    end
    operations.store
  end
  
  def volume_calculations()
      operations.running.each do |op|
        # op.input(INPUT).item.volume = rand(13..50) if debug
        op.input(INPUT).item.volume = op.input(INPUT).item.volume.to_f
        op.temporary[:resuspend_vol] = 0.1 * op.input(INPUT).item.volume * 1000.0
        op.temporary[:aliquot_vol] = op.temporary[:resuspend_vol] / op.output_array(OUTPUT).size
      end
  end
  
  def endprotocol()
  end
  
  def resuspend()
    show do
        title "Remove supernatent"
        check "In the #{HOOD}, carefully remove the supernatent using a serological pipette."
        warning "Be careful not to disturb the cell pellet! It will be small and white."
    end
    
    show do
        title "Resusepend carefully in #{PBS}" 
        check "In the #{HOOD}, carefully resuspend virus pellet in #{PBS}"
        check "Very gently pipette up and down to resuspend virus pellet"
        warning "The virus in the cell pellet is <i>very</i> fragile. Pipette gently!"
        table operations.running.start_table    
            .input_item(INPUT)
            .custom_column(heading: "PBS Vol (uL)") { |op| op.temporary[:resuspend_vol].round(1) }
            .end_table
    end
  end

  def check_lentivirus_volumes()
    items_need_volume_validation = operations.running.select { |op| op.input(INPUT).item.volume.nil? }.map { |op| op.input(INPUT).item }
    check_volumes(items_need_volume_validation, with_contamination: false, unit: "mL", min: 0, max: 100) if items_need_volume_validation.any?
  end
  
  def gather_and_label_tubes()
    num_tubes = operations.running.map { |op| op.output_array(OUTPUT).size }.reduce(:+)
    show do
        title "Gather #{num_tubes} cryogenic tubes"
        check "Label tubes (TODO)" # TODO: label tubes
    end
  end


end
