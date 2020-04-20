# Author: Justin Vrana
# Date: 08-15-17
# Edit 08-24-17 by Garrett Newman
#   - added array input

class Protocol
  CSV_INPUT = "Items to discard (comma or space separated)"
  ARRAY_INPUT = "Items to discard"

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

  def main

    if debug
      operations.running.each do |op|
        op.set_input CSV_INPUT, "  	161913  	164743 164742	, 164744, 	164745, 	164746, 9999999"
      end
    end

    operations.running.each do |op|
        csv_input = op.input(CSV_INPUT)
        csv_input.save
    end

    operations.running.each do |op|
      csv_str = op.input(CSV_INPUT).val
      csv = parse_csv csv_str
      csv = csv.map! { |x| x.to_i }.uniq
      if csv.any? { |x| x == 0 } or csv.empty?
        op.error :input_error, "\"#{csv_str}\" is not formatted properly. Please use a comma or space separated list of item ids"
      else
        op.temporary[:item_ids] = csv
      end
    end

    items_to_discard = []
    operations.running.each do |op|
      missing_items = op.temporary[:item_ids].select { |i| Item.find_by_id(i).nil? }
      items = op.temporary[:item_ids].map { |i| Item.find_by_id(i) }.compact
      items_not_owned = items.select { |i| i.sample.user != op.user }
      items.select! { |i| i.sample.user == op.user } unless debug
      deleted_items = items.select { |i| i.deleted? }
      to_be_deleted = items.select { |i| !i.deleted? }
      op.associate :missing_items, "#{missing_items.join(', ')}." if missing_items.any?
      op.associate :owned_by_others, "#{items_not_owned.map { |i| "#{i.id} (#{i.sample.user.login})" }.join(", ")}" if items_not_owned.any?
      op.associate :already_discarded, "#{deleted_items.map { |i| i.id }.join(', ')}" if deleted_items.any?
      op.error :no_items_discarded, "No items were discarded. See associated data." if to_be_deleted.empty?
      set_inputs op, to_be_deleted
    end

    if operations.running.empty?
      return {}
    end

    show do 
      title "Please discard all following items"
      note "If the item is an overnight, please bleach the tubes and leave them at the dishwashing station."
      note "If the item is a plate, plasmid, fragment, or glycerol stock, please discard it in the biohazard."
    end

    operations.running.retrieve

    show do
      title "Discard all of the following items"
      operations.running.each do |op|
        op.inputs.reject { |x| x.name == CSV_INPUT || x.name == ARRAY_INPUT }.each do |input|
          item = input.item
          item.mark_as_deleted if item
          if item
            check "#{item} (#{item.object_type.name})"
          end
        end
      end
    end

    operations.store

    return {}

  end

end
