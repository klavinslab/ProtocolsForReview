# O. de Lange Fall 2017. 

# Context in full workflow. Fragment: Stock --> [Fragment Phosphorylation] --> Fragment: Phosphorylated stock --> [Ligation] ---> Plasmid: ligation product ---> [ E. coli transformation].


class Protocol
    BUFFER_VOL = 10 # vol of buffer in each ligase buffer aliquot
    REACTION_VOLUME = 20.0
    Fragment_fM = 500 #0.5picomoles of DNA for the phosphorylation reaction
    MIN_PIPETTE_VOL = 0.2
    
    def calc_fM(i)
        s = Sample.find_by_id(i.sample_id)
        c = i.get :concentration
        l = s.properties["Length"].to_f
        fMul = (c *1520) / l
        fMul
    end
    

    def check_concentration 
        
        fragments = operations.collect { |op| op.input("Fragment").item}.select { |f| f.get(:concentration).nil? } 
       
       if fragments.empty? == false 
            cc = show do 
                    title "Please nanodrop the following fragment stocks"
                    note "Please nanodrop the following fragment stocks:"
                    fragments.each do |f|
                    note "#{f}"
                    get "number", var: "c#{f.id}", label: "#{f} item", default: 42
                    end
                end
        end
        
        fragments.each do |f|
            f.associate :concentration, cc["c#{f.id}".to_sym] #Convert string to symbol so it can be associated.
        end
    end
    
    def target_volumes
        operations.each do |op|
            frag_fm = calc_fM(op.input("Fragment").item)
            if frag_fm < 30.0
                op.associate :target_vol, 17.5
                op.associate :water_vol, 2.5
                op.plan.associate :warning, "The concentration of your input Item was too low. 17.5µl were used for the reaction but efficiency for the ligation may be low"
            else
                op.associate :target_vol, Fragment_fM/calc_fM(op.input("Fragment").item).round(1)
                op.associate :water_vol, 17.5-(op.get(:target_vol).round(1))
            end
        end
    end
    
    def check_volumes
        vols = show do 
            title "Check volumes"
            operations.each do |op|
                select ["Yes","No"], var: "vol_#{op.id}", label: "Are there at least #{op.get(:target_vol).round(1)} ul of DNA prep?"
            end
        end
        
        
        operations.each do |op|
            if vols["vol_#{op.id}".to_sym] == "No"
                show do
                    note "There is insufficient volume to carry out the reaction for operation #{op.id}. The user will be prompted to resubmit with a new fragment stock"
                end
            op.error :volume_insufficient, "There is insufficient volume to carry out this reaction. Please prepare another fragment stock."
            end
        end
    end
  

    def main
        
        show do 
            title "Fragment phosphorylation overview"
            note "In this protocol you will be preparing a DNA phosphorylation reaction. An Enzyme called DNA Kinase will transfer a phosphate ion from ATP onto any free DNA end presented to it."
            note "You will mix together fragment DNA, enzyme and an ATP-containing buffer and incubate at 37°C"
        end
        
        operations.retrieve
        
        check_concentration
        
        target_volumes
        
        check_volumes
        
        operations.running.make
        
        show do
            title "Label tubes"
            note "Take #{operations.running.length} 1.5ml tubes and label as follows"
              operations.running.each do |op|
              check "#{op.output("Phosphofragment").item.id}"
            end
        end
 
 #Make it tubes of ligase buffer in the normal enzyme containers. Just make a whole bunch more. 
       ligase_buffer_batch = Collection.where(object_type_id: ObjectType.find_by_name("T4 Ligase Buffer Aliquot").id).reject { |i| i.location == "deleted" }
       
       show do
          title "Thaw ligase buffer"
            check "Take an aliquot from the ligase buffer batch #{ligase_buffer_batch.first.id} at #{ligase_buffer_batch.first.location}"
            check "Leave on your bench to thaw"
            warning "Return box to freezer as soon as aliquot retrieved. This buffer is sensitive to freeze/thaw cycles"
        end
        
        # ligase_buffer_batch.first.subtract_one Sample.find_by_name("T4 DNA Ligase Buffer"), reverse: true
        
        show do
            title "Load water"
            table operations.running.start_table
                .output_item("Phosphofragment", heading: "Tube ID", checkable: true)
                .custom_column(heading: "MG H20(µl)"){|op| op.get(:water_vol).round(1)}
            .end_table
        end
        
        show do
            title "Load ligase buffer"
            note "Don't need to change tips"
            note "2µl into each well"
            warning "Check buffer has thawed properly. There should be no solid white flakes. If necessary, vortex till clear"
            operations.running.each do |op|
                check "#{op.output("Phosphofragment").item.id}"
            end
        end 
        
        show do
            title "Load DNA"
            warning "change tips each time"
            table operations.running.start_table
                .input_item("Fragment")
                .output_item("Phosphofragment", heading: "Tube ID", checkable: true)
                .custom_column(heading: "DNA(µl)"){|op| op.get(:target_vol).round(1)}
            .end_table
        end
      
        enzyme =  find(:item, { sample: { name: "T4 Polynucleotide Kinase" }, object_type: { name: "Enzyme Stock" } } )
        
        

        take [enzyme.first], interactive: false
        
        show do
            title "Load kinase"
            note "Take tube rack, p10 pipette and tips to the sample storage area (freezer bay)"
            check "Grab the freezer box containing the kinase enzyme from #{enzyme.first.location}. Keep it in it's freezer box."
            check "Add 0.5µl kinase enzyme to each reaction:"
            operations.running.each do |op|
                check "#{op.output("Phosphofragment").item.id}"
            end
            check "Return the freezer box with enzyme inside into the M20"
        end

        
        release [enzyme.first], interactive: false
       
        show do
            title "Incubate reactions"
            check "Close tube lids"
            check "Spin down reactions for a few seconds in tabletop mini-centrifuge"
            check "Place in 37°C incubator"
            check "<a href='https://www.google.com/search?q=google+timer+2+hours&oq=google+timer+2+hrs&aqs=chrome.1.69i57j0j69i64.6215j0j7&sourceid=chrome&ie=UTF-8' target='_blank'>
                Set a 2 hr timer on Google</a> to set a reminder to take out the reactions in 2 hrs."
        end
        
        operations.running.each do |op|
            op.output("Phosphofragment").item.location = "37°C Incubator"
            op.output("Phosphofragment").item.save
        end
      
        operations.running.store
  
    end

end
