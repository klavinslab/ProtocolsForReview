# Author: Justin Vrana
# Date: 08-15-17
# Edit 08-24-17 by Garrett Newman
#   - added array input
needs "Standard Libs/Feedback"

class Protocol
  include Feedback    
  
  CSV_INPUT = "Items to discard (comma or space separated)"
  ARRAY_INPUT = "Items to discard"
      
  # This method parses a csv file and splits it.
  def parse_csv csv
    x = csv.strip.split(/[\s,]+/)
  end
  
  # This method sets inputs (?)
  def set_inputs op, items
    op.temporary[:noowneritems] = []
    items.each do |i|
      items_in_inputs = op.inputs.map { |input| input.item }.uniq
      if not items_in_inputs.include? i
        n = "Discard Item #{i.id}"
        if i.sample.nil?
            #special case if item has no sample
            op.temporary[:noowneritems].push i
        else
            op.add_input n, i.sample, i.object_type
            op.input(n).set item: i
        end
      end
    end
  end
  
  # This method creates a variety of different associations. These associations
  # include missing items, items owned by others, and items already discarded. 
  # If no items are discarded in this method, then that associated operation will error.
  def op_associations
    operations.running.each do |op|
      missing_items = op.temporary[:item_ids].select { |i| Item.find_by_id(i).nil? }
      items = op.temporary[:item_ids].map { |i| Item.find_by_id(i) }.compact
      items_not_owned = items.select { |i| (i.sample.nil? || i.sample.user != op.user) && !op.user.is_admin }
      items = items - items_not_owned unless debug
      deleted_items = items.select { |i| i.deleted? }
      to_be_deleted = items.select { |i| !i.deleted? }
      op.associate :missing_items, "#{missing_items.join(', ')}." if missing_items.any?
      op.associate :owned_by_others, "#{items_not_owned.map { |i| "#{i.id} (#{i.sample.nil? ? "no owner" : i.sample.user.login})" }.join(", ")}" if items_not_owned.any?
      op.associate :already_discarded, "#{deleted_items.map { |i| i.id }.join(', ')}" if deleted_items.any?
      op.error :no_items_discarded, "No items were discarded. See associated data." if to_be_deleted.empty?
      set_inputs op, to_be_deleted
    end
  end
  
  # This method tells the technician to discard the following items.
  def show_discard_items
    show do 
      title "Please discard all following items"
      note "If the item is an overnight, please bleach the tubes and leave them at the dishwashing station."
      note "If the item is a plate, plasmid, fragment, or glycerol stock, please discard it in the biohazard."
    end
  end
  
  # This method retrieves and shows the items that the technician will have to discard.
  def discard_items
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
        op.temporary[:noowneritems].each do |item|
            check "#{item} (#{item.object_type.name})"
        end
      end
    end
  end
  
  # This method sets the csv.
  def set_csv
    if debug
      operations.running.each do |op|
        op.set_input CSV_INPUT, "  	161913  	164743 164742	, 164744, 	164745, 	164746, 9999999 13376 130823"
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
  end
  

  def main
    operations.each do |operation|
        
    end

    # get csv input and operate on it.
    set_csv
    
    operations.running.each do |op|
        op.input(CSV_INPUT).delete
    end

    #items_to_discard = []
    
    # set operation associations
    op_associations


    if operations.running.empty?
      return {}
    end
    
    # tells the tech to discard these item types
    show_discard_items

    operations.running.retrieve
    
    #discard specific items
    discard_items

    operations.store

    get_protocol_feedback()

    return {}

  end

end