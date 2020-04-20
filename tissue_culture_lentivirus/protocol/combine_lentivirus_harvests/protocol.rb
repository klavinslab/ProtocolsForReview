needs "Tissue Culture Libs/TissueCulture"

class Protocol
    include TissueCulture
    
  INPUT = "Lentivirus Harvest"
  OUTPUT = "Combined Harvest"
  
  def volume_calculations ops
    ops.each do |op|
        input_tubes = op.input_array(INPUT).map { |fv| fv.item } 
        total_volume = input_tubes.map { |t| t.get(:volume) }.reduce(:+)
        num_tubes = (35.0 / total_volume).ceil
        op.temporary[:num_tubes] = num_tubes
        op.temporary[:total_volume] = total_volume
        op.temporary[:input_tubes] = input_tubes
        op.temporary[:output_tube_labels] = num_tubes.times.map { |i| "#{op.output(OUTPUT).item.id} #{i+1}/#{num_tubes}" }
        op.temporary[:tube_vol] = total_volume * 1.0 / num_tubes
    end
  end
  
  def main

    operations.retrieve interactive: false
    operations.make
    
    tubes = operations.running.map { |op| op.input_array(INPUT).map { |fv| fv.item } }.flatten.uniq
    
    if debug
        tubes.each { |t| t.associate :volume, 13 }
    end
    
    volume_calculations operations.running
    
    spin_temp = 25
    spin_time = 10
    spin_speed = 500
    
    lentivirus_warning()
    
    prep_centrifuge(spin_time, spin_temp)
    
    show do
        title "Bring tubes into BSL2 room"
        check "Grab the leak-proof container containing the following tubes and enter the BSL2 room"
        t = Table.new
        t.add_column("Lentivirus Tubes", tubes.map { |i| i.id } )
        t.add_column("Location", tubes.map { |i| i.location } )
        table t
    end
    
    centrifuge_samples(tubes, spin_speed, spin_time, spin_temp, with_prep=false)
    
    show do
        title "Pool supernatent from samples"
        warning "Clean up spills immediately with #{ENVIROCIDE}"
        # check "Filter  through 0.45uM filter"
    end
    
    show do
        title "Combine the following lentivirus harvests"
        table operations.running.start_table
            .custom_column(heading: "Tubes") { |op| op.temporary[:input_tubes].map{|i| i.id}.join(' + ') }
            .output_item(OUTPUT, heading: "Combined Tube")
            .end_table
    end
    
    operations.running.each do |op|
        op.output(OUTPUT).item.volume = op.input_array(INPUT).map { |fv| fv.item.volume }.reduce(:+)
    end
    
    operations.running.each do |op|
        op.input_array(INPUT).each { |fv| fv.item.mark_as_deleted }
    end
    
    operations.store interactive: false
    
    return {}
    
  end

end
