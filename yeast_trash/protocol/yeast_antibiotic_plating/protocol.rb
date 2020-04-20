class Protocol

  def main

    operations.each do |op|
        if op.input("Overnight").sample.properties["Integrant"].nil?
            op.error :no_integrant, "Make sure to enter an integrant for #{op.input("Overnight").sample.name}"
        end
    end

    operations.retrieve.make
    operations.each do |op|
        op.plan.associate :yeast_plate, op.output("Plate").item.id
    end
    
      show do
        title "Transfer into 1.5 mL tube"
        
        check "Take #{operations.running.length} 1.5 mL tube, label with #{operations.running.map { |op| op.input("Overnight").item.id }}."
        check "Transfer contents from 14 mL tube to each same id 1.5 mL tube."
        check "Recycle or discard all the 14 mL tubes."
      end

      show do
        title "Resuspend in water"
        
        check "Spin down all 1.5 mL tubes in a small table top centrifuge for ~1 minute"
        check "Pipette off supernatant being careful not to disturb yeast pellet"
        check "Add 600 uL of sterile water to each eppendorf tube"
        check "Resuspend the pellet by vortexing the tube throughly"
        warning "Make sure the pellet is resuspended and there are no cells stuck to the bottom of the tube"
      end

      operations.running.each do |op|
          marker = op.input("Overnight").sample.properties["Integrant"].properties["Yeast Marker"].downcase[0,3]
          marker = "kan" if marker == "g41"
          op.temporary[:marker] = marker
      end
      
      ops_by_marker = Hash.new {|h,k| h[k] = [] }
      operations.running.each do |op|
        ops_by_marker[op.temporary[:marker]].push op
      end

      antibiotic_hash = { "nat" => "clonNAT", "kan" => "G418", "hyg" => "Hygro", "ble" => "Bleo", "5fo" => "5-FOA" }

      tab_plate = [["Plate Type","Quantity","Id to label"]]
      ops_by_marker.each do |marker, ops|
        ant_marker = antibiotic_hash[marker]
        tab_plate.push( [antibiotic_hash[marker], ops.length, ops.collect { |op| op.output("Plate").item.id }.join(", ") ])
        
        for i in 1..ops.length
          plate = Sample.find_by_name("YPAD + #{ant_marker}").in("Agar Plate")[0]
          plate.mark_as_deleted if plate
          i += 1
        end
      end

      show do
        title "Plating"
        
        check "Grab plates and label with your initials, the date, and the following ids on the top and side of the plate."
        table tab_plate
        check "Flip the plate and add 4-5 glass beads to it"
        check "Add 200 uL of 1.5 mL tube contents according to the following table"
        
        table operations.running.start_table
            .input_item("Overnight")
            .output_item("Plate")
        .end_table
      end

      show do
        title "Shake and incubate"
        
        check "Shake the plates in all directions to evenly spread the culture over its surface till dry"
        check "Discard the beads in a used beads container."
        check "Throw away all 1.5 mL tubes."
        check "Put the plates with the agar side up in the 30C incubator."
      end

      operations.running.each do |op|
          plate = op.output("Plate").item
          plate.location = "30 C incubator"
          plate.save
          op.input("Overnight").item.mark_as_deleted
      end
    
    operations.store
    
    return {}
    
  end

end
