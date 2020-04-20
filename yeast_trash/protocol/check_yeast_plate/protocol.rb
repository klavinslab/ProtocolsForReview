# Author: Ayesha Saleem
# December 20, 2016

# TO DO: 
    # Create option for "there are baby colonies but they're not big enough for protocols" case--put back in incubator
    # Re-streak the plate if there's too much contamination--fire check plate again in 24 hrs, probably collection

class Protocol

    def main
        # Take plates  
        operations.retrieve
        
        # Count the number of colonies and select whether the growth is normal, contaminated, or a lawn
        info = show do
            title "Estimate colony numbers"
            
            operations.each do |op|
                plate = op.input("Plate").item
                get "number", var: "n#{plate.id}", label: "Estimate how many colonies are on #{plate}", default: 5
                select ["normal", "contamination", "lawn"], var: "s#{plate}", label: "Choose whether there is contamination, a lawn, or whether it's normal."
            end
        end
    
        # Alter data of the actual item
        operations.each do |op|
            plate = op.input("Plate").item
            if info["n#{plate.id}".to_sym] == 0
                plate.mark_as_deleted
                plate.save
                op.temporary[:delete] = true
                op.error :no_colonies, "There are no colonies for plate #{plate}"
            else
                plate.associate :num_colonies, info["n#{plate.id}".to_sym]
                plate.associate :status, info["s#{plate.id}".to_sym]
                op.pass("Plate", "Plate")
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
            
            plates_to_parafilm = operations.reject { |op| op.temporary[:delete] }.map { |op| op.input("Plate").item.id }
            note "Perform the steps with the following plates: #{plates_to_parafilm}"
            note "Label the plates with their item ID numbers on the side, and parafilm each one."
            note "Labelling the plates on the side makes it easier to retrieve them from the fridge."
        end
            
        # Return plates
        operations.running.each { |op| op.output("Plate").item.store }
        operations.store
        
        return {}
  end
end
