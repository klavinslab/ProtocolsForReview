# Author: Ayesha Saleem
# December 20, 2016

#Updated: Cannon Mallory
#DEC 3, 2019

# TO DO: 
    # Create option for "there are baby colonies but they're not big enough for protocols" case--put back in incubator
    # Re-streak the plate if there's too much contamination--fire check plate again in 24 hrs, probably collection
    # Make multiple fluorescent markers work with protocol



needs "Standard Libs/Feedback"
needs "Standard Libs/PlanParams"

class Protocol
  include Feedback
  include PlanParams

  attr_accessor :plan_params

  ###### DEFAULT PARAMS #########

  #These are the default plan parameters. (Currently only addressing if it needs to be checked for fluorescent markers)
  #This should not be editied within the protocol.  It can be updated through the designer tab
  #when designing the plan.  To update parameters add an association to the plan, in the "key" box
  #put `optons` in the data box put `{'hash_key': 'value', 'hash_key2': 'value'}`
  def default_plan_params
    {
      fluorescent_marker: false,   # "true" or "false" This is wether or not a fluorescent marker is being used
      dark_light:         "light",  # "dark" or "light" indicating which fluorescent condition is "correct"
      marker_type:        "GFP",  # "GFP" is only one supported ("mCherry" "mTurq" "ecPink" will be supported eventually)
    }
  end

  #these are the static parameters that do not change unless protocol is being updated
  def static_params
    {
      work_room:            'Lab Equipment Room 380B',
      dark_light_options:   ["dark", "light"],
      marker_type_options:  ["GFP", "RFP"],  #add more as they become supported
      max_col:              5,      # should be a number.  This will determine the max number of fluorescent that will be circled
    }
  end


  def main
    #ID fluorescent Plates
    fluorescent_operations = get_fluorescent_operations

    # Take plates  
    operations.retrieve
    
    # Count the number of colonies
    info = get_colony_numbers

    # skip if no plates are fluorescent
    if !fluorescent_operations[:dark_ops].empty? || !fluorescent_operations[:light_ops].empty?
      #prep for fluorescet plate screening
      go_to_work_room(fluorescent_operations)

      #screen fluorescent plates
      screen_fluorescent_plates(fluorescent_operations)
      
      #Return to bench
      return_to_bench
      
      #make note on fluorescent colonies
      note_fluorescent_plates(fluorescent_operations)
    end

    # Update plate data
    update_item_data info
    
    # Delete and discard any plates that have 0 colonies
    discard_bad_plates if operations.any? { |op| op.temporary[:delete] }
    
    # Parafilm and label plates
    parafilm_plates
    
    # Return plates
    operations.store
    
    # Get feedback
    get_protocol_feedback()
    return {}
  end
  

  #-----------------Validate Parameters -------------------#
  #returns false if params are valid.  True if not
  #Will only error out the operation and NOT the whole job
  def validate_parameters?(op)
    temp_params = op.temporary[:plan_params]
    errors_noted = "The following parameters for plan #{op.plan.id}  have errors: "
    er = false
    if temp_params[:fluorescent_marker]
      errors_noted.concat("dark_light invalid") && er = true if !static_params[:dark_light_options].include? temp_params[:dark_light]
      errors_noted.concat("marker_type not supported") && er = true if !static_params[:marker_type_options].include? temp_params[:marker_type]
    end
    op.error :invalid_parameters, errors_noted  if er
    op.temporary[:valid_params?] = !er
  end

  #-------- Get Fluorescent Plates/Set UP Equipment/RTB--------------#

  #Instructions to take proper plates to Dark Room
  def go_to_work_room(fluorescent_operations)
    dark_list = fluorescent_operations[:dark_ops]
    light_list = fluorescent_operations[:light_ops]
    show do
      title "Take Some Plates to #{static_params[:work_room]}"
      note "Take the following plates to the #{static_params[:work_room]} for fluorescent marker screening"
      t = Table.new(a: "Item Number")
      dark_list.each { |op| t.a(op.input("Plate").item.id).append }
      light_list.each { |op| t.a(op.input("Plate").item.id).append }
      table t.all.render
    end
  end



  def return_to_bench
    show do
      title "Return to Bench"
      note "Take all plates and return to bench"
    end
  end


  #----- Screen Fluorescent Plates ----- #
  #helps divert the different types of screenings.  #todo this will eventually be where the protocol
  #will change for different fluorescent markers
  def screen_fluorescent_plates(fluorescent_operations)
    dark_list = fluorescent_operations[:dark_ops]
    light_list = fluorescent_operations[:light_ops]
    if !dark_list.empty?
      sub_dark_list = sort_fluorescence(dark_list)
      sub_dark_list.each_value do |op_list|
        circle_col("dark", op_list)
      end
    end

    if !light_list.empty?
      sub_light_list = sort_fluorescence(light_list)
      sub_light_list.each_value do |op_list|
        circle_col("light", op_list)
      end 
    end
  end

  def sort_fluorescence(fluorescent_list)
    num_options = Hash.new
    static_params[:marker_type_options].each do |marker_type|

      same_type = fluorescent_list.select{|op| op.temporary[:plan_params][:marker_type] == marker_type}
      if !same_type.empty?
        same_type.extend(OperationList)
        num_options[marker_type] = (same_type)
      end
    end
    return num_options
  end

  #Instructions on marking fluorescent colonies
  def circle_col(d_l, list_of_ops)
    marker_type = list_of_ops[0].temporary[:plan_params][:marker_type]
    setup_fluorescent_equipment(marker_type)
    record_col_num = list_of_ops.start_table
                          .input_item("Plate")
                          .get(:num_col, type: "number", heading: "Number of Colonies", default: "#{static_params[:max_col]}") { |op| 0}
                          .end_table
                        
    responses = show do 
      title "Select #{d_l} Colonies"
      note "Fluorescent colonies glow really bright!"
      separator
      if d_l == 'dark'
        note 'Dark colonies are the colonies that <b>do not</b> glow'
      else
        note 'Light colonies are the colonies that <b>do</b> glow'
      end
      note "If possible try to select isolated colonies that can easily be identified later"
      check "Use a sharpie to circle <b>up to #{static_params[:max_col]}</b> #{d_l} colonies"
      check "Label each colony with c1...c#{static_params[:max_col]}"
      check 'Record how many colonies were circled in the table below'

      table record_col_num
    end

    response_hash = Hash.new
    list_of_ops.each_with_index do |op|
      plate = op.input("Plate").item
      if debug
        response_hash["n#{plate.id}".to_sym]= 5
      else
        response_hash["n#{plate.id}".to_sym]=responses.get_table_response(:num_col, op: op)
      end
    end
    
    update_fluorescent_data(response_hash, list_of_ops)
  end


   #Set Up equipment
  #TODO inclue Nightsea gun
  def setup_fluorescent_equipment(fluorescent_marker)
    show do
      title "Setup fluorescent screening equipment for viewing #{fluorescent_marker}"
      if fluorescent_marker == 'GFP'
        note "You will need the Dark Reader"
        check "Put on the <b>Orange</b> emission filter glasses"
        check "Turn off room light and close door"
        check "Turn on the Transilluminator"
      elsif
        note "Fluorescent marker is currently not supported.  Contact lab manager for help with this step."
      end
    end
  end


#-------- Determins which plates are fluorescet ------------#
  #finds the fluorescent operations and puts them in a nice usable list
  #2 by x matrix.  Row 1 is light, row 2 is dark
  def get_fluorescent_operations
    dark_ops = Array.new
    light_ops = Array.new
    operations.each do |op|
      set_temporary_op_params(op, default_plan_params)
      validate_parameters?(op)
      valid_params = op.temporary[:valid_params?]
      temp_params = op.temporary[:plan_params]
      if  temp_params[:fluorescent_marker] && valid_params
        dark_light = temp_params[:dark_light]
        op.associate(:fluoresent_type, dark_light)
       
        if dark_light == ("light")
          light_ops << op
        elsif dark_light == ("dark")
          dark_ops << op
        end
      end
    end
    dark_ops.extend(OperationList)
    light_ops.extend(OperationList)
    return {dark_ops: dark_ops, light_ops: light_ops}
  end
  

  #--------- Count All colonies ---------#

  # Count the number of colonies and select whether the growth is normal, contaminated, or a lawn
  def get_colony_numbers
    show do
      title "Count colonies with CFU software"
      note "In the gel room, load up the CFU software and prepare the camera."
      note "For each plate: take a picture of the plate, drag the image into the CFU, and record the number of colonies"
      
      operations.each do |op|
        if op.temporary[:valid_params?]
          plate = op.input("Plate").item
          get "number", var: "n#{plate.id}", label: "Number of colonies on #{plate}", default: 5
          select ["normal", "contamination", "lawn"], var: "s#{plate}", label: "Choose whether there is contamination, a lawn, or whether it's normal.", default: 0
        end
      end
    end    
  end
  

#---------- Updates information associated with items---------#

  # Alter data of the virtual item to represent its actual state
  def update_item_data (info)
    operations.each do |op|
      plate = op.input("Plate").item
      if info["n#{plate.id}".to_sym] == 0
        plate.mark_as_deleted
        plate.save
        op.temporary[:delete] = true
        op.error :no_colonies, "There are no colonies for plate #{plate.id}"
      else
        plate.associate :num_colonies, info["n#{plate.id}".to_sym]
        plate.associate :status, info["s#{plate.id}".to_sym]
        
        
        checked_ot = ObjectType.find_by_name("Checked E coli Plate of Plasmid")
        plate.store if plate.object_type_id != checked_ot.id
        plate.object_type_id = checked_ot.id
        plate.save
        op.output("Plate").set item: plate
        
        op.plan.associate "plate_#{op.input("Plate").sample.id}", plate.id
      end
    end
  end

  # Alter data of the virtual item to represent its actual state
  def update_fluorescent_data (info, op_list)
    op_list.each do |op|
      plate = op.input("Plate").item
      if info["n#{plate.id}".to_sym] == 0
        plate.mark_as_deleted
        plate.save
        op.temporary[:delete] = true
        op.error :no_colonies, "There are no fluorescent colonies for plate #{plate.id}"
      else
        plate.associate :num_fluorescent_colonies, info["n#{plate.id}".to_sym]
      end
    end
  end
  
  # discard any plates that have 0 colonies
  def discard_bad_plates
      show do 
        title "Discard Plates"
        
        discard_plate_ids = operations.select { |op| op.temporary[:delete] }.map { |op| op.input("Plate").item.id }
        note "Discard the following plates with 0 colonies: #{discard_plate_ids}"
    end
  end
  

  #------- Finish labeling all plates-------#
  # Parafilm and label any plates that have suitable growth
  def parafilm_plates
    show do 
      title "Label and Parafilm"
      
      plates_to_parafilm = operations.reject { |op| op.temporary[:delete] || !op.temporary[:valid_params?] }.map { |op| op.input("Plate").item.id }
      note "Perform the steps with the following plates: #{plates_to_parafilm}"
      check "Label the plates with their item ID numbers on the side, and parafilm each one."
      check "Labelling the plates on the side makes it easier to retrieve them from the fridge."
    end
  end

  #Make note on fluorescent plates
  def note_fluorescent_plates(fluorescent_operations)
    long_list = fluorescent_operations[:dark_ops] + fluorescent_operations[:light_ops]
    show do 
      title "Make Note on Fluorescent Plates"
      plates_to_note = long_list.reject { |op| op.temporary[:delete] }.map{ |op| op.input("Plate").item.id }
      note "Perform steps with the following plates: #{plates_to_note}"
      note "Place a small piece of tape on each plate"
      note "Make note on tape saying 'Select Circled Colonies'"
    end
  end
end