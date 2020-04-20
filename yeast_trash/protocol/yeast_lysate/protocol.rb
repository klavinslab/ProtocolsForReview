class Protocol

  def main

    operations.retrieve

    # debuggin'
    if debug
        operations.each do |op|
            plate = Item.where(object_type_id: ObjectType.find_by_name("Yeast Plate").id).item
            op.plan.associate :yeast_plate, plate.id
            plate.associate :QC_result, ["No", "Yes", "Yes"] if [0, 1].sample == 0
        end
    end
    
    # put plate in temporary hash
    operations.each { |op| op.temporary[:yeast_plate] = Item.find(op.plan.get("yeast_plate_#{op.output("Lysate").sample.id}") || Item.find(op.plan.get(:yeast_plate))) }
    take operations.map { |op| op.temporary[:yeast_plate] }.uniq, interactive: true

    # pick colony and find tanneal (make sure to pick different colonies if picking from same plate)
    colonies_used_per_plate = {}
    operations.each do |op|
        plate = op.temporary[:yeast_plate] 
        
        qc_result = plate.get(:QC_result)
        colonies_used_per_plate[plate] = (colonies_used_per_plate[plate] || 0) + 1
        op.temporary[:colony] = (qc_result || []).length + colonies_used_per_plate[plate]
        
        if !plate.sample.properties["QC Primer1"]
            fwd = Sample.find_by_id(16749).properties["QC Primer1"]
            rev = Sample.find_by_id(16749).properties["QC Primer2"]
        else
            fwd = plate.sample.properties["QC Primer1"] 
            rev = plate.sample.properties["QC Primer2"]
        end
        op.temporary[:tanneal] = (fwd.properties["T Anneal"] + rev.properties["T Anneal"])/2
        
        
    end
    
    # build a ops_by_temp hash that group operations by T Anneal
    ops_by_temp = {
        "70" => operations.select { |op| op.temporary[:tanneal] >= 70 },
        "67" => operations.select { |op| op.temporary[:tanneal] >= 67 && op.temporary[:tanneal] < 70 },
        "64" => operations.select { |op| op.temporary[:tanneal] < 67 }
    }.delete_if { |t, ops| ops.empty? }

    # produce stripwells
    ops_by_temp.each do |t, ops|
        ops.make only: ["Lysate"]
        
        ops.output_collections["Lysate"].each do |sw|
            # calling 'associate' from DataAssociator, not Collection
            Item.instance_method(:associate).bind(sw).call(:tanneal, t.to_i)
        end
    end

    show do
        title "Prepare Stripwell Tubes"
        ops_by_temp.each do |temp, ops|
            sw = ops.first.output("Lysate").collection
            if sw.num_samples <= 6
                check "Grab a new stripwell with 6 wells and label with the id #{sw}."
            else
                check "Grab a new stripwell with 12 wells and label with the id #{sw}."
            end
            note "Pipette 25 µL of 20 mM NaOH into wells " + sw.non_empty_string + "."
            warning "Using 25 µL NaOH, not 30 µL SDS.  "
        end
    end

    # add colonies to stripwells
    ops_by_temp.each do |t, ops|
        show do
            sw = ops.first.output("Lysate").collection
            title "Load Stripwell #{sw.id}"
            
            table ops.start_table
                .custom_column(heading: "Location") { |op| op.output("Lysate").column + 1 }
                .custom_column(heading: "Colony cx from plate, 1/3 size", checkable: true) { |op| "#{op.temporary[:yeast_plate].id}.c#{op.temporary[:colony]}" }
            .end_table
            
            note "For each plate id.cx (x = 1,2,3,...), if a colony cx is not marked on the plate, mark it with a circle and write done cx (x = 1,2,3,...) nearby. If a colony cx is alread marked on the plate, scrape that colony."
            note "Use a sterile 10 µL tip to scrape about 1/3 of the marked colony, swirl tip inside the well until mixed."
        end
    end

    # Run the thermocycler
    thermocycler = show do
        title "Start the lysate reactions"
        
        check "Put the cap on each stripwell #{ops_by_temp.map { |t, ops| ops.first.output("Lysate").collection.id }}. Press each one very hard to make sure it is sealed."
        check "Vortex all the stripwells on a green tube holder on a vortexer."
        check "Place the stripwells into an available thermal cycler and close the lid."
        
        get "text", var: "name", label: "Enter the name of the thermocycler used", default: "TC1"
        
        check "Click 'Home' then click 'Saved Protocol'. Choose 'YY' and then 'LYSATE'."
        check "Press 'run' and select 25 µL."
    end

    operations.store io: "input", interactive: true

    show do
        title "Wait for 10 minutes"
        
        timer initial: { hours: 0, minutes: 10, seconds: 0}
    end

    operations.retrieve io: "output", interactive: true

    show do
        title "Retrieve and keep stripwells"
        
        check "Retrieve stripwells from #{thermocycler[:name]}"
        check "Keep the new stripwell on the bench for the next protocol to use."
        warning "DO NOT SPIN DOWN STRIPWELLS."
    end

    # Set the location of the stripwells to be the name of the thermocycler
    ops_by_temp.each do |t, ops| 
        ops.first.output("Lysate").collection.move "Bench"
    end
    
    operations.store io: "output", interactive: false
    
    release operations.map { |op| op.temporary[:yeast_plate] }.uniq, interactive: true

    return {}
    
  end

end
