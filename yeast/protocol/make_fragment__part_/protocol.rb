needs "Standard Libs/Feedback"
class Protocol
  # This protocol is not finished and not being used. 
  include Feedback
  def main
        
    operations.retrieve.make
    kapa =  find(:sample, name: "Kapa HF Master Mix")[0].in("Enzyme Stock")[0]
    
    # Verify enough volume of each primer aliquot
    verify_primer_volume

    # Find primer replacements
    replacements = find_primer_replacements

    replacements.merge!(get_replacements replacements) if !replacements.empty?
    
    # Label and prepare stripwells
    label_prepare_stripwells

    # Load templates
    load_templates

    # Load primers
    load_primers replacements

    # Pipette master mix into stripwells
    pipette_master_mix kapa

    annealing_temps = operations.map do |op|
        [op.input("Forward Primer").val.properties["T Anneal"], op.input("Reverse Primer").val.properties["T Anneal"]]
    end.flatten
    pcr_temp = annealing_temps.min
    
    template_lengths = operations.map { |op| op.input("Template").child_sample.properties["QC_length"] }.compact

    max_length = template_lengths.max

    # Don't do the rest if template_lengths = 0?
    if(template_lengths.length > 0)
      extension_seconds = [max_length / 1000.0 * 30.0, 180].max
      extension_time = Time.at(extension_seconds).utc.strftime("%M:%S") 
      
      start_pcr pcr_temp, extension_time
    end
    
    operations.store
    get_protocol_feedback
    return {}
  end
  
  # This method instructs the technician to make aliquots. 
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
    
  # This method iterates through a group of primers and finds replacements for each primer.
  # It updates the primer group with the newly found primer. If no replacement primer is found,
  # then an error is thrown for that operation.
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
    
  # This method prompts the technician to verify if enough volume of each primer aliquot is present.
  def verify_primer_volume
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
  end
    
    def find_primer_replacements
      replacements = {}
      
      operations.each do |op|
        if op.temporary[:fwd_enough_vol] == "n" 
          replacements["#{op.input("Forward Primer").item.id}"]
        end
        
        if op.temporary[:rev_enough_vol] == "n"
          replacements["#{op.input("Reverse Primer").item.id}"]
        end
      end
      
      show do
        note "#{replacements}"
      end
      replacements
    end
    
    def label_prepare_stripwells
      show do 
        title "Label and prepare stripwells"
        note "Label stripwells and pipette 3.5 uL of molecular grade water into each based on the following table:"
        table operations.start_table
          .output_collection("Fragment")
          .output_column("Fragment", heading: "Well Number", checkable: true)
        .end_table
      end
    end
    
    def load_templates
      show do
        title "Load templates"
        table operations.start_table
          .input_collection("Template", heading: "Template (0.5 uL)")
          .input_column("Template", heading: "Well Number", checkable: true)
          .output_collection("Fragment")
          .output_column("Fragment", heading: "Well")
        .end_table
          
        warning "Use a fresh pipette tip for each transfer.".upcase
      end
    end
    
    def load_primers replacements
      show do
        title "Load primers"
        table operations.start_table
          .output_collection("Fragment")
          .output_column("Fragment", heading: "Well")
          .custom_column(heading: "Forward Primer") { |op| 
            replacements.keys.include?(op.input("Forward Primer").item.id) ? "#{op.input("Forward Primer").item.id} or #{replacements[op.input("Forward Primer").item.id]}" : "#{op.input("Forward Primer").item.id}" }
          .custom_column(heading: "Reverse Primer") { |op|
            replacements.keys.include?(op.input("Reverse Primer").item.id) ? "#{op.input("Reverse Primer").item.id} or #{replacements[op.input("Reverse Primer").item.id]}" : "#{op.input("Reverse Primer").item.id}" 
          }
          .end_table
        warning "Please use a fresh pipette tip for each transfer.".upcase
      end
    end
    
    def pipette_master_mix kapa
      show do
        title "Pipette 25 L of master mix into stripwells based on the following table:"
        note "Pipette 25 uL of master mix (item #{kapa}) into each well according to the following table:"
        table operations.start_table
          .output_collection("Fragment")
          .output_column("Fragment", heading: "Well to pipette", checkable: true)
        .end_table
        warning "Plase use a new pipette tip for each well and pipette up and down to mix.".upcase
        check "Cap each stripwell. Press each one very hard to make sure it is sealed."
      end
    end
    
    def start_pcr pcr_temp, extension_time
      show do
        title "Start PCR at #{pcr_temp} C"
        check "Place the stripwell into an available thermal cycler and close the lid."
        check "Click 'Home' then click 'Saved Protocol'. Choose 'YY' and then 'COLONYPCR'."
        check "Set the anneal temperature to #{pcr_temp} C. This is the 3rd temperature."
        check "Set the extension time (4th time) to #{extension_time}."
      end
    end
end