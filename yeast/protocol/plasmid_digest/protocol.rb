needs "Cloning Libs/Cloning"
needs "Standard Libs/Debug"
needs "Standard Libs/Feedback"
# This operation is a mirror of restriction digest with pre selected enzymes, meant to be used specifically for preparing a plasmid integrant for yeast transformation.
# Unlike Restriction Digest, this operation outputs a item, not a part of a collection
# Unlike Restriction Digest, this operation outputs a 'Digested Plasmid', rather than a Fragment. Semantically these are the same, but it is convienent for users of the 
# Yeast workflow to know that a specific fragment used to be a plasmid. (They do not have to create a new fragment item that corresponds to the plasmid)
class Protocol
    include Debug
    include Cloning
    include Feedback
   
    def main 

      operations.retrieve.make 
      # The only inputs to this operation should be plasmids that will be integrated into the genome of Yeast in Yeast Transformation
      # Plasmids that will be transformed as plasmids, or Fragment stock, can both be entered as a direct input to Yeast Transformation
      
      # sample_id = Sample.where(user_id: User.find_by_name("Ayesha Saleem").id)
      # sample = sample_id.select { |s| s.sample_type_id == SampleType.find_by_name("Yeast Strain").id }
      # s = sample.select { |s| s.properties["Integrant"] == Sample.find_by_id(12933) }[0]
      # show do 
      #     note "#{Sample.find_by_id(13733).properties["Integrant"].id}"
      #     note "#{sample.join(",")}"
      #     note "#{s}"
      # end
      
      
      #prepare and label 0.6 ml tubes
      prepare_tubes
      
      # calculate the ratio of mix::plasmid stock needed for each operation and build the table which
      # shows the tech what reagent volumes are for each output tube
      check_concentration operations, "Integrant"
      operations.each do |op|
          conc = op.input("Integrant").item.get(:concentration).to_i
          conc = rand(100..1000) if debug
          op.temporary[:plasVol] = (1000.0 / conc).round(1)
      end
      mm_table = operations.start_table
          .output_item("Digested Plasmid")
          .custom_column(heading: "DI Water (µl)", checkable: true) { |op| 44 - op.temporary[:plasVol] }
          .custom_column(heading: "Buffer (µl)", checkable: true) { |op| 5 }
          .custom_column(heading: "Enzyme (µl)", checkable: true) { |op| 1 }
          .end_table
      
      # For each output tube, add the mix of Cut smart and PmeI which will digest the plasmid
      add_mix(mm_table)
      
      # load each output tube with the associated plasmid
      add_plasmid
      
      operations.store io: "input", interactive: true
      
      # put all the digest tubes into the 37 C incubator for an hour before putting them on the bench in preperation for a yeast transform.
      incubate_digest
      
      operations.store io: "output", interactive: false
      get_protocol_feedback
      return {}
    end
    
    # This method tells the technician to prepare digest tubes and label them.
    def prepare_tubes
      show do 
        title "prepare digest tubes"
        
        note "Grab #{operations.length} 0.6 mL tubes and label with the following item ids: #{operations.map { |op| op.output("Digested Plasmid").item.id }.to_sentence}"
      end
    end
    
    # This method builds and returns a table.
    def table mix_table_builder
      check_concentration operations, "Integrant"
      operations.each do |op|
        conc = op.input("Integrant").item.get(:concentration).to_i
        op.temporary[:plasVol] = (1000.0 / conc).round(1)
      end
      
      
      mm_table = operations.start_table
        .output_item("Digested Plasmid")
        .custom_column(heading: "DI Water (µl)", checkable: true) { |op| 44 - op.temporary[:plasVol] }
        .custom_column(heading: "Buffer (µl)", checkable: true) { |op| 5 }
        .custom_column(heading: "Enzyme (µl)", checkable: true) { |op| 1 }
        .end_table
      return mm_table
    end
    
    # This method tells the technician to add digestion mix to tubes
    def add_mix(mm_table)
    # Take Cut Smart and PmeI
      cut_smart = Sample.find_by_name("Cut Smart").in("Enzyme Buffer Stock")[0]
      pmeI = Sample.find_by_name("PmeI").in("Enzyme Stock")[0]
      
      take [cut_smart], interactive: true
  
      show do
        title "Grab an ice block"
        
        warning "In the following step you will take PmeI enzyme out of the freezer. Make sure the enzyme is kept on ice for the duration of the protocol."
      end
      
      take [pmeI], interactive: true
      
      show do 
        title "Prepare each tube for digest by adding digestion mix"
        
        note "Pipette add reagents to tubes according to the following table"
        table mm_table
        note "Vortex the tubes to ensure thorough mixing."
      end
      release [pmeI, cut_smart], interactive: true
    end
    
    # This method tells the technician to add plasmid stock into tubes.
    def add_plasmid
      # Calculate plasmid volumes
      # Pipette plasmids into tubes
      show do
        title "Load tubes"
        
        note "Add volume of each sample stock into the tube indicated."
        warning "Use a fresh pipette tip for each transfer."
        
        table operations.start_table
          .input_item("Integrant")
          .output_item("Digested Plasmid")
          .custom_column(heading: "Volume (µl)", checkable: true) { |op| op.temporary[:plasVol] }
          .end_table
        warning "Vortex and spin down 0.6 mL tubes."
      end
    end
    
    # This method tells the technician to perform incubation steps.
    def incubate_digest
        # Move tubes to 37 C incubator

      show do
        title "Incubate"
        
        check "Put the cap on each tube. Press each one very hard to make sure it is sealed."
        check "Place the tubes into a small green tube holder and then place in 37 C incubator where it will stay for 1 hour."
        note '<a href="https://www.google.com/search?q=set%20timer%20for%20one%20hour">timer link</a>'
        image "put_green_tube_holder_to_incubator"
        
      end

      operations.each do |op|
        op.output("Digested Plasmid").item.move "37C incubator"
      end
        
    end
end