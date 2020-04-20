# Author: Ayesha Saleem
# November 4, 2016
needs "Standard Libs/Feedback"
needs "Standard Libs/AssociationManagement"

class Protocol
  include Feedback
  include AssociationManagement;
  
  def main
    # Take plates  
      operations.retrieve
        
    # Output is same as input (TODO Make "pass" work for parts as well?)
      operations.each do |op|
          op.output("Plate").copy_inventory op.input("Plate")
      end
      operations.output_collections["Plate"] = operations.map { |op| op.output("Plate").collection }.uniq
        
    # Count the number of colonies and select whether the growth is normal, contaminated, or a lawn
      plate_info = get_colony_num

    # Alter data of the actual item
      alter_item_data plate_info

    # Parafilm 
      parafilm
            
    # Return plates
      operations.each { |op| op.output("Plate").item.store }
      operations.store
    
     get_protocol_feedback
    return {}
    
  end
  
  # This method asks the technician how many colonies he thinks are on each plate and returns the value.
  def get_colony_num
    plate_info = show do 
      title "Estimate colony numbers"
      
      operations.each do |op|
        plate = op.input("Plate").collection
        
        get "number", var: "n#{op.id}", label: "Estimate how many colonies are on plate #{plate.id}.#{op.input("Plate").column + 1}", default: 5
        select ["normal", "contamination", "lawn"], var: "s#{op.id}", label: "If plate #{plate.id}.#{op.input("Plate").column + 1} is contaminated, choose contamination. If there is a lawn of colonies, choose lawn.", default: 0
      end
    end
    plate_info
  end
  
  # This method alters item data and associates the number of colonies 
  # on a plate and a status to each plate.
  def alter_item_data plate_info
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
    #   Item.find(plate.id).associate :section_num_colonies, section_num_colonies
    #   Item.find(plate.id).associate :section_status, section_status
      
      AssociationMap.associate_data(plate, :section_num_colonies, section_num_colonies)
      AssociationMap.associate_data(plate, :section_status, section_status)
    end
  end
  
  # This method tells the technician to label and parafilm plates.
  def parafilm
    show do 
      title "Label and Parafilm"
      note "Label the plates with their item ID numbers on the side, and parafilm each one."
      note "Labelling the plates on the side makes it easier to retrieve them from the fridge."
    end 
  end

end
