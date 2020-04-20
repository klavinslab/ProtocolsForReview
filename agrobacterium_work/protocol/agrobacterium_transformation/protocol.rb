# Copied from E.coli transformation by Author: Ayesha Saleem, and edited by Orlando de Lange
# 14th June 2017
needs "Standard Libs/Debug"

class Protocol
    include Debug
  def main

    # Take Gibson result or plasmid and E coli comp cells and create output Transformed E Coli aliquots
    operations.make
    operations.retrieve only: ["Plasmid"]

    selections = operations.map { |op| op.output("Transformed").sample.properties["Agro Selection"] }
    gent = selections.count "Gentamycin"
    amp = selections.count "Ampicillin"
    kan = selections.count "Kanamycin"
    spec = selections.count "Spectinomycin"
    

    
        show do 
            title "Get cold items"
            note "Retrieve a styrofoam ice block (Small Freezer, storage room) and an aluminum tube rack (Media fridge). Put the aluminum tube rack on top of the ice block."
            check "Retrieve #{operations.length} cuvettes (M20, bottom shelf, orange lids) and put inside the styrofoam touching ice block."
        end
        
        show do
            title "Retrive comp cells"
            operations.each do |op|
                check "Take one competent cell aliquot from box #{op.input("Batch").collection.id}, located at #{op.input("Batch").collection.location} and place on aluminum block"
            end
        end
    
        show do
            title "Add plasmid to comp cell aliquot and incubate for 5 minutes "
            check "Pipette 2 uL plasmid into labeled electrocompetent aliquot, swirl the tip to mix and place back on the aluminum rack after mixing."
            table operations.start_table 
                .input_item("Plasmid", heading: "2 µl of Plasmid")
                .input_sample("Batch", heading: "Comp cell tube label", checkable: true)
                .end_table
        end
        
        show do 
            title "Incubate for 5 minutes"
            timer initial: { hours: 0, minutes: 5, seconds: 00}
        end
        
        show do
            title "Label and fill cuvettes"
             note "Label cuvettes (last 3 digits of each agro strain sample number):"
             operations.each  do |op|
                check "#{op.output("Transformed").sample.id.to_s.last(3)}"
            end
             check "Transfer full 50 l from each comp cell aliquot tube to the correspondingly numbered cuvette"
        end
        
        show do
            title "Electroporate and rescue"
            note "If the electroporator is off (no numbers displayed), turn it on using the ON/STDBY button."
            note "Set the voltage to 1250V by clicking up and down button."
            note " Click the time constant button to show 0.0."
            note "Electroporate by hitting pulse twice"
            check "Slide cuvette into electroporator, press PULSE button twice, and retrieve to place back with the ice block"
            operations.each  do |op|
                check "#{op.output("Transformed").sample.id.to_s.last(3)}"
            end
        end
        
        show do
            title "Transfer transformation products into incubation tubes"
            check "Retrieve and label #{operations.length} 1.5 mL tubes with the following ids: #{operations.collect { |op| "#{op.output("Transformed").item.id}"}.join(",")} "
            check "Retrieve a small bottle of YEB liquid medium from the yellow box labelled 'Orlando' "
            check "For each cuvette: add 300 l YEB, pipette up and down and transfer 300l into labelled 1.5 ml tube"
            table operations.start_table
                .custom_column(heading: "Cuvette"){ |op| op.output("Transformed").sample.id.to_s.last(3)}
                .output_item("Transformed")
                .end_table
        end
        
        operations.each do |op|
            op.output("Transformed").item.location = "30 C shaker incubator"
            op.output("Transformed").item.save
        end

        show do 
            title "Incubate tubes"
            check "Ensure all lids are properly closed"
            check "Put the transformed Agro aliquots into <b>30C</b> shaker, in a secured styrofoam rack"
            note "Retrieve all the tubes 2 hours later by doing the Plate Agro Transformations protocol. You can finish this protocol now by perfoming the next return steps."
            note"<a href='https://www.google.com/search?q=google+timer+2+hours&oq=google+timer+2+hrs&aqs=chrome.1.69i57j0j69i64.6215j0j7&sourceid=chrome&ie=UTF-8' target='_blank'>
                Set a 2 hr timer on Google</a> to set a reminder to start the Plate Agro Transformations protocol."
        end
        plate_batches = Collection.where(object_type_id: ObjectType.find_by_name("Agar Plate Batch").id)
        gent_plates = plate_batches.find {|batch| batch.matrix.flatten.include? Sample.find_by_name("YEB Gent").id}
        kan_plates = plate_batches.find {|batch| batch.matrix.flatten.include? Sample.find_by_name("YEB Gent + Kan").id}
        spec_plates = plate_batches.find {|batch| batch.matrix.flatten.include? Sample.find_by_name("YEB Gent + Spec").id}
        
         show do
            title "Plates in the incubator"
            operations.each do |op|
                if op.output("Transformed").sample.properties["Agro Selection"] == "Gent" && (gent_plates.nil? == false)
                     check "Take #{gent} plates from #{gent_plates.id} located in #{gent_plates.location}"
                elsif op.output("Transformed").sample.properties["Agro Selection"] == "Kanamycin" && (kan_plates.nil? == false)
                    check "Take #{kan} plates from #{kan_plates.id} located in #{kan_plates.location}"
                elsif op.output("Transformed").sample.properties["Agro Selection"] == "Spectinomycin" && (spec_plates.nil? == false)
                    check "Take #{spec} plates from #{spec_plates.id} located in #{spec_plates.location}"
                else check "You need to make a YEB Rif #{op.output("Transformed").sample.properties["Agro Selection"]} plate"
                end
            end
            check "Place plates into the 30C incubator"
        end
        
        if gent_plates.nil? == false then gent.times{gent_plates.subtract_one} end
        if kan_plates.nil? == false then kan.times{kan_plates.subtract_one} end
        if spec_plates.nil? == false then  spec.times{spec_plates.subtract_one} end

        show do
            title "Clean up"
            check "Discard cuvettes into the biohazard waste"
            check "Discard empty electrocompetent aliquot tubes the biohazard waste."
            check "Return the styrofoam ice block and the aluminum tube rack."
        end
        
   operations.each { |op| op.input("Plasmid").item.store }
    
  end
  
end 