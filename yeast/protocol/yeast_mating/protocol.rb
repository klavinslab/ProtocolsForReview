# Updated: 12/05/18
# Written by: Ayesha Saleem
# Updated by: Eriberto Lopez (elopez3@uw.edu)
needs "Standard Libs/Debug"
needs "Standard Libs/Units"
class Protocol
  include Debug, Units
  
  # DEF
  STRAIN_1 = "Strain 1"
  STRAIN_2 = "Strain 2"
  OUTPUT =  "Overnight"
  
  # Constants
  MEDIA = "YPAD"
  OUTPUT_CULT_VOL = 0.5#mLs
  FROM_GLYCEROL_STEPS = [
    "Go to M80 area to perform following inoculation steps.",
    "Grab one glycerol stock at a time out of the M80 freezer.",
    "Use a sterile 100uL tip with pipettor and vigerously scrape a big chuck of glycerol stock swirl into the 1.5mL tube following the table below.",
    "Place the glycerol stock immediately back into the freezer after each use."
  ] 
  FROM_PLATE_STEPS = [
    "<b>Important: The index of the appropriate divided yeast plate section is displayed in this table starting from an index of 1.</b>",
    "Using a sterile 10uL tip, pick up a medium sized colony by gently using the tip to scrape the colony."
  ]
  def intro()
      show do
          title "Yeast Mating"
          note "This protocol will guide you in mating two haploid yeast strains together."
          note "Researchers take advantage of yeast mating to mix alleles of interest or combine multiple synthetic genetic parts into one diploid strain."
          note "<b>1.</b> Resuspend input items in liquid media (1.5mL tube)."
          note "<b>2.</b> Prepare 14mL overnight tubes with liquid media."
          note "<b>3.</b> Mix resuspended input items in their appropriate overnight tube."
      end
  end

  def main
    intro
    operations.retrieve(interactive: false)
    operations.make
    # Prep, label, and fill tubes
    item_to_tube_num = prepare_tubes()
    # Innoculate prepped tubes
    innoculate_input_samples_before_mating(groupby_input_object_type(), item_to_tube_num) 
    # Combine samples to mate yeast strains
    prepare_output_test_tubes()
    yeast_mating_innoculation(item_to_tube_num)
    incubate_matings()
    # Change the location of the running operations
    operations.running.each {|op| op.output(OUTPUT).item.location = "30 C incubator"
      op.output(OUTPUT).item.save
    }
    # Find how many and which type of plates are needed for the successive operation 
    plates = num_and_type_of_yeast_plates() # Maybe we can spin out a pour plates op that will create an auxothropic and antibiotic plate. 
    cleanup_locations(item_to_tube_num)
    operations.store(interactive: false)
    return {}
  end # Main
  
  def prepare_tubes()
    # Find the input item ids then count how many times the are used as an input to deterimine media necessary for each mating
    input_items = operations.map {|op| [op.input(STRAIN_1).item, op.input(STRAIN_2).item]}.flatten
    # Find how many times a given sample appears as an input
    media_per_item = {}
    input_items.each {|item|
      (media_per_item.keys.include? item.id) ? media_per_item[item.id] += 1 : media_per_item[item.id] = 1
    }
    # Enumerate the 1.5mL tube labels for quick labeling
    item_to_tube_num = {}
    input_items.uniq.each_with_index {|item, idx| item_to_tube_num[item.id] = idx+1}
    # Build checkable display table, with unique input samples array
    t = [["Tube ID#", "#{MEDIA} Vol (#{MICROLITERS})"]]
    input_items.uniq.each_with_index {|item, idx| t.push( [item_to_tube_num[item.id]].concat( [media_per_item[item.id]*220].map{|content| {content: content, check: true}} ) ) }
    show do
      title "Prepare 1.5mL Tubes"
      note "Grab #{input_items.length} 1.5mL tubes and label with <b>'Tube ID#'</b> according to the following table:"
      table t
      bullet "If media volume is greater than 1.7mLs create a duplicate tube and divide the aliquot between the tubes."
    end
    return item_to_tube_num
  end
  
  def groupby_input_object_type()
    input_fv_arr = []
    operations.each {|op| op.inputs.flatten.each {|fv| input_fv_arr.push(fv)} }
    return input_fv_arr.uniq.group_by {|fv| fv.item.object_type.name}
  end
  
  def num_and_type_of_yeast_plates()
    plates = {}
    operations.each do |op|
      markers = op.output(OUTPUT).sample.properties["Integrated Marker(s)"].split(",")
      if markers.length < 2 
        markers = op.output(OUTPUT).sample.properties["Integrated Marker(s)"].split(" ")
      end
      markers.collect! { |m| ((m.upcase.include?"URA") || (m.upcase.include?"TRP") || (m.upcase.include?"LEU") || (m.upcase.include?"HIS")) ? "- #{m.upcase}" : "+ #{m.upcase}" }
      #   #update how many plates are needed for a specific set of markers 
      plates[markers] ? plates[markers] = plates[markers] + 1 : plates[markers] = 1
    end
    show do 
      title "Plates Needed"
      note "The following plates are needed: "
      plates.each { |p, q| note "SDO #{p.join(" ")}, <b>Quantity:  #{q}</b>"}
      note "Please check the inventory to ensure these are in stock, and if they're not, notify a lab manager"
    end
    return plates
  end
  
  
  def cleanup_locations(item_to_tube_num)
    t = []
    operations.each {|op| op.inputs.each {|fv| t.push([fv.item.id, fv.item.location])} }
    t = t.uniq.unshift(['Item', 'Location'])
    show do
      title "Cleaning Up..."
      note "Use the table to return any items left out:"
      note "OR continue to finish the experiment"
      table t
    end
  end
  
  def incubate_matings()
    show do
      title "Incubate"
      check "Place all 14 mL tubes with the following ids into 30 C shaker incubator:"
      note operations.running.collect { |op| op.output(OUTPUT).item.id }.join(", ")
      check "Discard all 1.5 mL tubes."
    end
  end  
  
  def yeast_mating_innoculation(item_to_tube_num)
    mat_t = [[ "14 mL tube ID", "First 1.5 mL Tube", "Second 1.5 mL Tube"]] #creating the mating table
    # Creating checkable table using the quick label tube numbers to guide tech to mixing the appropriate strains
    operations.running.each {|op|
      mat_t.push(
        [op.output(OUTPUT).item.id].concat(
          [item_to_tube_num[op.input(STRAIN_1).item.id], item_to_tube_num[op.input(STRAIN_2).item.id]].map{|content| {content: content, check: true}} 
        ) 
      )
    }
    show do 
      title "Yeast Mating"
      check "Vortex all 1.5 mL tubes"
      check "Add 200#{MICROLITERS} from each 1.5 mL tube to 14 mL tubes according to the following table:"
      table mat_t
    end
  end
  
  def prepare_output_test_tubes()
    show do
      title "Prepare 14 mL Tubes"
      check "Grab #{operations.running.length} of 14 mL tubes and label each with the Overnight Item ID according to the table below:"
      table operations.start_table
        .custom_column(heading: "14 mL Tube", checkable: true) { |op| operations.running.index(op) + 1}
        .output_item(OUTPUT)
      .end_table
      check "Add #{OUTPUT_CULT_VOL}mL of YPAD to each tube"
    end
  end
  
  def innoculate_input_samples_before_mating(groupby_object_type, item_to_tube_num)
    # show do 
    #   warning "You're going to be inoculating from both glycerol stocks and streak plates; the order of the tube ID's is going to change!"
    # end if (groupby_object_type.keys.include? "Yeast Glycerol Stock") && (groupby_object_type.keys.include? "Divided Yeast Plate")
    
    groupby_object_type.each {|obj_type, in_fv_arr|
      # All fv are uniq so we must combine the field values that are using the same item
      log_info 'object_type', obj_type, 'input items', in_fv_arr.map {|fv| fv.item}.uniq
      show do
        title "Innoculation"
        case obj_type
        when "Divided Yeast Plate"
          FROM_PLATE_STEPS.each {|step| check step }
          if debug
            t = in_fv_arr.map {|fv| 
              ["#{fv.item.id}#{[1]}", fv.item.location].concat([item_to_tube_num[fv.item.id]].map{|content| {content: content, check: true}}) 
            }.uniq
          else
            t = in_fv_arr.map {|fv| 
              ["#{fv.item.id}#{[fv.column+1]}", fv.item.location].concat([item_to_tube_num[fv.item.id]].map{|content| {content: content, check: true}}) 
            }.uniq
          end
        when "Yeast Glycerol Stock"
          FROM_GLYCEROL_STEPS.each {|step| check step }
          t = in_fv_arr.map {|fv| 
            ["#{fv.item.id}", fv.item.location].concat([item_to_tube_num[fv.item.id]].map{|content| {content: content, check: true}}) 
          }.uniq
        else
          show{warning "THIS IS NOT A VAILD OBJECT TYPE, INCLUDE THE CASE IN THE: 'innoculate_input_samples_before_mating' function"}
        end
        t.unshift(["#{obj_type}", "Location", "1.5 mL tube ID"]) # Display table column labels
        table t
      end unless in_fv_arr.empty?  
    }
  end
  
end # Class