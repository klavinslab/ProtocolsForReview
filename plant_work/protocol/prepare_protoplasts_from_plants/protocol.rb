needs "Standard Libs/UploadHelper"
needs "Standard Libs/AssociationManagement"
needs "Standard Libs/Feedback"
needs "Plant work/Protoplast methods"

class Protocol
    

    DIRNAME="<where are gel files on computer>"
    TRIES=3
    include UploadHelper, AssociationManagement
    include Feedback 
    include Harvesting
    
    INPUT = "Plants"
    OUTPUT = "Digesting Cells"
    ENZYMES = "Cell wall mix"
    HARVEST_TYPE = "Tissue_slices?"
    
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
        
        harvest_plant_material
        
        associate_data
    end
    
    def incubate_enzyme_mix
        
        show do 
            title "Warm up enzyme mix(es)"
            note "Prewarm the following tubes of enzyme mix in a 55C bead bath for 15 minutes"
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
    
    def gather_plant_material
        
        show do 
            title "Gather plants for  tissue harvesting"
            note "Gather the following and bring to the #{HARVEST_LOC}"
            operations.each do |op|
               check "#{op.input(INPUT).item.id}"
            end
        end
    end
    
    def harvest_plant_material
        
        ops = operations.running
        arab_ops = ops.select{|op| op.input(INPUT).sample.sample_type.name == "Arabidopsis line"}
        arab_slice_ops = arab_ops.select{|op| op.input(HARVEST_TYPE).val == "No"}
        arab_clump_ops = arab_ops.select{|op| op.input(HARVEST_TYPE).val == "Yes"}
        duck_ops = ops.select{|op| op.input(INPUT).sample.sample_type.name == "Duckweed line"}
        duck_whole_ops = duck_ops.select{|op| op.input(HARVEST_TYPE).val == "No"}
        duck_slice_ops = duck_ops.select{|op| op.input(HARVEST_TYPE).val == "Yes"}
        slice_ops = ops.select{|op| op.input(HARVEST_TYPE).val == "Yes"}
        
        incubation_method = INCUBATION
        

        show do 
            title "Check timer on the Enzyme mix"
            note "Have the enzyme mix(es) been pre-warming for #{ENZYME_WARM_MINS} minutes? If not, wait before proceeding"
        end
        
        show do 
            title "Gather materials"
            check "#{operations.running.length} clean petri dishes. Don't have to be sterile"
            check "Tweezers"
            unless arab_ops.empty?
                check "A pair of scissors. <b>Sharpen the scissors</b> in the portable sharpener by pushing the open scissors through the slots and then closing as you pull back through. Repeat 10 times"
                check "Clean the scissors with 70% ethanol and dry with a Kimwipe"
            end
            unless slice_ops.empty?
                check "A box of fresh razorblades"
                check "A chopping board"
            end
        end
        
        show do 
            title "Label petri dishes"
            note "Write on small strips of tape and use to label the petri dishes with the following IDs:"
            operations.each do |op|
                check "#{op.output(OUTPUT).item.id}"
            end
        end
        
        arab_slice_ops.each do |op|
            harvest_arabidopsis_leaves(op)
        end
        
        arab_clump_ops.each do |op|
            harvest_arabidopsis_clumps(op)
        end
        
        duck_whole_ops.each do |op|
            harvest_duckweed_whole_plants(op)
        end
        
        duck_slice_ops.each do |op|
            harvest_sliced_duckweed(op)
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
        
        operations.each do |op|
            op.input(ENZYMES).item.mark_as_deleted
            op.input(ENZYMES).item.save
            op.output(OUTPUT).item.associate(:enzyme_start, Time.zone.now)
            jars = op.input(INPUT).item
            jars.mark_as_deleted
            jars.save
        end
        
    end
    
    def set_location(loc)
        
        operations.each do |op|
            op.output(OUTPUT).item.location = loc
            op.output(OUTPUT).item.save
        end
        
    end
    
end    
