# Adapted from Check Divided Yeast Plate

class Protocol

  def main
    # Take plates  
        operations.retrieve
        
    # Output is same as input (TODO Make "pass" work for parts as well?)
        operations.each do |op|
            op.output("Checked Plate").copy_inventory op.input("Plate")
        end
        operations.output_collections["Checked Plate"] = operations.map { |op| op.output("Checked Plate").collection }.uniq
        
    # Count the number of colonies and select whether the growth is normal, contaminated, or a lawn
        plate_info = show do 
            title "Estimate colony numbers"
            
            operations.each do |op|
                plate = op.input("Plate").item
                
                get "number", var: "n#{plate.id}", label: "Estimate how many colonies are on plate #{plate.id}", default: 5
                select ["normal", "contamination", "lawn"], var: "s#{plate.id}", label: "If plate #{plate.id} is contaminated, choose contamination. If there is a lawn of colonies, choose lawn.", default: 0
            end
        end
        
        operations.each do |op|
            plate = op.input("Plate").item
            if plate_info["n#{plate.id}".to_sym] == 0
                plate.mark_as_deleted
                plate.save
                op.temporary[:delete] = true
                op.error :no_colonies, "There are no colonies for plate #{plate}"
            else
                plate.associate :num_colonies, plate_info["n#{plate.id}".to_sym]
                plate.associate :status, plate_info["s#{plate.id}".to_sym]
                op.pass("Plate", "Checked Plate")
            end
        end
    
        # Delete and discard any plates that have 0 colonies
        show do 
            title "Discard Plates"
            
            discard_plate_ids = operations.select { |op| op.temporary[:delete] }.map { |op| op.input("Plate").item.id }
            note "Discard the following plates with 0 colonies: #{discard_plate_ids}"
        end if operations.any? { |op| op.temporary[:delete] }

    
    # Parafilm 
        show do 
            title "Label and Parafilm"
            note "Label the plates with their item ID numbers on the side, and parafilm each one."
            note "Labelling the plates on the side makes it easier to retrieve them from the fridge."
        end
            
    # Return plates
        operations.each { |op| op.output("Checked Plate").item.store }
        operations.store
    
    return {}
    
  end

end
