needs "Standard Libs/Feedback"
class Protocol
    include Feedback
  def main
    operations.make
    
    # Protocol information
    protocol_information

    # Move overnights to 30 C shaker incubator
    move_to_incubator
    
    # Media preparation in media bay
    media_preparation

    operations.retrieve
    
    # Inoculation
    inoculation

    operations.store
    get_protocol_feedback
    return {}
    
  end
  
  # This method displays this protocol's information.
  def protocol_information
    show do
      title "Protocol information"
      note "This protocol is used to prepare yeast overnight suspensions from divided yeast plates."
    end
  end
  
  # This method changes the item location to 30 C Shaker incubator.
  def move_to_incubator
    operations.each do |op|
        op.output("Overnight").item.location = "30 C shaker incubator"
        op.output("Overnight").item.save
    end
  end
  
  # This method tells the technician to prepare media in the media bay.
  def media_preparation
    show do
      title "Media preparation in media bay"
      
      check "Grab #{operations.length} of 14 mL Test Tube"
      check "Slowly shake the bottle of 800 mL YPAD liquid (sterile) media to make sure it is still sterile!!!"
      check "Add 2 mL of 800 mL YPAD liquid (sterile) to each empty 14 mL test tube using serological pipette"
      check "Write down the following ids on the cap of each test tube using dot labels #{operations.map { |op| op.output("Overnight").item.id}}"
    end
  end
  
  # This method tells the technician to perform inoculation steps.
  def inoculation
    show do
      title "Inoculation"
      
      note "Inoculate yeast into test tube according to the following table. Return items after innocuation."
      
      bullet "Take a sterile 10 uL tip, pick up a medium sized colony by gently scraping the tip to the colony."
      
      
      table operations.start_table
        .custom_column(heading: "Item ID.section") { |op| "#{op.input("Yeast Strain").item.id}.#{op.input("Yeast Strain").column + 1}" }
        .output_item("Overnight", heading: "14 mL tube ID", checkable: true)
      .end_table
    end
  end

end
