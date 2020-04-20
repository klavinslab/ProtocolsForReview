needs "Standard Libs/UploadHelper"
needs "Standard Libs/AssociationManagement"
needs "Standard Libs/Feedback"
class Protocol
    

    DIRNAME="<where are gel files on computer>"
    TRIES=3
    include UploadHelper, AssociationManagement
    include Feedback 
    
    INPUT = "Jar of plants"
    OUTPUT = "Digesting Cells"
    ENZYMES = "Cell wall mix"
    
    CHEM_BAY = "the shelf with solid chemicals, opposite fume hood"
    MEDIA_BAY = "the shelf above the balance"
    WORK_BAY = "DAWGMA work bay, on shelf above work bench"
    LARGE_FRIDGE_DOOR = "inside door of fridge R1"
    SMALL_FRIDGE = "small fridge next to the the autoclave"
    CONTAINER1 = "clean petri dish"
    CONTAINER2 = "50mL Falcon Tube"
    DISH = "plastic weigh boat"
    HEAT = true
    FILTER = false
    HAEMOCYTOMETER_COUNT = true
    PRE_HEAT_TEMP = 50
    
   
    ENZYME_WARM_MINS = 15
    INCUBATION = {:dark => true, :time => "60",  :equipment => "Orbital platform rotator", :location => "Next to the dissecting microscope", :attachment_technique => "no need to secure", :speed => 50}
    CENTRIFUGATION = {:speed => "100 x g", :time => "5 minutes", :temp => "4°C"}
    WASH = "10 mL of W5 buffer"
    STORAGE = "5 mL of sterile MMg"
    
    #Names used for harvesting input parameter and values 
    HARVEST_METHOD = "Harvesting method"
    LEAFWISE = "Leafwise"
    LEAF_NUM = 15 # Number of fully expanded leaves to harvest using the leafwise method. 
    CLUMPED = "Clumped"
    
    
    HARVEST_LOC = "Media bay" #Location where the harvsting is carried out
    VOL = 10 #mL of enzyme mix that tissue will be bathed in during digestion. 
    
    
  def main
        
        operations.retrieve({only: [INPUT]})
        
        check_for_contamination
        
        operations.retrieve({only: [ENZYMES]})
        
        incubate_enzyme_mix
        
        operations.running.make
        
        gather_materials
        
        harvest_plant_material
        
        unless operations.running.empty?
            
            isolate_protoplasts
            
            set_location(SMALL_FRIDGE)
            
            operations.store
            
        end
        
        associate_data
    end
    
    def incubate_enzyme_mix
        
        show do 
            title "Warm up enzyme mix(es)"
            note "Prewarm the following tubes of enzyme mix in a 55°C bead bath for 15 minutes"
            note "Move on to the next step once tubes are in the bead bath and the timer is started"
            operations.running.each do |op|
                bullet "Tube #{op.input(ENZYMES).item.id}"
            end
            timer initial: { hours: 0, minutes: ENZYME_WARM_MINS, seconds: 0}
        end
    end
    
    def associate_data
        
        operations.each do |op|
            
            #Age and storage location of enzyme mixes
            enzymes = op.input(ENZYMES).item
            if debug 
                age_secs = 345600
            else
                age_secs = Time.zone.now - enzymes.created_at
            end
            age_days = (age_secs / 86400).round(0) #Seconds in a day
            op.output(OUTPUT).item.associate :age_of_enzyme_mix_days, age_days
            enzymeLoc = op.input(ENZYMES).item.location
            op.output(OUTPUT).item.associate :enzyme_Location, enzymeLoc
            
            #Age of harvested plants
            plants = op.input(INPUT).item
            if debug 
                age_secs = 345600
            else
                age_secs = Time.zone.now - plants.created_at
            end
            age_days = (age_secs / 86400).round(0) #Seconds in a day
            op.output(OUTPUT).item.associate :age_of_plants, age_days
            
            #Enzyme digestion time
            op.output(OUTPUT).item.associate :enzyme_end, Time.zone.now
            date1 = Time.parse(op.output(OUTPUT).item.associations["enzyme_end"])
            date2 = Time.parse(op.output(OUTPUT).item.associations["enzyme_start"])
            incubationTime = date1 - date2            
            op.output(OUTPUT).item.associate :enzyme_incubation_time, incubationTime
        end

   end
    
    def check_for_contamination
        
            contamination = show do 
                title "Contamination Check"
                check "Take each jar in turn, open the lid, and check for signs of visible microbial growth. Particularly any white fluffy mold. Place the lid back on each jar after you have checked it"
                operations.each do |op|
                    note "Is jar #{op.input(INPUT).item.id} contaminated"
                    select ["yes","no"], var: "#{op.input(INPUT).item.id}_jar" , label: "YES or NO", default: 1
                end
            end
            
            operations.each do |op|
                contamination_status = contamination["#{op.input(INPUT).item.id}_jar".to_sym]
                op.input(INPUT).item.associate :contamination, contamination_status
                if op.input(INPUT).item.associations["contamination"] == "yes"
                    show do
                        title "Discard Jar"
                        note "Set jar #{op.input(INPUT).item} aside to be discarded, move on to the next operation."
                    end
                    op.error :contamination, "This jar is contaminated"
                end
            end
        
    end
    
    def gather_materials
        
        show do 
            title "Gather materials for plant tissue harvesting"
            note "Gather the following and bring to the #{HARVEST_LOC}"
            check "#{operations.running.length} clean petri dishes"
            check "A pair of fine scissors"
            check "Portable sharpener for scissors"
            check "A box of fresh razorblades"
            check "A chopping board"
            check "Tweezers"
            note "Jars of plants:"
            operations.each do |op|
               check "#{op.input(INPUT).item.id}"
            end
        end
    end
    
    def harvest_plant_material
        
        incubation_method = INCUBATION
        
        show do 
            title "Label petri dishes"
            note "Write on small strips of tape and use to label the petri dishes with the following IDs:"
            operations.each do |op|
                check "#{op.output(OUTPUT).item.id}"
            end
        end
        
        show do 
            title "Check timer on the Enzyme mix"
            note "Have the enzyme mix(es) been pre-warming for #{ENZYME_WARM_MINS} minutes? If not, wait before proceeding"
        end
        
        show do 
            title "Sharpen scissors"
            check "<b>Sharpen the scissors</b> in the portable sharpener by pushing the open scissors through the slots and then closing as you pull back through. Repeat 10 times"
            check "Clean the scissors with 70% ethanol and dry with a Kimwipe"
        end
        
        operations.running.each do |op|
            
            show do
                title "Harvest leaves from jar #{op.input(INPUT).item.id}"
                check "Put on gloves, or if already wearing gloves clean with 70% ethanol"
                check "Pour #{VOL} mL from #{op.input(ENZYMES).object_type.name} #{op.input(ENZYMES).item.id} into petri dish #{op.output(OUTPUT).item.id}"
                check "Place petri dish #{op.output(OUTPUT).item.id} on a balance. TARE the balance."
                check "Place the chopping board in front of you"
                note "<b> Work quickly on the following step </b>"
                check "Using tweezers pull up one or a few plants at a time from Jar #{op.input(INPUT).item.id}. Using the scissors cut all fully expanded adult leaves onto the chopping board. Repeat till all leaves have been cut from all leaves"
            end
            
            harvest = show do 
                title "Process leaf tissue"
                warning "Work carefully with the razorblade. Dispose in Sharps container immediately after use. Do not leave lying around"
                note "Use the blade to pull the leaf material into a central clump and then chop in one direction along the clump and the other, repeat up to three times"
                check "Take a fresh razor blade to quickly and finely chop the leaves harvested in the previous step into thin strips"
                check "Use the blade to scrap leaf tissue into dish of enzyme mix #{op.output(OUTPUT).item.id}. Swirl lightly to wet all leaf material"
                check "Discard the razorblade into a sharps container"
                note "Record the leaf mass harvested"
                get "number", var: :leafmass, label: "Enter the exact value of the leaf mass", default: 2.0
            end
            
            show do 
                title "Finish up harvesting"
                check "Clean the chopping board with water and 70% ethanol"
                check "Take petri dish off the balance. Place lid on top and wrap in aluminum foil (Place the foil under the dish and then fold on top)."
            end
                
            op.output(OUTPUT).item.associate :leafMass, harvest[:leafmass]
    
            op.input(ENZYMES).item.mark_as_deleted
            op.input(ENZYMES).item.save
            op.output(OUTPUT).item.associate(:enzyme_start, Time.zone.now)
            jars = op.input(INPUT).item
            jars.mark_as_deleted
            jars.save
                
        end
            
        show do 
            title "Incubate cells while digesting"
            check "Secure into #{incubation_method[:equipment]} #{incubation_method[:location]} and set to #{incubation_method[:speed]} rpm"
            check "Set yourself a timer for #{incubation_method[:time]}"
            note "While waiting proceed to next steps"
        end
        
        show do 
            title "Tidy work area"
            check "Discard jars of plants. Scoop out and discard agar and any remaining plant material using a paper towel into the Biohazard waste. Place jars and lids in cleaning bucket next to sink"
            operations.each do |op|
                check "#{op.input(INPUT).item.id}"
            end
            check "Wipe down balance and surrounding area with water and then 70% ethanol"
            check "Clean and return all implements used for harvesting"
        end
        
    end

    
    # ________________________________________________________________________________

    def isolate_protoplasts
        
        buffer = {:volume => "10 mL", :name => "W5", :long_name => "glass bottle of sterile W5 medium", :location => "Shelf above microscope with other protoplast prep materials",:wash_vol => 1}
        strainer = {:name => "mesh strainer", :long_name => "100 uM nylon mesh strainer", :location => "plastic bag on shelf above microscope",:wash_vol => 1}
        water = {:name => "sterile water", :long_name => "Glass bottle of sterile ddH20", :location => "Shelf above microscope with other protoplast prep materials",:wash_vol => 1}
        items = [buffer ,strainer, water]
        rinse_solutions = [buffer,water]
        
        show do 
            title "Retrieve materials to isolate protoplasts"
            note "Retrieve the following:"
            items.each do |i|
                check "#{i[:long_name]} from #{i[:location]}"
            end
            check "#{operations.length} clean and sterile #{CONTAINER2}(s)"
        end
        
        show do
            title "Prepare the Rinse"
            check "Take a spare petri dish (ususally in the box with the scissors), clean with 70% ethanol and ddH20"
            rinse_solutions.each do |r|
                check "Add #{2 * r[:wash_vol]} mL of #{r[:name]} to the spare petri dish."
            end
        end
        
        show do
            title "Preset Centrifuge Temp"
            note "Set large Sorvall centrifuge to #{CENTRIFUGATION[:temp]}"
        end
        
        show do 
            title "Prepare to strain protoplasts"
            note "Prepare #{operations.length} #{CONTAINER2}(s) in a rack"
            note "Label with item numbers:"
            operations.each do |op|
                check "#{op.output(OUTPUT).item.id}"
            end
            check "Take #{operations.length} fresh #{strainer[:name]}"
            check "Moisten strainer(s) with a 1:1 mix of W5 and sterile water (you can make a few mL in a clean petri dish and wipe the strainers through this)"
            check "Place strainers in #{CONTAINER2}(s)"
        end
        
        show do 
            title "Add #{buffer[:name]} to Protoplasts"
            note "Add #{buffer[:volume]} of #{buffer[:name]} to each #{CONTAINER1} of protoplasts using a seriological pipette" 
            operations.each do |op|
                check "#{op.output(OUTPUT).item.id}"
            end
             warning "Hold the #{CONTAINER1} at an angle and touch the tip of the pipette to the side, forming a slow trickle as you dispense. This gentle treatment will keep the protoplasts intact"   
        end
            
        show do 
            title "Strain protoplasts"
            note "With the tube held at an angle, slowly pour the cells through the #{strainer[:name]}"
            note "Afterwards remove #{strainer[:name]}, seal #{CONTAINER2} with protoplasts and discard empty #{CONTAINER1} into the Biohazard waste"
            operations.each do |op|
                check "#{op.output(OUTPUT).item.id}"
            end
        end
    
        show do 
            title "Pellet protoplasts"
            check "Set large Sorvall centrifuge to #{CENTRIFUGATION[:speed]}, #{CENTRIFUGATION[:time]}."
            check "Add all #{CONTAINER2}s of protplasts, balance as required with tube(s) of water"
            check "Hit Run"
        end
        
        show do 
            title "Wash"
            check "Use a seriological pipette to carefully remove and discard supernatant from each #{CONTAINER2}"
            check "Add #{WASH}. Gently invert until fully mixed"
            check "Set large Sorvall centrifuge to #{CENTRIFUGATION[:speed]}, #{CENTRIFUGATION[:time]}, #{CENTRIFUGATION[:temp]}"
            check "Add all #{CONTAINER2}s of protplasts, balance as required with tube(s) of water"
            check "Hit Run"
            check "Once run is finished, remove tubes and reset the temperature on the centrifuge to 24°C"
        end
        
        show do 
            title "Add storage buffer"
            check "Remove and discard supernatant from each #{CONTAINER2} slowly and carefully with a seriological pipette"
            check "Add #{STORAGE} to each #{CONTAINER2} slowly and carefully with a seriological pipette"
            check "Place tubes in the fridge until needed"
        end
    end
    
    def set_location(loc)
        
        operations.each do |op|
            op.output(OUTPUT).item.location = loc
            op.output(OUTPUT).item.save
        end
        
    end
    
end    
