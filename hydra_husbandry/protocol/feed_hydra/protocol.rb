needs "Hydra Transgenics/Handling"
needs "Hydra Husbandry/UnverifiedHydra"
needs "Hydra Husbandry/BrineShrimp"

class Protocol
  
  include Handling
  include UnverifiedHydra
  include BrineShrimp
  
  def main
    
    # the amounts of brine shrimp solution to add to each hydra container type
    amounts = {"Hydra Tray" => "3 pipettes",
                "Large Hydra Dish" => "3 drops",
    }
    amounts.default = "some" # default to the tech's discretion
    
    # precipitate the brine shrimp and save user timer response
    data = precipitate
    
    # prepare the brine shrimp and provide a timer if requested by the tech
    prep_shrimp(data[:timer] == "yup")
    
    # collect the brine shrimp
    collect_shrimp
    
    # feed all of the hydra in a particular and complicated order:
    
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
        feed(sample, container, items, amounts)
      end
    end
    
    # feed the unverified hydra plates last
    feed_uvhp
    
    # hatches more brine shrimp if there are not enough left
    maybe_hatch()
    
    cleanup    
    
    return {}
    
  end
  
  
  def precipitate
    data = show do
      title "Precipitate Shrimp"
      
      note "Turn off the brine shrimp air pump"
      note "Wait until the egg shells float to the top of the cone " + 
           "and the shrimp sink to the bottom (about 3 minutes)"
      select [ "yup", "nope" ], var: "timer",
                                label: "Would you like a timer?",
                                default: 1
    end
    return data
  end
  
  def prep_shrimp(need_timer)
    show do
      title "Prepare for shrimp collection"
      
      timer initial: { hours: 0, minutes: 3, seconds: 0} if need_timer
      note "While you're waiting, gather the following items:"
      bullet "Brine Shrimp Filter"
      bullet "Shrimp Collection Dish"
      note "Remove the straw from the hatching cone"
      note "Rinse it with water and ethanol"
      note "Place it in the drying area"
    end
  end  
  
  def collect_shrimp
    show do
      title "Collect shrimp"
      
      note "Pour off shells from the top of the cone into the sink"
      note "Pour shrimp through filter into sink"
      note "Rinse shrimp into each corner of tray with DI water"
      note "Invert filter over collection dish and rinse with hydra medium"
      note "Add extra hydra medium to the brine shrimp so they can be pipetted"
      note "Obtain a pasteur pipette and rubber bulb"
    end
  end 
  
  # instructs tech to feed the given items of the correponding sample and
    # container type, with the given map of amounts
  def feed(sample, container, items, amounts)
    
    # store the name of the container for convenience
    cname = container.name
    
    show do
      title "Feed #{cname.pluralize(items.size)}"
      
      note "Add #{amounts[cname]} of the shrimp to each #{cname.split.last.downcase}"
      warning "Discard the pipette if it touches the liquid" if transgenic?(sample)
      
      hydra_table = Table.new
      hydra_table.add_column("Item", items.map{|item| {content: item.id.to_s, check: true}})
      hydra_table.add_column("Location", items.map{|item| item.location.to_s})
      table hydra_table
    end
  end
  
  # feeds all feedable wells in all unverified hydra plates
  def feed_uvhp
    find_all_uvhp.each do |plate|
      show do
        title "Feed Unverified Hydra Plates"
        note "Add 1 drop of the shrimp to each well highlighted below"
        warning "Discard the pipette if it touches the liquid"
        table feedable_wells_table(plate)
      end if feedable_wells(plate)
    end
  end
  
  # if the tech wishes to make more brine shrimp, provides instructions to do so
  def maybe_hatch()
    data = show do
      title "Make more brine shrimp?"
      select [ "yup", "nope" ], var: "moreplease",
                                label: "Would you like to hatch more brine shrimp?",
                                default: 0
    end
    hatch_brine_shrimp() if data[:moreplease] == "yup"
  end
  
  # as may be anticipated from its name, this method performs cleanup duties
  def cleanup
    
    data = show do
      title "Cleanup"
      
      note "Please enter the minutes from now that you will be available for cleanup"
      get "number", var: "mins", label: "Minutes", default: 0
    end
    
    show do
      title "Cleanup"
      
      timer initial: { hours: 0, minutes: data[:mins], seconds: 0}
      note "Dispose the pipette in the glass waste"
      note "Rinse the collection dish and filter with ethanol and water"
      note "Put them in the drying area"
      note "Scrub any residue off of the hatching cone"
    end
  end
  

end