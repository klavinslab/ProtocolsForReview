# gets item type 
class Protocol

    def main
        
        item_id=99263     # enter item id here
        item_id=115552 
            
            
        operations.each { |op|
            show { 
                note "#{Item.find(item_id).object_type}" 
                note "#{Item.find(item_id).object_type.name}" 
            }
        }
        
        return {}
        
    end

end