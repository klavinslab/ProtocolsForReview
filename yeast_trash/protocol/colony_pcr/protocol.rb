class Protocol
    
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
    
    
    def get_replacements(primers)
        to_aliquot = {}
        
        primers.keys.each do |k|
            p = Item.find_by_id(k)
            p.mark_as_deleted
            replacement_p = Item.where(sample_id: p.sample_id, object_type_id: p.object_type_id).reject! { |p| p.location == "deleted" }[0]
            replacement_s = Item.where(sample_id: p.sample_id, object_type_id: ObjectType.find_by_name("Primer Stock").id).reject! { |p| p.location == "deleted" }[0]
            
            if replacement_p
                primers[k] = replacement_p
            elsif replacement_s
                primers[k] = produce new_sample "#{Sample.find_by_id(p.sample_id)}", of: "Primer", as: "Primer Aliquot"
                to_aliquot[replacement_s] = primers[k]
            else
                ops_error = operations.collect { |op| op.input("Forward Primer") == p || op.input("Reverse Primer") == p }
                ops_error.each { |op| op.error :no_primer, "There seems to be a missing forward or reverse primer." }
            end
        end
        
        make_aliquots to_aliquot
        
        primers
    end
    
    def main
        
        operations.retrieve.make only: ["PCR"]
        
        kapa =  find(:sample, name: "Kapa HF Master Mix")[0].in("Enzyme Stock")[0]
        take [kapa], interactive: true
        y = operations.first.output("PCR").item.object_type_id == ObjectType.where(name: "Yeast Strain")
    
        show do
          title "Verify enough volume of each primer aliquot is present, or note if contamination is present"
            table operations.start_table
                .input_item("Forward Primer")
                .get(:fwd_enough_vol, type: "string", default: "y", heading: "Enough? (y/n)")
            .end_table
          
            table operations.start_table
                .input_item("Reverse Primer")
                .get(:rev_enough_vol, type: "string", default: "y", heading: "Enough? (y/n)")
            .end_table
        end
        
        replacements = {}
        
        operations.each do |op|
            if op.temporary[:fwd_enough_vol] == "n" 
                replacements["#{op.input("Forward Primer").item.id}"]
            end
            
            if op.temporary[:rev_enough_vol] == "n"
                replacements["#{op.input("Reverse Primer").item.id}"]
            end
        end
         
        replacements.merge!(get_replacements replacements) if !replacements.empty?
        
        f_or_p = operations.first.input("Template").sample_type.id == SampleType.where(name: "Fragment").first.id || operations.first.input("Template").item.object_type_id == SampleType.where(name: "Plasmid").first.id
        y = operations.first.input("Template").sample_type.id == SampleType.where(name: "Yeast Strain").first.id
        
        y ? vol = 3.5 : vol = 19
        
        stripwell_tab = [["Stripwell", "Wells to pipette"]] +
            operations.output_collections["PCR"].map { |sw| ["#{sw} (#{sw.num_samples <= 6 ? 6 : 12} wells)", { content: sw.non_empty_string, check: true }] }
        show do
            title "Label and prepare stripwells"
            note "Label stripwells, and pipette #{vol} L of molecular grade water into each based on the following table:"
            table stripwell_tab
        end
          
        y ? vol = 0.5 : vol = 1

        operations.output_collections["PCR"].each do |sw|
            ops = operations.select { |op| op.output("PCR").collection == sw }
            
            show do
                title "Load templates for stripwell #{sw.id}"
                table ops.start_table
                    .custom_column(heading: "Well Number") { |op| op.output("PCR").column + 1 }
                    .input_item("Template", heading: "Template (#{vol} L)", checkable: true)
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
                    .custom_column(heading: "Forward Primer, 0.5 L", checkable: true) { |op| 
                        replacements.keys.include?(op.input("Forward Primer").item.id) ? "#{op.input("Forward Primer").item.id} or #{replacements[op.input("Forward Primer").item.id]}" : "#{op.input("Forward Primer").item.id}" }
                    .custom_column(heading: "Reverse Primer, 0.5 L", checkable: true) { |op|
                        replacements.keys.include?(op.input("Reverse Primer").item.id) ? "#{op.input("Reverse Primer").item.id} or #{replacements[op.input("Reverse Primer").item.id]}" : "#{op.input("Reverse Primer").item.id}" 
                    }
                    .end_table
                warning "Please use a fresh pipette tip for each transfer.".upcase
            end
        end

        y ? vol = 5 : vol = 25
        
        show do
            title "Pipette #{vol} L of master mix into stripwells based on the following table:"
            note "Pipette #{vol} uL of master mix (item #{kapa}) into each well according to the following table:"
            table stripwell_tab
            warning "Plase use a new pipette tip for each well and pipette up and down to mix.".upcase
            check "Cap each stripwell. Press each one very hard to make sure it is sealed."
        end
        
        annealing_temps = operations.map do |op|
            [op.input("Forward Primer").val.properties["T Anneal"], op.input("Reverse Primer").val.properties["T Anneal"]]
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