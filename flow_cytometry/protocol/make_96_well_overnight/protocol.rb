#Set so errored operations are removed from work flow

needs 'Standard Libs/CommonInputOutputNames'
needs 'Standard Libs/PlanParams'
needs 'Tissue Culture Libs/CollectionDisplay'
class Protocol
  
  include CommonInputOutputNames, PlanParams
  include CollectionDisplay

  attr_accessor :plan_params
  attr_accessor :static_params


  def default_plan_params
    #####WARNING: do not change the default parameters unless you are doing Protocol Development
    {
      add_inducer_chemical:   false,            #Determine if an inducer should be added (currently not supported)
      inducer_chemcial:       {},               #Tells which inducer to use for which row (each row has the same inducer)(0 indicates no inducer)
      ul_inducer_well:        {},               #Determines number of ul of inducer per well in each row (constant for all columns)
      media_volume:           1000,             #ul of media per well
    }
  end

  def static_params
    {
      glycerol_obj_type_filter:  "Glycerol",
      plate_obj_type_filter:     "Plate"
    }
  end

  def main           

    set_constants
   

    operations.make

    glycerol_ops = filter_op_input(operations, static_params[:glycerol_obj_type_filter])
    plate_ops = filter_op_input(operations, static_params[:plate_obj_type_filter])

    operations.retrieve(only: [MEDIA])
    plate_ops.retrieve(only: [INPUT_SAMPLE])

    build_full_samples_array

    validate_plan_params

    design_plate

    get_supplies

    label_plates

    add_media

    #go through (row by row) and put glycerol stock overnights into correct deep wells
    add_cells(glycerol_ops, plate_ops)


    #go through (row by row) and put  inducer chenmicals into correct wells
    #not supported yet

    cover_plates

    set_locations

    operations.store

  end

  def set_locations
    operations.each do |op|
      op.output(OUTPUT_SAMPLE).item.location = "30 C shaker incubator"
    end
  end

  def cover_plates
    show do 
      title "Cover 96 Well Plates"
      note "Cover all 96 Well Plates with cover thingy"
    end
  end

  #filters the operation list based on filter string,
  #
  #operationlist OperationList (since this should be pushed over to a library)
  #filter        string       (exact string of what you are filtering on)
  def filter_op_input(operationlist, filter)
    op_list = operationlist.reject{|op| !op.input(INPUT_SAMPLE).item.object_type.name.include? filter}
    op_list.extend(OperationList)
    return op_list
  end

  def add_cells(glycerol_ops, plate_ops)
    ran_add_cells = false


    if glycerol_ops.length > 0
      ran_add_cells = true
      glycerol_ops.each do |op|
        inocculate_wells(op, glycerol_ops)
      end 
    end

    if plate_ops.length > 0
     ran_add_cells = true
      plate_ops.each do |op|
        inocculate_wells(op)
      end 
    end

    if !ran_add_cells
      a = "Ahh something quite interesting happened.  There appears to be nothing to do!"
      b = " We all know this is can't be true, so something horrible happend with the protocol."
      c = " You defenetly shouldnt go bother the automation scientist.  Its deff not their job!"
      raise a + b + c
    end

  end

  #op   operation   the operation that needs to be displayed
  #fetch_input  bool    determins if the input item needs to be gotten (aka glycerol stock)
  def inocculate_wells(op, op_list = nil)

    if op_list != nil
      op_list.retrieve(only: [INPUT_SAMPLE])
    end

    show do
      title "Add Cells to Wells"
      op.input_array(INPUT_SAMPLE).collect! {|samp| samp = samp.item}.each do |item|
        multi_plate = op.output(OUTPUT_SAMPLE).collection
        locations = multi_plate.find(item)
        note "Using a pipette tip collect cells from #{item.object_type.name} <b>#{item}</b>"
        note "Put pipette tip into highlighted well of 96 Well plate <b>#{multi_plate.id}</b>"
        note "Reference table below"
        table highlight_rc(multi_plate, locations)
      end
    end
  end


  def label_plates
    show do 
      title "Label Deep Well plates with the following labels"
      operations.each do |op|
        note "#{op.output(OUTPUT_SAMPLE).collection.id}"
      end
    end
  end

  #goes through and sets all constants
  def set_constants
    operations.each do |op|
      set_temporary_op_params(op, default_plan_params)

      op.temporary[:array_samples] = op.input_array(INPUT_SAMPLE)
      op.temporary[:array_samples].collect! {|samp| samp = samp.sample}

      op.temporary[:num_each_culture] = op.input("Number of Each Sample").val.to_i
   
      plate_obj = operations.first.output(OUTPUT_SAMPLE).object_type
      op.temporary[:num_columns] = plate_obj.columns
      op.temporary[:num_rows] = plate_obj.rows
    end
  end


  #builds the full samples array that is being used
  def build_full_samples_array
    operations.each do |op|
      num_times = op.temporary[:num_each_culture]
      if num_times > 1
        full_array = Array.new
        op.temporary[:array_samples].each do |samp|
          num_times.times{full_array << samp}
        end
        op.temporary[:array_samples] = full_array
      end
    end
  end


  #validates plan params
  def validate_plan_params
    operations.each do |op|
      num_rows = op.temporary[:num_rows]
      num_columns = op.temporary[:num_columns]
      er = false
      er_message = "Errors in Plan Parameters"
      num_samps_rows = op.temporary[:array_samples].length
      if op.temporary[:plan_params][:add_inducer_chemical]
        er = true && er_message = er_message + ' inducer array wrong size' if plan_params[:inducer_chemcial].length != num_rows
        er = true && er_message = er_message + ' ul inducer array wrong size' if plan_params[:ul_inducer_well].length > num_columns
        er = true && er_message = er_message + ' too many samples' if num_rows > num_rows
      else
        #if we are just doing all of them no inducer can have up to 96 samples
        er = true && er_message = er_message + ' oh deary me, there too many samples silly!' if num_samps_rows > 96
      end
      op.error :invalid_parameter, er_message if er
      op.temporary[:valid_params?] = !er
    end
  end


  #associates what wells has what in them
  #this will start simple and then get more complicated as needed.
  #ideally the other methods work completly independent of this
  #so this can be changed at will and everything else stays the same
  def design_plate
    operations.each do |op|
      if !op.temporary[:plan_params][:add_inducer_chemical]
        design_no_inducer_plate(op)
      else
        design_inducer_plate(op)
      end
    end
  end


  #designs a plate that has no inducers
  #fills in row by row (per collection standard)
  def design_no_inducer_plate(op)
      plate = op.output(OUTPUT_SAMPLE).collection
      samples = op.temporary[:array_samples]
      plate.add_samples(samples)
  end

  #designs a plate that has inducers
  def design_inducer_plate
    raise "inducer plates are not currently supported.  Sorry ):  << the backward sad face is there to make you uncomfortable cause its backwards"
  end


  #adds appropriate media to wells
  def add_media #TODO
    operations.each do |op|
      total_media_volume = op.temporary[:plan_params][:media_volume] * op.temporary[:array_samples].length / 1000

      show do
        title 'Pour out media'
        note "Pour about #{total_media_volume} ml of <b>#{op.input(MEDIA).item.id} #{op.input(MEDIA).sample.name}</b> into (PLASTIC TRAY BOI)"
      end

      plate = op.output(OUTPUT_SAMPLE).collection

      show do
        title 'Add media to wells'
        note "Using the multi channel pipette add #{op.temporary[:plan_params][:media_volume]} ul of media to highlighted wells of"
        note "<b> 96 Well Plate #{plate}</b>"
        table highlight_non_empty(plate)
      end
    end

  end


  #get supplies
  def get_supplies  #TODO
    operations.each do |op|
      if op.temporary[:plan_params][:add_inducer_chemical]
        show do 
          title "not supported yet. But go get those inducers!"
        end
      end
    end

    show do 
      title "Get needed supplies"
      check "#{operations.length} Deep Well 96 well plate(s) (GOTTA GET THE PROPER NAME HERE) located in that one location"
      check "L1000 multi channel pipette"
    end
  end


end