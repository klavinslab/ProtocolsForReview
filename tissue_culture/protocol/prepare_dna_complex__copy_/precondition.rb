def parse_csv csv
  x = csv.strip.split(/[\s,]+/)
end

def set_inputs op, items
  items.each do |i|
    items_in_inputs = op.inputs.map { |input| input.item }.uniq
    if not items_in_inputs.include? i
      n = "Discard Item #{i.id}"
      op.add_input n, i.sample, i.object_type
      op.input(n).set item: i
    end
  end
end

def set_inputs_from_str(csv_str)
  csv = parse_csv(csv_str)
  item_ids = csv.map { |x| x.to_i }.uniq
  if item_ids.any? { |x| x == 0 }
    op.associate :precondition_status, "\"#{csv_str}\" is not formatted properly. \
        Please use a comma or space separated list of item ids #{item_ids} something #{csv}"
    return false
  end
  items = item_ids.map { |i| Item.find_by_id(i) }
  set_inputs(items)

def precondition(op)
  set_inputs_from_str(op.input("Plasmid Items").val)
end