

class Protocol

  def main

    operations.retrieve.make
  
    show do 
        title "Take tissue to the media bay to weigh"
        note "Place lids on petri dishes"
        note "Take the petri dishes and the chromebook to the media bay"
    end
    
    show do
        title "Label falcon tubes"
        note "Take #{operations.length} falcon tubes and label as follows"
        operations.each do |op|
            check "#{op.output("Pool").item.id}"
        end
    end

    
    operations.each do |op|
        
        show do 
            title "Weigh and combine samples for pool #{op.output("Pool").item.id}"
            note "The plant tissue items for this pool are: #{op.input_array("Plants").item_ids}"
            note "Take them to the balance in the media bay"
        end
        
       masses = show do 
            title "Weigh plant tissue items"
            note "Zero the balance with a clean plastic weighing boat. Pour in the contents of each petri dish one at a time and record the mass before emptying into falcon tube #{op.output("Pool").item.id}"
             op.input_array("Plants").items.each do |plant|
                    note "Weigh dish #{plant.id} and enter mass in grams (enter only number, no units)"
                    get "number", var: "mass_#{plant.id}", label: "What's the mass", default: 0.5
                end
        end
        
        i = 0
        op.input_array("Plants").items.each do |plant|
            plant.associate :biomass, masses["mass_#{plant.id}".to_sym]
            i = i +  plant.get(:biomass)
        end
        
        op.output("Pool").item.associate :pooled_biomass, i
    
    end

    operations.each do |op|
        if op.input("Control group?").val == "Yes"
            op.output("Pool").item.associate :experiment_role, "control"
        else
            op.output("Pool").item.associate :experiment_role,  "treatment"
        end
    end
    
    show do
        title "Clean up"
        note "Discard all empty petri dishes into biohazard waste"
        note "Discard empty weighing boats into biohazard waste"
        note "Place falcon tubes in a rack"
        note "Wipe surfaces of media bay with DI water"
    end
   

        
    operations.store interactive: false
    
    return {}
    
  end

end
