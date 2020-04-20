# Author: Justin Vrana
# Date: 08-15-17

needs "Tissue Culture Libs/TissueCulture"

class Protocol
    include TissueCulture
  INPUT = "Items to discard (comma or space separated)"

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
  
  def is_a_bsl2_item item
    ["Active Cell Line", "Cell Line"].include? item.sample.sample_type.name 
  end

  def main

    if debug
      operations.running.each do |op|
        op.set_input INPUT, "  	161913  	148558	164743 164742	, 164744, 	164745, 	164746, 9999999"
      end
    end

    operations.running.each do |op|
      csv_str = op.input(INPUT).val
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
      not_bsl2 = items.select { |i| !is_a_bsl2_item i }
      to_be_deleted = items.select { |i| !i.deleted? and is_a_bsl2_item(i) }
      
      op.associate :missing_items, "#{missing_items.join(', ')}." if missing_items.any?
      op.associate :owned_by_others, "#{items_not_owned.map { |i| "#{i.id} (#{i.sample.user.login})" }.join(", ")}" if items_not_owned.any?
      op.associate :already_discarded, "#{deleted_items.map { |i| i.id }.join(', ')}" if deleted_items.any?
      op.error :no_items_discarded, "No items were discarded. See associated data." if to_be_deleted.empty?
      op.associate :not_bsl2, "#{not_bsl2.map { |i| i.id }.join(', ')}" if not_bsl2.any?
      set_inputs op, to_be_deleted
    end

    if operations.running.empty?
      return {}
    end
    
    required_ppe STANDARD_PPE

    show do 
      title "Please discard all following items"
      note "If the item is an overnight, please bleach the tubes and leave them at the dishwashing station."
      note "If the item is a plate, plasmid, fragment, or glycerol stock, please discard it in the biohazard."
    end

    operations.running.retrieve

    operations.running.each do |op|
        op.inputs.reject { |x| x.name==INPUT}.each do |input|
            input.item.mark_as_deleted 
        end
    end

    release_tc_plates operations.running.map { |i| i.inputs.reject { |x| x.name==INPUT }.map { |fv| fv.item } }.flatten

    operations.store

    return {}

  end

end
