# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main
   
    operations.make
    
            show do
                title "Retrieve Transformed aliquots"
                note "Retrieve tubes labelled #{operations.collect { |op| "#{op.input("Transformation").item.id}"}.join(",")} tubes from the sytrofoam holder in the 30C shaker"
            end
            
            show do 
                title "Retrieve plates from incubator"
                note "Retrieve #{operations.length} plates from the 30C incubator"
            end
           
            show do
                title "Label plates"
                note "Label plates with your initials, today's date and Item IDs, according to the list"
                table operations.start_table
                .custom_column(heading: "Plate type"){|op| op.output("Plate").sample.properties["Agro Selection"]} 
                .output_item("Plate", heading: "ID", checkable: true)
                .custom_column(heading: "Initial + date", checkable: true){" Initial + #{Date.today.month}/#{Date.today.day}"}
                .end_table
            end
             
            show do 
                title "Plate transformed Agro aliquots"
                check "Use sterile beads to plate THE ENTIRE VOLUME (300 uL) from the transformed aliquots (1.5 mL tubes) onto the plates, following the table below."
                check "Discard used transformed aliquots after plating."
                table operations.start_table
                .input_item("Transformation", heading: "Tube ID")
                .output_item("Plate", heading: "Plate ID", checkable: true)
                .end_table
            end
            
            show do
                title "Finish up"
                check "Plates in 30C incubator"
                check "Clear workspace and wipe with 70% ethanol"
            end
            
            operations.each do |op|
                op.output("Plate").item.location = "30 C incubator"
                op.output("Plate").item.save
                op.input("Transformation").item.mark_as_deleted
                op.input("Transformation").item.save
            end
    
  end

end