needs "Hydra Husbandry/UnverifiedHydra"

class Protocol
  
  include UnverifiedHydra
  
  def main
    
    operations.retrieve(interactive: false).make
    
    operations.each do |op|
      colonize(op)
    end
    
    return {}
    
  end
  
  # performs colonization for given operation
  def colonize(op)
    
    # read operation inputs
    old_items = op.input_array("Hydra").items
    old_object_type = old_items.first.object_type.name
    new_object_type = op.output("Hydra").item.object_type.name
    
    # Prepare operation by retrieving equipment and hydra strain items
    show do
      title "Preparation"
      
      note "Obtain the following:"
      bullet "Graduated Cylinder" if old_object_type == 'Hydra Tray'
      bullet "#{old_items.size} empty #{old_object_type.pluralize(old_items.size)}"
      bullet "Pasteur Pipette"
      
      if old_items.size == 1
        note "Obtain #{old_object_type} #{old_items.first.id} from #{old_items.first.location}"
      else
        note "Obtain the following #{old_object_type.pluralize}"
        old_items.each{|item| check "Item #{item.id} at #{item.location}"}
      end
    end
    
    # Create new item of the desired output type and store it
    if new_object_type == "Unverified Hydra Well"
      new_item = new_uvhw(op.output("Hydra").sample)
      store_uvhw(new_item)
    else 
      new_item = item = op.output("Hydra").sample.make_item new_object_type
    end
    new_item.save
    new_item.store
    
    # Move the desired number of hydra into the new item
    show do
      title "Colonize Hydra"
      
      if new_object_type == "Hydra Tray"
        note "Add 600mL of hydra medium into the new hydra tray"
      else
        note "Fill the new #{new_object_type} halfway with hydra medium"
      end
      old_items.each do |item|
        check "Pipette #{op.input("Number of Hydra").val} hydra from item #{item.id} in the new #{new_object_type}"
      end
      note "Label the new #{new_object_type} with the id <bf>#{new_item.id}</bf>"
      note "Place the new #{new_object_type} into 18C incubator"
    end
    
    # Ask which old items are empty
    data = show do
      title "Select Empty Item(s)"
      if old_items.size == 1
        note "Select whether the old #{old_object_type} is empty"
      else
        note "Select which of the old #{old_object_type.pluralize} are empty"
      end
      old_items.each do |item|
        select [ "not empty", "empty" ], var: "item#{item.id}", label: "Item #{item.id}", default: 1
      end
    end
    empty_items = old_items.select{|item| data["item#{item.id}".to_sym] == "empty"}
    
    # sak the user to clean the empty items, then delete them
    if empty_items.size > 0
      
      if old_object_type == "Hydra Tray"
        show do
          title "Bleach #{"Tray".pluralize(empty_items.size)}"
          note "Rinse the following #{"tray".pluralize(empty_items.size)} with 10% bleach solution"
          empty_items.each{ |item| check "Item #{item.id}" }
        end
        empty_items.each{|item| item.mark_as_deleted}
      end
      
      if old_object_type == "Hydra Dish"
        show do
          title "Toss #{"Dish".pluralize(empty_items.size)}"
          note "Toss the following #{"dish".pluralize(empty_items.size)} into the biohazard rubbish"
          empty_items.each{ |item| check "Item #{item.id}" }
        end
        empty_items.each{|item| item.mark_as_deleted}
      end
      
      if old_object_type == "Unverified Hydra Well"
        empty_items.each{|item| store_uvhw(item)} if debug
        empty_items.each{|item| remove_uvhw(item)}
        bleach_empty_uvhp()
      end
    end

  end  
  
end