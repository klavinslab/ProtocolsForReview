category = "Tissue Culture Libs"
needs "#{category}/TissueCultureConstants"
needs "#{category}/TextExtension"

# eval Library.find_by_name("TissueCultureConstants").code("source").content
# extend TissueCultureConstants

# eval Library.find_by_name("TextExtension").code("source").content
# extend TextExtension


module BaseExtension
  def show_with_input_table ops, create_block, num_tries=5
    ops.extend(OperationList)
    counter = 0
    results = nil
    continue = true
    msgs = []
    while continue and counter < num_tries
      counter += 1
      input_table = create_block.call(ops)
      extra = ShowBlock.new(self).run(&Proc.new) if block_given?

      results = show do
        raw extra if block_given?
        if msgs.any?
          msgs.each do |m|
            warning m
          end
        end
        table input_table.render
      end

      msgs = ops.cleanup_input_table(operations)
      if msgs.any?
        continue = true
      else
        continue = false
      end
    end
    results
  end
end #BaseExt

# Adds new input_table methods

module OperationListExtension
  # A custom selection input with input validation
  def custom_selection key, choices, options={}, &default_block
    opts = {heading: "Custom Selection", checkable: false, style_block: nil, type: "string"}
    opts.merge! options
    key = key.to_sym
    opts[:heading] += " (#{choices.join("/")})"
    self.custom_input(key, opts, &Proc.new)
    self.validate(key) { |op, v| choices.include?(v) }
    self.validation_message(key) { |op, k, v| "Choice #{v} is not valid. Please select from #{choices}" }
  end

  # A custom "yes" or "no" input box. Gets converted to true or false in cleanup_input_table
  def custom_boolean key, options={}, &default_block
    opts = {heading: "Custom Boolean", checkable: false, style_block: nil}
    opts.merge! options
    choices ||= ["y", "n"]
    key = "#{key}||boolean".to_sym
    key = key.to_sym


    # Default boolean block
    boolean_block ||= Proc.new { |x|
      choices[0] == x.downcase[0]
    }

    # Designate which keys are boolean keys
    temp_op = self.first
    temp_op.temporary[:boolean_keys] ||= []
    temp_op.temporary[:boolean_keys] << key

    # Determine how to interpret input values as booleans
    temp_op.temporary[:boolean_blocks] ||= Hash.new
    temp_op.temporary[:boolean_blocks][key] = boolean_block

    opts[:type] = "string"
    self.custom_selection(key, choices, opts, &Proc.new)
    self.validate(key) { |op, v| choices.include?(v.downcase[0]) } # override the validation
  end


  # Collects inputs from custom_input and saves in operation.temporary hash
  # Needs operations due to the way Krill saves inputs to virtual operations
  def cleanup_input_table operations
    temp_op ||= self.first
    boolean_keys = temp_op.temporary.delete(:boolean_keys)
    boolean_blocks = temp_op.temporary.delete(:boolean_blocks)
    messages = []

    self.each do |op|
      vhash = op.temporary[:validation]
      op.temporary[:temporary_keys].each do |temp_key|
        # Parse key
        uid, key = temp_key.to_s.split('__')
        key = key.to_sym
        temp_op = operations.select { |op| op.temporary.keys.include? temp_key }.first
        val = temp_op.temporary[temp_key]

        # Input validation
        vblock = vhash[key] if vhash
        valid = true

        valid = vblock.call(op, val) if vblock
        if not valid
          msghash = op.temporary[:validation_messages] || Hash.new
          msgblock = msghash[key]
          validation_message = msgblock.call(op, key, val) if msgblock
          validation_message ||= "Input invalid: operation_id: #{op.id}, key: #{key}, value: #{val}"
          messages << validation_message
        end

        op.temporary[key.to_sym] = val
        temp_op.temporary.delete(temp_key)
      end

      boolean_keys.each do |key|
        b = boolean_blocks[key]
        v = op.temporary.delete(key)
        k, _ = key.to_s.split("||").map(&:to_sym)
        op.temporary[k] = b.call(v)
      end if boolean_keys

      op.temporary.delete(:temporary_keys)
      op.temporary.delete(:uid)
      op.temporary.delete(:validation)
      op.temporary.delete(:validation_messages)
    end
    messages.uniq
  end
end #OpListExt

module OperationExtension
  include TissueCultureConstants

  # Expands an output array by num
  def expand_output_array name, num
    fv = self.output_array(name).first
    # raise "FieldType #{name} is not an array. Cannot set output array." if not self.output(name).field_type.array
    wires = fv.wires_as_source.map { |wire| wire }
    self.set_output name, [fv.sample]*num, aft=fv.allowable_field_type

    # Make sure wires are faithfully restored to first fv in array
    wires.each do |wire|
      wire.from_id = self.output_array(name).first.id
      wire.save
    end
  end

  # Really really lame method...
  def required_cells
    cells = nil
    name = self.operation_type.name
    plating_operations = ["Plate Cells"] #, "Plate Multiwell Dish", "Plate Well"]
    plating_operations.each { |po| raise "OperationType #{po} not found!" if OperationType.find_by_name(po).nil? }

    if plating_operations.include? name
      fv = self.outputs.first.extend(CellCulture)
      cells = fv.max_cell_number * self.input("Seed Density (%)").val.to_i / MAX_CONFLUENCY
      cells = cells * self.input("Number of Wells").val.to_i if name == "Multiwell Plate"
    end

    if name == "Freeze Cell Line"

    end

    cells
  end
end #OperationExtension

module TemporaryExtensions
  include BaseExtension
  include OperationListExtension
  include OperationExtension

  Base.send(:prepend, BaseExtension)
  OperationList.send(:prepend, OperationListExtension)
  Operation.send(:prepend, OperationExtension)
  String.send(:prepend, TextExtension)
end