needs "Cloning Libs/Cloning"

class Protocol
    
    include Cloning
    
    def make_aliquots(primers)
        take primers.keys
        
        show do 
            title "Pipette Water into Tubes"
            note "Gather #{primers.length} 1.5 mL tubes and label with the following ids : #{primers.values}"
            note "Pipette 90 uL of molecular grade water into each tube"
        end
        
        show do 
            title "Aliquot Primers from Primer Stock"
            note "Pipette 10 uL of each primer stock into the corresponding tube, according to the table below:"
            table [["Primer Stock", "Primer Aliquot"], [primers.keys, primers.values]]
        end
        
        release primers.keys, interactive: true
    end
    
    def main
        operations.retrieve only: ["QC Primer1", "QC Primer2"]
        kapa =  find(:sample, name: "Kapa HF Master Mix")[0].in("Enzyme Stock")[0]
        take [kapa], interactive: true
        operations.retrieve only: ["Template"]
        
        operations.make only: ["PCR"]
        
        y = operations.first.output("PCR").item.object_type_id == ObjectType.where(name: "Yeast Strain")
    
        # Check the volumes of input primers for all operations, and ensure they are sufficient
        operations.each { |op| op.temporary[:primer_vol] = 0.5 }
        check_volumes ["QC Primer1", "QC Primer2"], :primer_vol, :make_aliquots_from_stock, check_contam: true
        
        f_or_p = operations.first.input("Template").sample_type.id == SampleType.where(name: "Fragment").first.id || operations.first.input("Template").item.object_type_id == SampleType.where(name: "Plasmid").first.id
        y = operations.first.input("Template").sample_type.id == SampleType.where(name: "Yeast Strain").first.id
        
        y ? vol = 3.5 : vol = 19
        
        stripwell_tab = [["Stripwell", "Wells to pipette"]] +
            operations.output_collections["PCR"].map { |sw| ["#{sw} (#{sw.num_samples <= 6 ? 6 : 12} wells)", { content: sw.non_empty_string, check: true }] }
        show do
            title "Label and prepare stripwells"
            note "Label stripwells, and pipette #{vol} µL of molecular grade water into each based on the following table:"
            table stripwell_tab
        end
          
        y ? vol = 0.5 : vol = 1

        operations.output_collections["PCR"].each do |sw|
            ops = operations.select { |op| op.output("PCR").collection == sw }
            
            show do
                title "Load templates for stripwell #{sw.id}"
                note "Transfer 0.5 µL from each template stripwell to the new stripwell #{sw.id}"
                warning "Spin down stripwells immediately before transferring template."
                table ops.start_table
                    .input_item("Template", heading: "Template (#{vol} µL)")
                    .custom_column(heading: "Source Well") { |op| op.input("Template").column + 1 }
                    .custom_column(heading: "Dest. Well", checkable: true) { |op| op.output("PCR").column + 1 }
                .end_table
                
              warning "Use a fresh pipette tip for each transfer.".upcase
            end     
        end
        
        operations.output_collections["PCR"].each do |sw|
            ops = operations.select { |op| op.output("PCR").collection == sw }
            
            show do
                title "Load primers for stripwell #{sw.id}"
                table ops.start_table
                    .custom_column(heading: "Well Number") { |op| op.output("PCR").column + 1 }
                    .custom_column(heading: "Forward Primer, 0.5 µL", checkable: true) { |op| 
                        "#{op.input("QC Primer1").item.id}" }
                    .custom_column(heading: "Reverse Primer, 0.5 µL", checkable: true) { |op|
                        "#{op.input("QC Primer2").item.id}" }
                    .end_table
                warning "Please use a fresh pipette tip for each transfer.".upcase
            end
        end

        y ? vol = 5 : vol = 25
        
        show do
            title "Pipette #{vol} µL of master mix into stripwells based on the following table:"
            
            note "Pipette #{vol} uL of master mix (item #{kapa}) into each well according to the following table:"
            
            operations.group_by { |op| op.output("PCR").collection }.each do |sw, ops|
                ops.extend(OperationList)
                table ops.start_table
                    .custom_column(heading: "Stripwell #{sw.id} Well", checkable: true) { |op| op.output("PCR").column + 1 }
                .end_table
            end
            
            warning "Plase use a new pipette tip for each well and pipette up and down to mix.".upcase
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

        thermocycler = show do
            title "Start PCR at #{pcr_temp} C"
            check "Place the stripwell into an available thermal cycler and close the lid."
            get "text", label: "Enter the name of the thermocycler used", val: "name", default: "TC1"
            check "Click 'Home' then click 'Saved Protocol'. Choose 'YY' and then 'CLONEPCR'." if f_or_p
            check "Click 'Home' then click 'Saved Protocol'. Choose 'YY' and then 'COLONYPCR'." if y
            check "Set the anneal temperature to #{pcr_temp} C. This is the 3rd temperature."
            check "Set the extension time (4th time) to #{extension_time}." 
        end
        
        lysate_stripwells = operations.map { |op| op.input("Template").item }.uniq
        lysate_stripwells.each do |sw|
            sw.mark_as_deleted
            sw.save
        end
        show do
            title "Clean up"
            note "Discard the following stripwells"
            note lysate_stripwells.map { |sw| sw.id }.to_s
        end
        
        operations.store io: "input", interactive: true, method: "boxes"
        operations.store io: "output", interactive: false
        release [kapa], interactive: true
        
        return {}
    end
end