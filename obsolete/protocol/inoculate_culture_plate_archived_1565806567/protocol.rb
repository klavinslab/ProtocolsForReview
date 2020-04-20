# By: Eriberto Lopez
# elopez3@uw.edu
# 06/26/19

needs "Standard Libs/Debug"
needs "High Throughput Culturing/CultureComposition"
needs "High Throughput Culturing/HighThroughputHelper"

class Protocol
  include Debug
  include HighThroughputHelper
  
  # DEF
  INPUT = "Culture Condition"
  OUTPUT = "Culture Plate"
  TEMPERATURE = "Temperature (°C)"
  
  # Predcessor DEF
  STRAIN = "Strain"
  MEDIA = "Media"
  INDUCERS = "Inducer(s)"
  ANTIBIOTICS = "Antibiotic(s)"
  CONTROL = "Control Tag"
  REPLICATES = "Replicates"
  OPTIONS = "Option(s)"

  # Access class variables via Protocol.your_class_method
  @@materials_list = []
  def self.materials_list; @@materials_list; end
  
  def intro
    show do
      title "High Throughput Culturing"
      separator
      note "This protocol, organizes a culturing experiment into a high throughput container."
      note "The culturing could be very complex with additional inducers and reagents required to test experimental conditions."
      note "<b>1.</b> Gather materials for experiment."
      note "<b>2.</b> Fill and inoculate the container."
      note "<b>3.</b> Place plate in growth environment."
    end
  end
  
  def main
    intro
    clean_up_arr = []
    operations.group_by {|op| get_uninitialized_output_object_type(op) }.map do |out_ot, ops|
      ops.map do |op|
        experimental_cultures = []; control_cultures = []
        condition_ops = get_define_culuture_condition_ops(op) # Predecessor operations
        condition_ops.map do |condition_op|
          control_tag           = get_control_tag(condition_op)
          replicate_num         = get_replicate_num(condition_op)
          condition_options     = get_condition_options(condition_op)
          culture_component_arr = get_base_culture_components(condition_op)
          # Format inducer components to account for combintorial inducer conditions, prior to initializing CultureComposition
          formatted_inducer_components = format_induction_components(condition_op)
          # Arrange component array by combining the culture component arr with the varying inducer components, unless we do not need inducers
          distribute_inducer_components(culture_component_arr: culture_component_arr, formatted_inducer_components: formatted_inducer_components).each do |component_arr|
            culture = CultureComposition.new(component_arr: component_arr, object_type: out_ot, opts: condition_options)
            culture.composition.merge!(control_tag)
            culture.composition.merge!(get_source_item_input(culture))
            replicates = replicate_culture(culture: culture, replicate_num: replicate_num) 
            (control_tag.fetch('Control').empty?) ? experimental_cultures.push(replicates) : control_cultures.push(replicates)
          end
        end
        # Place sorted cultures into new collection & set the new collections to the ouput array of the operation
        new_output_collections = associate_cultures_to_collection(cultures: experimental_cultures, object_type: out_ot)
        output_array = op.output_array(OUTPUT)
        new_output_collections.each_with_index do |out_collection, idx|
          associate_controls_to_collection(cultures: control_cultures, collection: out_collection)
          if output_array[idx].nil? # If there are no output field values left to fill create a new one and add it to the output array
            new_fv = create_new_fv(args=get_fv_properties(output_array[idx-1]))
            output_array.push(new_fv)
          end
          output_array[idx].set(collection: out_collection)
        end
        # Depending on the type of input items prepare inoculates using the inoculation_prep_hash
        inoculation_prep_hash = get_inoculation_prep_hash(new_output_collections)
        inoculate_culture_plates(new_output_collections: new_output_collections, inoculation_prep_hash: inoculation_prep_hash)
        incubate_plates(output_collections: new_output_collections, growth_temp: op.input(TEMPERATURE).val)
      end
    end
    clean_up(item_arr: clean_up_arr.flatten.uniq)
    { operations: operations }
  end # Main
  
  def replicate_culture(culture:, replicate_num:)
    return replicate_num.times.map {|i| culture.composition.merge({'Replicate'=>"#{i+1}/#{replicate_num}"}) }
  end  
  
  def get_source_item_input(culture)
    source_array = []
    source_array.push({id: culture.composition.fetch(STRAIN).values.first[:item_id]})
    return { 'source'=> source_array }
  end
  
  # Get an array of predecessor operations through the Wire object.
  def get_define_culuture_condition_ops(op)
    predecessor_output_fv_ids = op.input_array(INPUT).map {|fv| fv.wires_as_dest.first.from_id } # Finding the pred fv ids by using the wires connecting them to this op.input_array
    define_culture_condition_ops = FieldValue.find(predecessor_output_fv_ids).to_a.map {|fv| fv.operation } # Predecessor operations
    return define_culture_condition_ops
  end
  
  def get_condition_options(condition_op)
    condition_op.input(OPTIONS).val
  end
  
  def get_replicate_num(condition_op)
    condition_op.input(REPLICATES).val.to_i
  end
  
  def get_control_tag(condition_op)
    { 'Control' => condition_op.input(CONTROL).val }
  end
  
  # Base components are the strain, media, and any counterselective antibiotics.
  def get_base_culture_components(condition_op)
    base_component_fvs = condition_op.field_values.select {|fv| ([STRAIN, MEDIA, ANTIBIOTICS].include? fv.name) && (fv.role == 'input') }
    culture_component_arr = base_component_fvs.map {|fv| FieldValueParser.get_args_from(obj: fv) }.flatten.reject {|component| component.empty? }
    return culture_component_arr
  end
  
  def format_induction_components(condition_op)
    inducer_fv = get_inducer_fieldValue(condition_op)
    formatted_inducer_components = FieldValueParser.get_args_from(obj: inducer_fv)
  end
  
  def get_inducer_fieldValue(condition_op)
    condition_op.field_values.select {|fv| fv.name == INDUCERS }.first
  end
  
  def induction_culture_component_generator(formatted_inducer_components, &block)
    formatted_inducer_components.each {|inducer_component| yield inducer_component } 
  end
  
  def distribute_inducer_components(culture_component_arr:, formatted_inducer_components:)
    culture_condition_arr = []
    if formatted_inducer_components
      induction_culture_component_generator(formatted_inducer_components) {|inducer_component| culture_condition_arr.push(culture_component_arr.dup.push(inducer_component).flatten) }
    else
      culture_condition_arr.push(culture_component_arr.dup)
    end
    return culture_condition_arr
  end
  
  def get_fv_properties(fv)
    {
      name: fv.name,
      role: fv.role,
      field_type_id: fv.field_type_id,
      allowable_field_type_id: fv.allowable_field_type_id,
      parent_class: fv.parent_class,
      parent_id: fv.parent_id
    }
  end
  
  def create_new_fv(args={})
    fv = FieldValue.new()
    (args) ? set_fv_properties(fv, args) : nil
    fv.save()
    return fv
  end
  
  def set_fv_properties(fv, args={})
    args.each {|k,v| fv[k] = v }
    fv.save()
    return fv
  end
  
end # Protocol