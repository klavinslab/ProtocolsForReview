needs "Standard Libs/Debug"

class Protocol
  LOWER_BOUND      = "Lower Bound"
  UPPER_BOUND      = "Upper Bound"
  SAMPLE_NAME      = 'Sample Name ("Any" if any is fine)'
  OBJECT_TYPE_NAME = "Object Type Name"
  
  include Debug
  
  def main
    operations.each do |op|
        
        sample = Sample.find_by_name(op.input(SAMPLE_NAME).val)
        object_type = ObjectType.find_by_name(op.input(OBJECT_TYPE_NAME).val)
        
        if (sample.nil? && op.input(SAMPLE_NAME).val.downcase != "any") || object_type.nil?
          show do
            title "Sample name or object type name incorrect"
            
            note 'Please check your sample and object type names! ("Any" is valid for sample name).'
          end
          
          return {}
        end
        
        
        # Sorting Items by box and location and box - Test Example
        # i1 = Item.find(102299)
        # i2 = Item.find(98894)
        # i3 = Item.find(99061)
        # items = [i1,i2,i3]
        # log_info items, items.map {|i| i.location} # unsorted
        # items.sort! {|x, y| x.location.split('.')[1..3] <=> y.location.split('.')[1..3]}
        # log_info items, items.map {|i| i.location}
        # # Next grouping by box and each slide directs tech by box
        # items_grouped_by_box = items.group_by {|i| i.location.split('.')[1]}
        # log_info items
        # items_grouped_by_box.each {|box_num, item_arr| log_info item_arr}
        
        lower = op.input(LOWER_BOUND).val.to_i
        upper = op.input(UPPER_BOUND).val.to_i
        items = []
        
        if op.input(SAMPLE_NAME).val.downcase == "any"
          items = Item.where('id IN (?) AND object_type_id=(?) AND location!="deleted"',
                             (lower..upper).to_a,
                             object_type.id)
                             
        else
          items = Item.where('id IN (?) AND sample_id=(?) object_type_id=(?) AND location!="deleted"',
                             (lower..upper).to_a,
                             sample.id,
                             object_type.id)
        end
        
        # Sort items by location
        # make an array with items that dont have locations in the format of M.#.#.# NOR locations that are nil
        removed_items = items.select {|item| item.location.split('.')[1..3].nil? || item.location.split('.')[1..3].length < 3} 
        
        # make an array with items that only have locations in the format of M.#.#.#
        kept_items = items - removed_items 
        
        # sort by location that follows X.#.#.# format.
        kept_items.sort! {|x, y| x.location.split('.')[1..3] <=> y.location.split('.')[1..3]} # Sorts by the box number Fridge.X.X.X 
        
        # Add the removed items and no-location items back to the list
        kept_items.push(*removed_items)
        
        items_grouped_by_box = kept_items.group_by {|i| i.location.split('.')[1]}
        items_grouped_by_box.each {|box_num, item_arr| # Groups by box then takes by box location
             take item_arr, interactive: true, method: "boxes"
         }
        
        # Dispose or recycle depending on the items
        dispose_items
    
      	kept_items.each do |x|
      		x.mark_as_deleted
      		x.save
      	end
      	
      	release items
      end
      
    end # main
    
    def dispose_items
    	show do
    		title "Dispose or recycle depending on the items"
    		
    		check "For glassware contained items, 50 mL Falcon tubes, 96 deepwell plates, take to the dishwashing station. For other items, discard properly to the bioharzard box."
    	end
    end
    
end # Protocol