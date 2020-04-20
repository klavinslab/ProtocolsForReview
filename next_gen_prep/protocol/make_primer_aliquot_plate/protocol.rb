# Devin Strickland
# dvn.strcklnd@gmail.com
#
# Dilutes a 96-well Primer Plate collection from stock to working concentration

needs "Standard Libs/Debug"
needs "Standard Libs/AssociationManagement"

class Protocol

    include Debug, AssociationManagement

    # Sample
    STOCK_PLATE = "96-Well Primer Stock Plate"
    ALIQUOT_PLATE = "96-Well Primer Aliquot Plate"

    MY_DEBUG = false
    DEBUG_COLLECTION_ID = 299278

    def main
        
        operations.each do |op|
            
            stock_plate = nil
            
            loop do
                msg = ""
                
                data = show do
                    title "Enter Stock Plate ID"
                    warning msg if msg.present?
                    note "Enter the Item ID of the 96-Well Primer Stock Plate you wish to dilute."
                    get "text", var: "collection_id", label: "ID"
                end
                
                data[:collection_id] = DEBUG_COLLECTION_ID if debug && MY_DEBUG
                
                stock_plate = Collection.find(data[:collection_id])
                
                break if stock_plate.present? && stock_plate.object_type.name == STOCK_PLATE
                
                msg = "The Item ID entered (#{data[:collection_id]}) is not the Item ID of a #{STOCK_PLATE}."
            end 
            
            aliquot_plate = Collection.new_collection(ALIQUOT_PLATE)
            
            sample_id_matrix = stock_plate.get_matrix
            
            sample_table = sample_id_matrix.map do |row|
                row.map do |cell|
                    sample_id = cell.to_i
                    content = sample_id > 0 ? sample_id : ""
                    { content: content, style: { check: sample_id > 0 } }
                end
            end
            
            show do
                title "Dilute Primers"
                note "Get a 96-Well Plate for the primer aliquots."
                note "Add TE to the wells that are colored below."
                note "Dilute the primers from the #{STOCK_PLATE} into the #{ALIQUOT_PLATE}."
                note "Label the #{ALIQUOT_PLATE} with Item ID #{aliquot_plate}."
                
                table sample_table
            end
            
            aliquot_plate.associate_matrix(sample_id_matrix)
        end
        
        operations.store
        
        return {}
        
    end
    
end