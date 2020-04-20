# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!
needs "Standard Libs/Feedback"
needs "Yeast/CheckForGrowth"
class Protocol
    include Feedback
    include CheckForGrowth
    INPUT = "Overnight"
  def main
    operations.retrieve interactive: true
    
    # Verify whether each input has growth and error it if it does not
    # IMPORTANT: this must go before operations.make because it changes the number of operations to make
    check_for_growth(INPUT)

    operations.make
    
    media = find(:item, object_type: { name: "800 mL liquid" }, sample: {name: "YPAD"})[0]
        
    take [media], interactive: true
    
    # Media preparation
    media_preparation

    operations.retrieve
    
    # Inoculate yeast overnights into flasks
    inoculate_yeast

    operations.each do |op|
      o = op.input("Overnight").item
      o.mark_as_deleted
      o.save
    end
    
    # Discard yeast overnights
    discard_yeast

    operations.each do |op|
      yc = op.output("Culture").item
      yc.location = "30 C shaker incubator"
      yc.save
    end
    
    operations.store io: "input", interactive: false
    operations.store io: "output", interactive: true
    get_protocol_feedback
    return {}
    
  end
  
  # This method tells the technician to prepare media.
  def media_preparation
    show do
      title "Media preparation"
      
      warning "Work in the media bay for media prepartion"
      
      check "Grab #{operations.length} of 250 mL Baffled Flask."
      check "Add 50 mL of 800 mL YPAD liquid (sterile) into each 250 mL Baffled Flask."
      check "Label each flask with a piece of tape with the following ids:"
      note operations.map { |op| op.output("Culture").item.id }.join(", ")
    end
  end
  
  # This method tells the technician to inoculate yeast overnights into flasks.
  def inoculate_yeast
    show do
      title "Inoculate yeast overnights into flasks"
      
      note "Pipette 1 mL of each overnight into each culture flask."
      
      table operations.start_table
        .input_item("Overnight")
        .output_item("Culture", heading: "Yeast 50 mL Culture ID (output)", checkable: true)
        .end_table
    end
  end

  # This method tells the technician to discard yeast overnights.
  def discard_yeast
    show do
      title "Discard yeast overnights"
      
      note "Discard yeast overnights with the following ids. If it is a plastic tube, push down the cap to seal the tube and discard into biohazard box.
            If it is a glass tube, place it in the dish washing station."
      note operations.map { |op| op.input("Overnight").item.id }.join(", ")
    end
  end

end