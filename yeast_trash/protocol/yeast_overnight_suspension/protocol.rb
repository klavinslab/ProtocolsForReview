class Protocol

  def main

    operations.make
    
    show do
      title "Protocol information"
      note "This protocol is used to prepare yeast overnight suspensions from glycerol stocks, plates or overnight suspensions for general purposes."
    end

    obj_names = operations.map { |op| op.input("Yeast Strain").object_type.name }.uniq
    obj_names.each do |obj_name|
        ops = operations.select { |op| op.input("Yeast Strain").object_type.name == obj_name }
        
        
        # Move overnights to 30 C shaker incubator
        ops.each do |op|
            op.output("Overnight").item.location = "30 C shaker incubator"
            op.output("Overnight").item.save
        end
    
        show do
          title "Media preparation in media bay"
          
          check "Grab #{ops.length} of 14 mL Test Tube"
          check "Slowly shake the bottle of 800 mL YPAD liquid (sterile) media to make sure it is still sterile!!!"
          check "Add 2 mL of 800 mL YPAD liquid (sterile) to each empty 14 mL test tube using serological pipette"
          check "Write down the following ids on the cap of each test tube using dot labels #{ops.map { |op| op.output("Overnight").item.id}}"
          check "Go to the M80 area and work there." if obj_name == "Yeast Glycerol Stock"
        end
        
        ops.retrieve interactive: false
    
        # Make a hash to keep track of the number of colonies used for each plate
        #   (e.g. If one is used, used the next if there exists another "correct" colony)
        plate_colony_to_use = Hash.new { |h, k| h[k] = 0 }
        
        ops.each_with_index do |op, idx|
          correct_colonies = op.input("Yeast Strain").item.get :correct_colony
          
          if obj_name.include?("Yeast Plate") && correct_colonies
            op.temporary[:colony_info] = "c#{correct_colonies[plate_colony_to_use[op]]}"
            plate_colony_to_use[op] += 1 if correct_colonies[plate_colony_to_use[op] + 1]
          else
            op.temporary[:colony_info] = "NA"
          end
        end
    
        show do
          title "Inoculation"
          
          note "Inoculate yeast into test tube according to the following table. Return items after innocuation."
          
          if obj_name == "Yeast Glycerol Stock"
            bullet "Use a sterile 100 µL tip and vigerously scrape the glycerol stock to get a chunk of stock. Return each glycerol stock immediately after innocuation."
          elsif obj_name ==  "Yeast Plate"
            bullet "Take a sterile 10 µL tip, pick up a medium sized colony by gently scraping the tip to the colony."
          elsif obj_name == "Yeast Overnight Suspension"
            bullet "Inoculate the following tubes with 5 uL of the overnight"
          end
          
          table ops.start_table
            .input_item("Yeast Strain", heading: "#{obj_name} ID", checkable: true)
            .custom_column(heading: "Location") { |op| op.input("Yeast Strain").item.location }
            .output_item("Overnight", heading: "14 mL Tube ID")
            .custom_column(heading: "Colony Selection") { |op| op.temporary[:colony_info] }
            .end_table
        end
        
        ops.store(io: "input", interactive: true)
        ops.store(io: "output", interactive: true)
      end
  
    return {}
    
  end

end
