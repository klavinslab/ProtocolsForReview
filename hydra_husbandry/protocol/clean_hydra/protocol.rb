needs "Hydra Transgenics/Handling"
needs "Hydra Husbandry/UnverifiedHydra"

class Protocol
  
  include Handling
  include UnverifiedHydra
  
  def main
    
    # gather necessary equipment
    gather_equipment
    
    # clean all of the hydra in a particular and complicated order:
    
    # find all of the items that contain instances of SampleType Hydra Strain
      # don't include unverified hydra plates; they are handled separately below
    items = find(:item, { sample_type: { name: "Hydra Strain" } } )
    items.reject!{|item| item.object_type.name == "Unverified Hydra Well"}

    # group the items by their samples
    grouped = items.group_by{|i| i.sample}
    
    # within each sample, group the hydra by their containers
    grouped.each_key{|k| grouped[k] = grouped[k].group_by{|i| i.object_type}}
    
    # start with all of the transgenic hydra
    grouped.keys.sort{|sample| transgenic?(sample) ? 1 : 0}.each do |sample|
      grouped[sample].each do |container, items|
        
        clean_hydra(sample, container, items)
        
        # clean the filter after every transgenic sample
        clean_filter if transgenic?(sample)
        
      end
      
    end
    
    # clean all unverified hydra plates
    clean_uvhp
    
    # perform cleanup duties
    cleanup
    
    return {}
    
  end
  
  # instructs tech to gather the necessary equipment
  def gather_equipment
    show do
      title "Gather the following items"
      
      bullet "Collection dish"
      bullet "Hydra filter"
    end
  end

  # cleans the hydra in the given items with given sample and container type
  def clean_hydra(sample, container, items)
    show do
      title "Clean #{container.name.pluralize(items.size)}"
      
      note "For each #{container.name}:"
      nickname = container.name.split.last.downcase
  
      if container.name == "Unverified Hydra Well"
        bullet "Pipette out hydra medium from #{nickname} through filter"
        bullet "Rinse the #{nickname} with the hydra medium squirt bottle"
        bullet "Pipette any hydra stuck on filter back into the #{nickname}"
        bullet "Refill the #{nickname} with Hydra Medium"
      else
        bullet "Pour the #{nickname} through the filter into the beaker"
        bullet "Rinse the #{nickname} to get any shrimp out"
        bullet "Rinse any hydra in the filter back into the #{nickname}"
        if container.name == "Hydra Tray"
          bullet "Refill the #{nickname} to the 600mL mark with Hydra Medium"
        elsif container.name == "Large Hydra Dish"
          bullet "Refill the #{nickname} to the 15mL mark with Hydra Medium"
        else
          bullet "Refill the #{nickname} with Hydra Medium"
        end
        bullet "Pour the collection beaker #{transgenic?(sample) ? "into the <b>transgenic waste bucket</b>" : "down the drain"}"
      end
      
      hydra_table = Table.new
      hydra_table.add_column("Item", items.map{|item| {content: item.id.to_s, check: true}})
      hydra_table.add_column("Location", items.map{|item| item.location.to_s})
      table hydra_table
    end
  end
  
  # clean all feedable wells in all unverified hydra plates
  def clean_uvhp
    find_all_uvhp.each do |plate|
      show do
        title "Clean Plates"
        note "For each well highlighted below"
        bullet "Pipette out hydra medium from the well through the filter"
        bullet "Rinse the well with the hydra medium squirt bottle"
        bullet "Pipette any hydra stuck on filter back into the well"
        bullet "Refill the well with Hydra Medium"
        table feedable_wells_table(plate)
      end if feedable_wells(plate)
    end
  end
  
  # instructs tech to clean the filter (used after transgenic samples)
  def clean_filter
    show do
      title "Clean Filter"
      
      note "Don safety goggles"
      note "Rinse the filter with 20% bleach solution"
      note "Rinse the filter with tap water"
    end
  end
  
  # Surprise, suprrise! This method does precisely what it claims to do.
  def cleanup
    show do
      title "Cleanup"
      
      note "Add enough bleach to the waste bucket make a 10% bleach solution."
      note "Put everything away."
    end
  end

end
