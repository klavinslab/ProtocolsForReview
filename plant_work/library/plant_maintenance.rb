module ItemandOperationMethods

    
    def gather_by_location wizard_name
        Item.select {|i| i.location.include? "#{wizard_name}"}
    end
  
    def delayed_plan_input_check id_no, input_name, sample_type_name
        
        operations_list = Operation.where(operation_type_id: id_no).select { |op| op.status == "delayed" }
        
        ids_to_check = []
        
        operations_list.each do |op|
            ids_to_check.push op.input(input_name).item.id
        end
        
        items_to_check = Item.find(ids_to_check)
        
        items_to_check.select {|it| it.sample.sample_type == SampleType.find_by_name(sample_type_name)}

    end
    
    def move_plants plant_hash, name, wizard
        show do
            title "Move items to #{name}"
                plant_hash.each do |ph|
                    ph.move (wizard)
                    check "Move item #{ph.id} to #{name} #{ph.location}"
                end
        end
    end
    
    def items_by_location wizard_name
        my_wiz = Wizard.find_by_name(wizard_name)
        items_array = my_wiz.locators.map{|loc| loc.item}
    end
end

module WateringandChecking
        
    def gather_plant_items container_name
        Item.where(object_type_id: ObjectType.find_by_name(container_name).id).reject { |i| i.location == "deleted" }
    end
    
    def water container, wizard, instructions
        items_of_container = gather_plant_items container
        items_to_water = items_of_container.select {|i| i.location.include?(wizard)}
        
        if items_to_water.empty? == false
            show do 
                title "Water #{items_to_water.length} #{container} items in #{wizard}"
                note "watering instructions: #{instructions}"
                    items_to_water.each do |i|
                        check "Water #{i.id}, at #{i.location}"
                    end
                end
        end
    end
    
    def germination_check container, num
        species_hash = gather_plant_items container
        if species_hash.empty? == false
            species_hash_ungerminated = species_hash.select {|sh| sh.get(:germinated) != "Yes"}
            
            if species_hash_ungerminated.empty? == false
                germination_data = show do 
                    title "Check '#{container}'' items for germination"
                    species_hash_ungerminated.each do |shu|
                        note "Are there at least #{num} germinated seedlings in pot #{shu.id}, at #{shu.location}"
                        select [ "No" ,"Yes"], var: "germinated_#{shu.id}", label: "Germinated?", default: 1
                    end
                end
            
                species_hash_ungerminated.each do |shu|
                     shu.associate :germinated, germination_data["germinated_#{shu.id}".to_sym]
                end
            end
        end 
    end
    
    def bolting_trays_check container
        trays_hash = gather_plant_items container
        if trays_hash.empty? == false
            trays_data = show do 
                    title "Check #{container} items for bolting"
                    trays_hash.each do |t|
                        if t.get(:bolting) != "Yes"
                            note "Are any of the plants on tray #{t.id}, at #{t.location} bolting?"
                             select [ "No","Yes" ], var: "bolting_#{t.id}", label:"Bolting?" , default: 1
                        elsif t.get(:bolting) == "Yes"
                            note "What's the infloresence status of the plants on tray #{t.id}, at #{t.location}?"
                            select ["flowers", "green siliques"], var: "infloresence_#{t.id}", label: "Status}?", deafault: 0
                        end
                    end
            end
            
            trays_hash.each do |t|
                t.associate :bolting, trays_data["bolting_#{t.id}"]
                t.associate :infloresence, trays_data["infloresence_#{t.id}"]
            end
        end
    end
    
    def flats_check container
        flats_hash = gather_plant_items container
            if flats_hash.empty? == false
              flats_data = show do
                    title "Check infloresence status of #{container} items"
                    flats_hash.each do |f|
                        note "Check flat #{f.id} at #{f.location}"
                        select ["None","flowers", "green siliques", "dry siliques"], var: "infloresence_#{f.id}", label: "What is the infloresence status of #{f.id}?", default: 2
                    end
                end
        
                flats_hash.each do |f|
                    f.associate :infloresence, flats_data["infloresence_#{f.id}".to_sym]
                end
            end
    end
    
    def leafsize_check plant_hash, size, species
            leafsize_data = show do
                title "Check leaf sizes of #{species} plants that are going to be used for leaf infiltration"
                plant_hash.each do |ph|
                    if ph.get(:leaf_size) != "Yes"
                        note "Are there at least 2 leaves on each plant in tray #{ph.id}, at #{ph.location} with leaves bigger than #{size}?"
                        select ["No", "Yes"], var: "leafsize_#{ph.id}", label: "Leaves at least #{size}", default: 0
                    end
                end
            end
            
            plant_hash.each do |ph|
                ph.associate :leaf_size, leafsize_data["leafsize_#{ph.id}".to_sym]
            end
    end
    
    def check_selection_plates container
        selection_plates = gather_plant_items container
        fridge_plates = selection_plates.select { |sp| sp.location == "Plant room fridge" }
        fridge_plates_to_move = fridge_plates.select {|fp| days_old fp >= 2}
        if fridge_plates_to_move.empty? == false then move_plants fridge_plates_to_move, "Growth Rack 3", "GR3" end
        selection_plate_data = show do 
            title "Check T1 selection plates"
             selection_plates.each do |sp|
                 note "Have the seeds on selection plate #{sp.id} germinated? What does the plate look like?"
                select [ "No", "Yes" ], var: "germinated_#{sp.id}", label: "Are there at least 20 germinated seedlings on plate #{sp.id}?", default: 0
                select ["Fine", "Dry", "Contaminated"], var: "dried_#{sp.id}", label: "Is plate #{sp.id} dried out?", default: 0
                end
        end
        
        selection_plates.each do |sp|
            sp.associate :germinated, selection_plate_data["germinated_#{sp.id}".to_sym]
            sp.associate :plate_condition, selection_plate_data["condition_#{sp.id}".to_sym]
        end
    end
end

module PlantMaintenanceGeneral
    
    def item_comment_query
        
        comment_query = show do 
            title "Would you like to leave a comment for any item today?"
            note "Reasons could include: discarding a dead plant, contamination on a tray, or signs of stress"
            select ["Yes", "No"],var: "answer", label: "comment?", default: 0 
        end
        
        leave_a_comment = comment_query[:answer]
        i = 0
        
        until leave_a_comment == "No" or i > 9 do
            item_datum = show do
                        title "Leave a comment"
                        get "text", var: "item_number", label: "What is the item number?", default: "12345"
                        get "text", var: "item_comment", label: "What is the comment", default: "Uneven growth rate among plants on tray"
                    end
                
            comment_item = Item.find(item_datum[:item_number])
            
            confirmation = show do
                        note "You would like to leave the comment #{item_datum[:item_comment]} for item #{comment_item.id} of sample #{comment_item.sample.name}?"
                        select ["Yes", "No"], var: "confirm", label: "confirm" , default: 0
            end
            
            if confirmation[:confirm] == "Yes"
                comment_item.associate :comments, item_datum[:item_comment]
            end
            
            comment_query = show do 
                title "Would you like to leave another comment?"
                note "Reasons could include: discarding a dead plant, contamination on a tray, or signs of stress"
                select ["Yes", "No"],var: "answer", label: "comment?", default: 1 
            end
        
            leave_a_comment = comment_query[:answer]
            i = i + 1
        end
    end
    
    def op_comments
        operations.each do |op|
            op_comments = show do
                title "Would you like to leave any comments for today's maintenance operation?"
                select ["Yes" , "No" ], var: "op_comment", label: "Click yes to leave a comment", default: 0
            end
            
            if op_comments[:op_comment] == "Yes"
                comment_for_op = show do
                    title "What comment would like to leave"
                    get "text", var: "text", label: "Leave comment here", default: "Water leaking in the fridge"
                    select ["Yes", "No"], var: "pressing", label: "Would you consider this an urgent problem that needs addressing?", default: 0
                end
                op.associate :todays_comment, comment_for_op[:text]
            
                if comment_for_op[:pressing] == "Yes"
                    show do 
                        title "Call 206-960-6808 to tell Orlando about this problem"
                        title "If it's not urgent, but still important email odl@uw.edu"
                    end
                end
            end
        end
    end
    
end

module RoomMaintenance
    
    def refill_protocol
        
        show do
            title "Refill carboy with tap water"
            note "Grab the empty carboy and the rubber tubing behind it"
            note "Remove your plant room PPE (lab coat, overshoes)"
            note "Take the empty carboy to the main lab sink"
            note "Connect the tubing and refill the carboy on the floor"
            note "You can use a wheely-chair to help you carry the carboy back to the door of the plant lab"
        end
    end
    
    def clean_floor
        show do
            title "Clean the floor"
            note "Sweep up and discard debris"
            note "Use floor cleaner and mop to wipe floor clean"
        end
    end
    
    def clean_surfaces
        show do
            title "Clean the work surfaces"
            note "Tidy items away"
            note "Use dustpan and brush or mini-vacuum-cleaner to remove debris"
            note "Wipe down and spray with cleaner"
        end
    end
    
    def waste_disposal
        show do
            title "Discard and replace trash bag"
            note "Tie up the bag and place into cardboard waste box"
            note "Place a new red trash bag into the waste bin"
        end
        
        show do 
            title "Check incineration waste"
            note "Weigh the box"
            note "If it weighs <b>45-50lb<b/> seal the inner liners and seal the box with packing tape. Affix an orange shipping label and inform a lab manager. Put out a fresh cardboard box with 2 red liners inside"
        end
    end

end