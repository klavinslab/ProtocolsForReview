needs "Cloning Libs/Cloning"
needs "Standard Libs/SortHelper"
needs "Standard Libs/AssociationManagement"
needs "Standard Libs/Feedback"
class Protocol
    
  include Cloning, SortHelper, AssociationManagement, Feedback
  
  def main
    
    # ensure that the job contains either all yeast, or all frag/plas. Mixed jobs are not possible with this protocol
    ensure_not_mixed

    # instruct tech to find inputs      
    operations.retrieve
    
    # Sort Operations by template collection id, then by column index so that output parts are generated with nicely parallel columns to the inputs
    temp = sortByMultipleIO(operations, ["in", "in"], ["Template", "Template"], ["id", "column"], ["collection", "io"])
    operations = temp
    
    # generate outputs
    operations.make
    
    # instruct tech to retrieve kapa master mix
    kapa =  find(:sample, name: "Kapa HF Master Mix")[0].in("Enzyme Stock")[0]
    take [kapa], interactive: true

    # check the volumes of input primers for all operations, and ensure they are sufficient
    check_primer_volume
     
    # `y` is true if the inputs are all yeast strains, false if the inputs are all plasmids or fragments.
    #  reagent volumes and extension time depend on whether the job being run is all yeast or all plas/frags.
    y = operations.first.input("Template").sample_type.id == SampleType.where(name: "Yeast Strain").first.id

    stripwell_tab = build_stripwell_table

    water_vol = y ? 3.5 : 19
    # instruct tech to label and add water to stripwells
    prepare_stripwells water_vol, stripwell_tab
      
    template_vol = y ? 0.5 : 1
    # instruct tech to add templates and primers to stripwells
    load_template_and_primers template_vol
    
    mix_vol = y ? 5 : 25
    # instruct tech to add the master mix to stripwells
    load_master_mix mix_vol, kapa, stripwell_tab
    
    # calculate the optimal temperature for pcr
    pcr_temp = calculate_pcr_temp
    
    # returns extension time - different for yeast jobs than for fragments/plasmid jobs
    extension_time = calculate_extension_time y

    # instruct tech to put stripwells into thermocycler, and record which cycler was used as new location for the stripwells
    start_pcr pcr_temp, extension_time, y
    
    # discard lysate stripwells
    clean_up
    
    # associate which colony was picked and from which plate it was picked
    # to the output part, so that fragment analyzing can know which colony it is qcing
    pass_down_colony_pick
    
    # store all ingredients and outputs
    release [kapa], interactive: true
    operations.store io: "input", interactive: true
    get_protocol_feedback
    return {}
  end
  
  # This method checks to see if the jobs are not mixed. 
  def ensure_not_mixed
    operations.retrieve interactive: false
    if operations.map { |op| op.input("Template").sample_type.id == SampleType.where(name: "Yeast Strain").first.id }.uniq.size > 1
      operations.store interactive: false
      raise "Mixed jobs are not possible. Reschedule with either all Yeast Strains, or all Fragment and Plasmids." 
    end
  end
  
  # This method checks if the qc primers have enough volume.
  def check_primer_volume
    operations.each { |op| op.temporary[:primer_vol] = 0.5 }
    # the interface for this method is complicated. For more information look in `Cloning Libs/Cloning`
    check_volumes ["QC Primer1", "QC Primer2"], :primer_vol, :make_aliquots_from_stock, check_contam: true
  end
  
  # This method builds a stripwell table.
  def build_stripwell_table
    [["Stripwell", "Wells to pipette"]] + operations.output_collections["PCR"].map { |sw| ["#{sw} (#{sw.num_samples <= 6 ? 6 : 12} wells)", { content: sw.non_empty_string, check: true }] } # return
  end
  
  # This method tells the technician to label and prepare stripwells.
  def prepare_stripwells vol, stripwell_tab
    show do
      title "Label and prepare stripwells"
      check "Based on the following table, make new stripwells of the correct size and label them"
      check "Pipette #{vol} uL of molecular grade water into each well of each stripwell"
      table stripwell_tab
    end
  end
  
  # This method tells the technician to load templates and primes for stripwells.
  def load_template_and_primers vol
    operations.output_collections["PCR"].each do |sw|
      ops = operations.select { |op| op.output("PCR").collection == sw }
      show do
        title "Load templates for stripwell #{sw.id}"
        check "Spin down stripwell immediately before transferring template."
        table ops.start_table
          .input_item("Template", heading: "Template (#{vol} uL)", checkable: true)
          .custom_column(heading: "Template Well") { |op| op.input("Template").column + 1 }
          .custom_column(heading: "Target Well (#{sw.id})") { |op| op.output("PCR").column + 1 }
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
          .custom_column(heading: "Forward Primer, 0.5 uL", checkable: true) { |op| 
              op.input("QC Primer1").item.id }
          .custom_column(heading: "Reverse Primer, 0.5 uL", checkable: true) { |op|
              op.input("QC Primer2").item.id }
          .end_table
        warning "Please use a fresh pipette tip for each transfer.".upcase
      end
    end
  end
  
  # This method tells the technician to load master mix into stripwells based on a volume table.
  def load_master_mix vol, kapa, stripwell_tab
    show do
      title "Pipette #{vol} uL of master mix into stripwells based on the following table:"
      note "Pipette #{vol} uL of master mix (item #{kapa}) into each well according to the following table:"
      table stripwell_tab
      warning "Plase use a new pipette tip for each well and pipette up and down to mix.".upcase
      check "Cap each stripwell. Press each one very hard to make sure it is sealed."
    end
  end
  
  # This method calculates and returns the pcr temperature.
  def calculate_pcr_temp
    # TODO implement more sophisticated anealing temperature calculation which can make use of multiple thermocyclers
    # if more than one stripwell is needed
    annealing_temps = operations.map do |op|
      [op.input("QC Primer1").val.properties["T Anneal"], op.input("QC Primer2").val.properties["T Anneal"]]
    end.flatten
    pcr_temp = annealing_temps.min
    pcr_temp #return
  end
  
  # calculate the extension time for the PCR. 
  # Extension time is calculated differently depending on whether all inputs are yeast, 
  # or all inputs are fragment/plasmids
  def calculate_extension_time y
    extension_time = "3 minutes"
    if !y
      template_lengths = operations.map { |op| op.input("Template").child_sample.properties["Length"] }
      max_length = template_lengths.max
      extension_seconds = [max_length / 1000.0 * 30.0, 180].max
      extension_time = Time.at(extension_seconds).utc.strftime("%M:%S") 
    end
    extension_time #return
  end
  
  # This method tells the technician to start the pcr at a certain temperature.
  # It then changes the stripwell location to match what thermocycler they were placed into.
  def start_pcr pcr_temp, extension_time, y
    thermocycler = show do
      title "Start PCR at #{pcr_temp} C"
      check "Place the stripwells into an available thermal cycler and close the lid."
      operations.output_collections["PCR"].each do |sw|
        get "text", label: "Enter the name of the thermocycler used for stripwell #{sw.id}", var: "#{sw.id}", default: "TC1"
      end
      check "Click 'Home' then click 'Saved Protocol'. Choose 'YY' and then 'CLONEPCR'." if !y
      check "Click 'Home' then click 'Saved Protocol'. Choose 'YY' and then 'COLONYPCR'." if y
      check "Set the anneal temperature to #{pcr_temp} C. This is the 3rd temperature."
      check "Set the extension time (4th time) to #{extension_time}." 
    end
    
    # change stripwell location to reflect which thermocycler they were placed into (using the technician input from above)
    operations.output_collections["PCR"].each do |sw|
      key = "#{sw.id}".to_sym
      sw.move(thermocycler[key])
      sw.save
    end
  end
  
  # This method marks items as deleted and tells the technician to clean up.
  def clean_up
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
  end
  
  # This method associates the colony pic and origin plate id to the output.
  def pass_down_colony_pick
    operations.each do |op|
      # Use association map to cleanly associate data to the parts of a collection
      colony_pick = op.input("Template").part.get(:colony_pick)
      origin_plate_id = op.input("Template").part.get(:origin_plate_id)
      
      AssociationMap.associate_data(op.output("PCR"), :colony_pick, colony_pick) if colony_pick
      AssociationMap.associate_data(op.output("PCR"), :origin_plate_id, origin_plate_id) if origin_plate_id
    end
  end  
end