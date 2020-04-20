INPUT = "Item ID"

class Protocol

  def main
      
    
    items = []
    
    operations.each do |op|
        id = op.input(INPUT).val
        if debug then id = 12345 end
        item = Item.find(id)
        if item.location == "deleted"
            op.error :item_deleted, "This item has already been deleted"
        end
        items.push(item)
    end
    
    show do
        title "Return items"
        items.each do |i|
            i.store
            check "Item #{i.id} to #{i.location}"
        end
    end
            
    {}

  end

end
