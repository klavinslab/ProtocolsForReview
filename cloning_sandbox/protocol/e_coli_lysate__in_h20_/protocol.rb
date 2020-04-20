needs "Yeast/StripwellMethods"
class Protocol
	include StripwellMethods

	def main
		
		operations.retrieve
        
        if debug
        operations.each do |op|
            plate = Item.where(object_type_id: ObjectType.find_by_name("Checked E coli Plate of Plasmid").id).sample
            op.plan.associate :checked_e_coli_plate_of_plasmid, plate.id
            plate.associate :QC_result, ["No", "Yes", "Yes"] if [0, 1].sample == 0
        end
    end


        operations.each do |op|
        op.pass("Plate", "Plate")
        plate = op.input("Plate").item
        op.plan.associate :plate, plate.id
        legacy_qc_num = (plate.get(:QC_result) || []).length
        plate.associate :num_qc_colonies, legacy_qc_num if plate.get(:num_qc_colonies).nil? 
        plate.associate :num_qc_colonies, plate.get(:num_colonies).to_i + 1 if plate.created_at < Time.utc(2018, "jan", 11, 19, 15)
 
         new_num_qc_col = plate.get(:num_qc_colonies) + 1 
         op.associate :colony_picked, new_num_qc_col
         op.temporary[:colony] = new_num_qc_col
         plate.associate :num_qc_colonies, new_num_qc_col
         
        
         if !plate.sample.properties["QC Primer1"]
            fwd = Sample.find_by_id(5606).properties["QC Primer1"]
            rev = Sample.find_by_id(5606).properties["QC Primer2"]
        else
            fwd = samples.collect { |y| y.properties["QC Primer1"] }
            rev = samples.collect { |y| y.properties["QC Primer2"] }
        end
        op.temporary[:tanneal] = (fwd.properties["T Anneal"] + rev.properties["T Anneal"])/2
          
     end
         
         ops_by_temp = {
             "70" => operations.select { |op| op.temporary[:tanneal] >= 70 },
             "67" => operations.select { |op| op.temporary[:tanneal] >= 67 && op.temporary[:tanneal] < 70 },
             "64" => operations.select { |op| op.temporary[:tanneal] < 67 }
          }.delete_if { |t, ops| ops.empty? }
          
        sw = []

            ops_by_temp.each do |t, ops|
            ops.make only: ["Lysate"]
            sw.push ops.output_collections["Lysate"]
            sw.flatten!
            ops.output_collections["Lysate"].each do |sw|
                # calling 'associate' from DataAssociator, not Collection
                Item.instance_method(:associate).bind(sw).call(:tanneal, t.to_i)
         end
        end
        
             prepare_stripwell sw, 15, "H20"
        
             ops_by_temp.each do |t, ops|
              show do
              sw =   ops.first.output("Lysate").collection
             title "Load Stripwell #{sw.id}"                         
            
             table ops.start_table
                .custom_column(heading: "Location") { |op| op.output("Lysate").column + 1 }
                .custom_column(heading: "Colony cx from plate, 1/3 size", checkable: true) { |op| "#{op.input("Plate").item.id}.c#{op.temporary[:colony]}" }
             .end_table
            
             note "For each plate id.cx (x = 1,2,3,...), if a colony cx is not marked on the plate, mark it with a circle and write done cx (x = 1,2,3,...) nearby. If a colony cx is alread marked on the plate, scrape that colony."
             note "Use a sterile 10 L tip to scrape about 1/3 of the marked colony, swirl tip inside the well until mixed."
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
                check "Press 'run' and select 25 uL."
            end

            operations.store io: "input", interactive: true

             show do
                title "Wait for 10 minutes"
        
                timer initial: { hours: 0, minutes: 10, seconds: 0}
             end


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

    return {}
    
  end

end