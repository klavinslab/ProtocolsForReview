needs "Standard Libs/UploadHelper"
needs "Standard Libs/Debug"
class Protocol
    include UploadHelper, Debug
    
  def main

    operations.make
    up = Upload.find(34786)
    data = read_url(up)
    log_info data
    raise up.inspect
    show do
      title "Protocol information"
      note "This protocol is used to prepare yeast overnight suspensions from divided yeast plates."
    end

    # Move overnights to 30 C shaker incubator
    operations.each do |op|
        op.output("Overnight").item.location = "30 C shaker incubator"
        op.output("Overnight").item.save
    end

    show do
      title "Media preparation in media bay"
      
      check "Grab #{operations.length} of 14 mL Test Tube"
      check "Slowly shake the bottle of 800 mL YPAD liquid (sterile) media to make sure it is still sterile!!!"
      check "Add 2 mL of 800 mL YPAD liquid (sterile) to each empty 14 mL test tube using serological pipette"
      check "Write down the following ids on the cap of each test tube using dot labels #{operations.map { |op| op.output("Overnight").item.id}}"
    end
    
    operations.retrieve
    
    show do
      title "Inoculation"
      
      note "Inoculate yeast into test tube according to the following table. Return items after innocuation."
      
      bullet "Take a sterile 10 uL tip, pick up a medium sized colony by gently scraping the tip to the colony."
      
      
      table operations.start_table
        .custom_column(heading: "Item ID.section") { |op| "#{op.input("Yeast Strain").item.id}.#{op.input("Yeast Strain").column + 1}" }
        .output_item("Overnight", heading: "14 mL tube ID", checkable: true)
      .end_table
    end
    
    operations.store
    
    return {}
    
  end

end
