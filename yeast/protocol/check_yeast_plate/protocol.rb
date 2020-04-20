# Author: Ayesha Saleem
# December 20, 2016

# TO DO: 
    # Create option for "there are baby colonies but they're not big enough for protocols" case--put back in incubator
    # Re-streak the plate if there's too much contamination--fire check plate again in 24 hrs, probably collection
needs "Standard Libs/Feedback"
class Protocol
include Feedback
  def main
    t_inc = 30
    # Take plates  
    operations.retrieve
    
    # Count the number of colonies and select whether the growth is normal, contaminated, or a lawn
    info = estimate_colony_numbers
    
    # show do 
    #   note "#{info[:choice]}"
    # end

    # Alter data of the actual item
    alter_item_data info

    # Delete and discard any plates that have 0 colonies
    delete_plates

    ops_to_incubate = operations.select { |op| op.temporary[:re_incubate] }
    # Re-incubate the following plates
    re_incubate_plates ops_to_incubate

    # Parafilm 
    label_and_parafilm

    # Return plates
    operations.store
    get_protocol_feedback
    return {}
  end
  
  # This method lets the technician estimate colony numbers on plates and returns the value.
  def estimate_colony_numbers  
    info = show do
      title "Estimate colony numbers"
      
      operations.each do |op|
        plate = op.input("Plate").item
        get "number", var: "n#{plate.id}", label: "Estimate how many colonies are on #{plate}", default: 5
        select ["normal", "contamination", "lawn", "there are tiny baby colonies that need growin'"], var: "s#{plate.id}", label: "Choose whether there is contamination, a lawn, colonies that need to be further incubated, or the colonies are normal."
      end
    end
    info #return
  end
  
  # This method iterates through every option and determines if there are 
  # colonies on each operation's plate. If there are no colonies, the plate item
  # is marked as deleted and the operation errors. If there are colonies, then
  # the number of colonies and status of each plate will be associated to the plate.
  def alter_item_data info
    operations.each do |op|
      plate = op.input("Plate").item
      if info["n#{plate.id}".to_sym] == 0
        plate.mark_as_deleted
        plate.save
        op.temporary[:delete] = true
        op.error :no_colonies, "There are no colonies for plate #{plate}"
      else
        if info["s.#{plate.id}".to_sym] == "there are tiny baby colonies"
          op.temporary[:re_incubate] = true
        end
        plate.associate :num_colonies, info["n#{plate.id}".to_sym]
        plate.associate :status, info["s#{plate.id}".to_sym]
        plate.store
        plate.reload
        op.pass("Plate", "Plate")
      end
    end
  end
  
  # This method tells the technician to discard plates.
  def delete_plates
    show do 
      title "Discard Plates"
      
      discard_plate_ids = operations.select { |op| op.temporary[:delete] }.map { |op| op.input("Plate").item.id }
      note "Discard the following plates with 0 colonies: #{discard_plate_ids}"
    end if operations.any? { |op| op.temporary[:delete] }
  end
  
  # This method tells the technician to re-incubate plates. It also sets the status
  # of the operation's plate item to pending and it's location to pending. 
  def re_incubate_plates ops_to_incubate
    if !ops_to_incubate.blank? 
        show do 
            title "Re-Incubate"
            note "The following plates will be re-incubated, so set them aside for now:"
            note "#{ops_to_incubate.map { |op| op.input("Plate").item.id }.join(",")}"
        end
        ops_to_incubate.each do |op|
            plate = op.input("Plate").item
            op.set_status "pending"
            plate.location = "#{t_c} C incubator"
            plate.save
        end
    end
  end
  
  # This method tells the technician to label and parafilm plates.
  def label_and_parafilm
    show do 
        title "Label and Parafilm"
        
        plates_to_parafilm = operations.reject { |op| op.temporary[:delete] || op.temporary[:re_incubate] }.map { |op| op.input("Plate").item.id }
        note "Perform the steps with the following plates: #{plates_to_parafilm.join(",")}"
        note "Label the plates with their item ID numbers on the side, and parafilm each one."
        note "Labelling the plates on the side makes it easier to retrieve them from the fridge."
    end
  end
end
