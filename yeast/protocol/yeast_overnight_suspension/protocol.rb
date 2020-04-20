needs "Standard Libs/Debug"
needs "Standard Libs/Feedback"
class Protocol
require 'active_support'
include Debug
include Feedback

  def main
    operations.make
    # media = operations.map {|op| op.input("Type of Media").val}
    # log_info 'media', media
    show do
      title "Protocol information"
      note "This protocol is used to prepare yeast overnight suspensions from glycerol stocks, plates or overnight suspensions for general purposes."
    end

    obj_names = operations.map { |op| op.input("Yeast Strain").object_type.name }.uniq
    obj_names.each do |obj_name|
      ops = operations.select { |op| op.input("Yeast Strain").object_type.name == obj_name }
      group_by_media = ops.map.group_by {|op| op.input('Type of Media').val}
      
      # Move overnights to 30 C shaker incubator
      ops.each do |op|
        op.output("Overnight").item.location = "30 C shaker incubator"
        op.output("Overnight").item.save
      end
      
      # Media preparation in the media bay
      media_preparation group_by_media, obj_name

      ops.retrieve interactive: false
      
      # generate list of correct colonies to choose for suspension, if applicable
      ops.each do |op|
        correct_colonies = op.input("Yeast Strain").item.get :correct_colonies
        if correct_colonies.instance_of?(String)
            correct_colonies = JSON.parse(correct_colonies)
        end
        correct_colonies = ["c1", "c2"] if debug
        if correct_colonies
          correct_colonies.to_s.chomp(']').chomp!('[') #convert Array to string representation if Array and remove brackets
          op.temporary[:colony_info] = correct_colonies.split(",").to_sentence() #convert back to array so we can use to_sentence
        else
          op.temporary[:colony_info] = "N/A"
        end
      end
      
      # Inoculate yeast into test tubes
      inoculation obj_name, ops
      
      ops.store
    end
    get_protocol_feedback
    return {}
    
  end
  
  #Requires: op.output("Transformation").object_type.name == "Yeast Overnight for Antibiotic Plate"
  #spins out an operation to make an antibiotic plate that will be used for plating this op's strain
  #associates the operation id of the new operation to the Antibiotic plating operation that comes after this one
  def start_make_antibiotic_plate op
      #getting the media sample required to plate this yeast strain
      antibiotic_hash = { "nat" => "clonNAT", "kan" => "G418", "hyg" => "Hygro", "ble" => "Bleo", "5fo" => "5-FOA" }
      full_marker = op.input("Yeast Strain").sample.properties["Integrated Marker(s)"]
      marker = full_marker.downcase[0,3]
      marker = "kan" if marker == "g41"
      media = Sample.find_by_name("YPAD + #{antibiotic_hash[marker]}") 
      
      #create new operation and set to pending
      ot = OperationType.find_by_name("Make Antibiotic Plate")
      new_op = ot.operations.create(
          status: "pending",
          user_id: op.user_id
      )
      op.plan.plan_associations.create operation_id: new_op.id
      
      #add correct media sample as the output of the new op
      aft = ot.field_types.find { |ft| ft.name == "Plate" }.allowable_field_types[0]
      new_op.set_property "Plate", media, "output", false, aft
      
      #associate the new op with the item that will be the input of Yeast antibiotic plating
      #This way Antibiotic Plating can retrieve the correct plate for the yeast strain
      op.output("Overnight").item.associate :spin_off, new_op.id

      op.plan.reload
      new_op.reload
  end
  
  # This method tells the technician to prepare the media.
  def media_preparation group_by_media, obj_name
    group_by_media.each do |media_arr|
        
      show do
        title "Media preparation in media bay"
        
        check "Grab #{media_arr[1].length} of 14 mL Test Tube"
        
        check "Slowly shake the bottle of 800 mL #{media_arr.first} liquid (sterile) media to make sure it is still sterile!!!"
        check "Add 2 mL of 800 mL #{media_arr.first} liquid (sterile) to each empty 14 mL test tube using serological pipette"
        check "Write down the following ids on the cap of each test tube using dot labels #{media_arr[1].map { |op| op.output("Overnight").item.id}}"
      #   check "Write down the following ids on the cap of each test tube using dot labels #{ops.map { |op| op.output("Overnight").item.id}}"
        check "Go to the M80 area and work there." if obj_name == "Yeast Glycerol Stock"
      end
    end
  end
  
  # This method tells the technician to inoculate yeast into a test tube.
  def inoculation obj_name, ops
    show do
      title "Inoculation"
      
      note "Inoculate yeast into test tube according to the following table. Return items after innocuation."
      warning "If there is more than one correct colony, you only need to pick one colony"
      if obj_name == "Yeast Glycerol Stock"
        bullet "Use a sterile 100 uL tip and vigerously scrape the glycerol stock to get a chunk of stock. Return each glycerol stock immediately after innocuation."
      elsif obj_name ==  "Yeast Plate"
        bullet "Take a sterile 10 uL tip, pick up a medium sized correct colony. Pick up colony by gently scraping the tip to the colony."
      elsif obj_name == "Yeast Overnight Suspension"
        bullet "Inoculate the following tubes with 5 uL of overnight"
      end
      
      table ops.start_table
        .input_item("Yeast Strain", heading: "#{obj_name} ID", checkable: true)
        .custom_column(heading: "Location") { |op| op.input("Yeast Strain").item.location }
        .output_item("Overnight", heading: "14 mL Tube ID")
        .custom_column(heading: "Correct Colonies") { |op| op.temporary[:colony_info] }
        .end_table
    end
  end

end
