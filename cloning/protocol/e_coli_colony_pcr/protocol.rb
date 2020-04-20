#this protocol will walk the technician through the steps needed to perform an E Coli Colony PCR.

needs "Cloning Libs/Cloning"
needs "Standard Libs/Feedback"

class Protocol
    
    include Cloning, Feedback

    
    def main
    #displays directions to retrieve following items.
    operations.retrieve only: ["Template"]
    operations.retrieve only: ["QC Primer1", "QC Primer2"]
    
    #insert kapa as an input and ask technician to take from its place
    kapa =  find(:sample, name: "Kapa HF Master Mix")[0].in("Enzyme Stock")[0]
    take [kapa], interactive: true

    
    #creates inventory item for PCR.
    operations.make only: ["PCR"]
    
    #check the volumes of input primers for all operations, and ensure they are sufficient.
    operations.each { |op| op.temporary[:primer_vol] = 0.5 }
    check_volumes ["QC Primer1", "QC Primer2"], :primer_vol, :make_aliquots_from_stock, check_contam: true
    
     #figure out if using a plasmid or a fragment.
     f_or_p = operations.first.input("Template").sample_type.id == SampleType.where(name: "Fragment").first.id || operations.first.input("Template").item.object_type_id == SampleType.where(name: "Plasmid").first.id
     
     vol=3.5
     
     
     stripwell_tab = [["Stripwell", "Wells to pipette"]] +
            operations.output_collections["PCR"].map { |sw| ["#{sw} (#{sw.num_samples <= 6 ? 6 : 12} wells)", { content: sw.non_empty_string, check: true }] }
        
        #ask tech to label and prepare stripwells.
        show do
            title "Label and prepare stripwells"
            warning "Label stripwells, and pipette #{vol} L of molecular grade water into each based on the following table:"
            table stripwell_tab
        end
      
      vol=0.5
        
    
    operations.output_collections["PCR"].each do |sw|
            ops = operations.select { |op| op.output("PCR").collection == sw }
     
     #ask tech to load templates.
     show do
                title "Load templates for stripwell #{sw.id}"
                note "Spin down stripwell immediately before transferring template."
                table ops.start_table
                    .custom_column(heading: "Well Number") { |op| op.output("PCR").column + 1 }
                    .input_item("Template", heading: "Template (#{vol} L)", checkable: true)
                .end_table
                
              warning "Use a fresh pipette tip for each transfer.".upcase
            end     
     end
       
       vol=5
        
        operations.output_collections["PCR"].each do |sw|
            ops = operations.select { |op| op.output("PCR").collection == sw }
            
            #ask tech to load primers.
            show do
                title "Load primers for stripwell #{sw.id}" 
                table ops.start_table
                    .custom_column(heading: "Well Number") { |op| op.output("PCR").column + 1 }
                    .custom_column(heading: "Forward Primer, 0.5 L", checkable: true) { |op| 
                        op.input("QC Primer1").item.id }
                    .custom_column(heading: "Reverse Primer, 0.5 L", checkable: true) { |op|
                        op.input("QC Primer2").item.id }
                    .end_table
                warning "Use a fresh pipette tip for each transfer.".upcase
            end
        end
        
   #ask tech to pipette kapa into stripwell.
    show do
            title "Pipette #{vol} L of master mix into stripwells based on the following table:"
            note "Pipette #{vol} uL of master mix (item #{kapa}) into each well according to the following table:"
            table stripwell_tab
            warning "Use a new pipette tip for each well and pipette up and down to mix.".upcase
            check "Cap each stripwell. Press each one very hard to make sure it is sealed."
    end
     
     annealing_temps = operations.map do |op|
            [op.input("QC Primer1").val.properties["T Anneal"], op.input("QC Primer2").val.properties["T Anneal"]]
        end.flatten
        pcr_temp = annealing_temps.min
        extension_time = "3 minutes"

        if f_or_p
            template_lengths = operations.map { |op| op.input("Template").child_sample.properties["Length"] }
            max_length = template_lengths.max
            extension_seconds = [max_length / 1000.0 * 30.0, 180].max
            extension_time = Time.at(extension_seconds).utc.strftime("%M:%S") 
        end

        #displays directions to run thermocycler.
        thermocycler = show do
            title "Start PCR at #{pcr_temp} C"
            check "Place the stripwell into an available thermal cycler and close the lid."
            get "text", label: "Enter the name of the thermocycler used", val: "name", default: "TC1"
            check "Click 'Home' then click 'Saved Protocol'. Choose 'YY' and then 'COLONYPCR'."
            check "Set the anneal temperature to #{pcr_temp} C. This is the 3rd temperature."
            check "Set the extension time (4th time) to #{extension_time}." 
        end
        
        #mark stripwell's location as "deleted."
        lysate_stripwells = operations.map { |op| op.input("Template").item }.uniq
        lysate_stripwells.each do |sw|
            sw.mark_as_deleted 
            sw.save 
        end
        
        #ask tech to clean up.
        show do
            title "Clean up"
            note "Discard the following stripwells"
            note lysate_stripwells.map { |sw| sw.id }.to_s 
        end
        
        operations.store io: "input", interactive: true, method: "boxes" 
        operations.store io: "output", interactive: false
        release [kapa], interactive: true
        
        get_protocol_feedback
        return {}
    end
end
    