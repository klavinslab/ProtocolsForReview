# Author: Ayesha Saleem
# November 4, 2016
needs "High Throughput Culturing/HighThroughputHelper"

class Protocol
    include HighThroughputHelper
    
  def search_part_associations(collection:, data_key:, attribute:)
    collection_associations = AssociationMap.new(collection)
    part_data_matrix = collection_associations.instance_variable_get(:@map).fetch("part_data")
    part_data_matrix.map! {|row| row.map! {|part| part.empty? ? nil : part.fetch(data_key).values.first.fetch(attribute) } }
  end

  def main
    raise search_part_associations(collection: Collection.find(372586), data_key: "Strain", attribute: "item_id").inspect
    # Take plates  
        operations.retrieve
        
    # Output is same as input (TODO Make "pass" work for parts as well?)
        operations.each do |op|
            op.output("Plate").copy_inventory op.input("Plate")
        end
        operations.output_collections["Plate"] = operations.map { |op| op.output("Plate").collection }.uniq
        
    # Count the number of colonies and select whether the growth is normal, contaminated, or a lawn
        plate_info = show do 
            title "Estimate colony numbers"
            
            operations.each do |op|
                plate = op.input("Plate").collection
                
                get "number", var: "n#{op.id}", label: "Estimate how many colonies are on plate #{plate.id}.#{op.input("Plate").column + 1}", default: 0
                select ["normal", "contamination", "lawn"], var: "s#{op.id}", label: "If plate #{plate.id}.#{op.input("Plate").column + 1} is contaminated, choose contamination. If there is a lawn of colonies, choose lawn.", default: 0
            end
        end
    
    # Alter data of the actual item
        operations.output_collections["Plate"].each do |plate|
            ops_in_plate = operations.select { |op| op.output("Plate").collection == plate }
            
            section_num_colonies = Array.new(4) do |idx|
                op = ops_in_plate.find { |op| op.output("Plate").column == idx }
                if op
                    plate_info["n#{op.id}".to_sym]
                else
                    nil
                end
            end
            section_status = Array.new(4) do |idx|
                op = ops_in_plate.find { |op| op.output("Plate").column == idx }
                if op
                    plate_info["s#{op.id}".to_sym]
                else
                    nil
                end
            end

            # calling 'associate' for the Item, not Collection
            Item.find(plate.id).associate :section_num_colonies, section_num_colonies
            Item.find(plate.id).associate :section_status, section_status
            
            # error operations with 0 colonies
            ops_in_plate.select { |op| section_num_colonies[op.output("Plate").column] == 0 }.each do |op|
                op.error :no_colonies, "Your plate #{plate.id}.#{op.output("Plate").column + 1} has no colonies"
            end
        end
    
    # Parafilm 
        show do 
            title "Label and Parafilm"
            note "Label the plates with their item ID numbers on the side, and parafilm each one."
            note "Labelling the plates on the side makes it easier to retrieve them from the fridge."
        end
            
    # Return plates
        operations.each { |op| op.output("Plate").item.store }
        operations.store
    
    return {}
    
  end

end
