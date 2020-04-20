needs "Standard Libs/Feedback"
class Protocol
    
  include Feedback
  def main
    operations.retrieve interactive: false
    operations.make
    
    # grab primers from EE office
    pick_up_primers
    
    # Centrifuge ordered primer
    spin_down_primers
    
    # Get nMoles of primer for each tube
    get_primer_nm
    
    # Label primers and add TE
    rehydrate_primers
    
    # Prepare tubes to make aliquots with
    prepare_aliquot_tubes
    
    # Finish preparing primer stock tubes
    vortex_and_centrifuge
    
    # Add primer stock to prepared aliquot tubes
    make_aliquots
    
    operations.each { |op| op.input("Primer").item.mark_as_deleted }
    operations.store
    
    get_protocol_feedback
    return {}
  end

  # This method tells the technician to pick up primers for this protocol.
  def pick_up_primers
    show do
      title "Go the EE office to pick up primers"
      
      note "Abort this protocol if no primer has shown up. It will automatically rescheduled."
    end
  end
  
  # This method tells the technician to spin down the primers
  def spin_down_primers
    show do
      title "Quick spin down all the primer tubes"
      
      check "Find the order with sales order (or supplier ref) number #{operations.first.input_data("Primer", :order_number)}"
      check "Put all the primer tubes in a table top centrifuge to spin down for 3 seconds."
      warning "Make sure to balance!"
    end    
  end
  
  # Queries the tech for the nMoles of primer as written on tube and stores the measurement in operation.temporary[:n_moles]
  def get_primer_nm
    show do
      title "Enter the nMoles of the primer"
      
      note "Enter the number of moles for each primer, in nm. This is written toward the bottom of the tube, below the MW."
      note "The id of the primer is listed before the primer's name on the side of the tube."
      table operations
          .start_table
          .input_sample("Primer")
          .get(:n_moles, type: "number", heading: "nMoles", default: 10)
          .end_table
    end    
  end
  
  # label the primer tubes with their new unique id, and rehydrate each with an amount of TE dependent on the nMoles of primer.
  def rehydrate_primers
    show do
      title "Label and rehydrate"
      
      check "Label each primer tube with the ids shown in Primer Stock ids and rehydrate with volume of TE shown in Rehydrate"
      table operations
          .start_table
          .input_sample("Primer")
          .output_item("Primer Stock")
          .custom_column(heading: "Rehydrate (uL of TE)", checkable: true) { |op| op.temporary[:n_moles] * 10 }
          .end_table
    end    
  end
  
  # Tells the technician to vortex and centrifuge 
  def vortex_and_centrifuge
    show do
      title "Vortex and centrifuge"
      
      check "Wait one minute for the primer to dissolve in TE." if operations.length < 7
      check "Vortex each tube on table top vortexer for at least 30 seconds and then quick spin for 2 seconds on table top centrifuge."
    end    
  end
  
  # Prepare the aliquot tubes
  def prepare_aliquot_tubes
    show do
      title "Grab #{operations.length} 1.5 mL tubes"
      
      check "Grab #{operations.length} 1.5 mL tubes, label with following ids: #{operations.map { |op| "#{op.output("Primer Aliquot").item.id}" }.join(", ")}"
      check "Add 90 uL of water into each above tube."
    end    
  end

  # Displays a table and make primer aliquots 
  def make_aliquots
    show do
      title "Make primer aliquots"
      
      check "Add 10 uL from each primer stock into each primer aliquot tube using the following table."
      
      table operations
          .start_table
          .output_item("Primer Stock", heading: "Primer Stock (10 uL)")
          .output_item("Primer Aliquot", checkable: true)
          .end_table
      check "Vortex each tube after the primer has been added."
      
    end
    # Associate concentration of primer aliquot
    operations.map { |op| op.output("Primer Aliquot").item.associate('concentration_uM', 10)}
  end
end
