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

def precondition(op)
  csv_str = op.input("Items to discard (comma or space separated)").val
  csv = parse_csv csv_str
  item_ids = csv.map { |x| x.to_i }.uniq
  if item_ids.any? { |x| x == 0 }
    op.associate :precondition_status, "\"#{csv_str}\" is not formatted properly. \
        Please use a comma or space separated list of item ids #{item_ids} something #{csv}"
    return false
  end

  missing_items = item_ids.select { |i| Item.find_by_id(i).nil? }
  items = item_ids.map { |i| Item.find_by_id(i) }.compact
  items_not_owned = items.select { |i| i.sample.nil? || i.sample.user != op.user }
  items.select! { |i| !i.sample.nil? && i.sample.user == op.user }
  deleted_items = items.select { |i| i.deleted? }
  to_be_deleted = items.select { |i| !i.deleted? }

  op.inputs.each { |input| input.retrieve }

  # op.add_input "Enzyme" items.first.sample, items.first.object_type
  set_inputs op, to_be_deleted

  op.associate :missing_items, "#{missing_items.join(', ')}." if missing_items.any?
  op.associate :owned_by_others, "#{items_not_owned.map { |i| "#{i.id} (#{i.sample.nil? ? "no owner" : i.sample.user.login})" }.join(", ")}" if items_not_owned.any?
  op.associate :already_discarded, "#{deleted_items.map { |i| i.id }.join(', ')}" if deleted_items.any?


  op.associate :precondition_status, "OK" if op.get(:precondition_status)
  return true
end