## Updated 8.8.19 based on recommendations from file:///Users/Orlando/Downloads/phytagelgeling.pdf

needs "Plant Work/Plant_Media_Recipes"

class Protocol
    include Recipes
    PARAMETER = 'Recipe'
    OUTPUT = 'Culture Vessel'
    VOLUME = 100 #Media volume in the culture vessel 
    STORAGE_LOC = "Fridge R1"
    INPUT = "Jars"
    JAR_LOC = "drawers under grow tent, facing window"
    MEDIATYPE = "Media Type"
    
#Library with the recipes
  def main

    operations.retrieve.make
    
        ops_by_media = operations.group_by{|operation|operation.output(OUTPUT).sample}

        ops_by_media.each do |ops|
            
            recipe = check_recipes(ops)
            
            ops[1].each do |op|
                
                jars = jar_check(op)
                
                fill_collection jars, op
            
                retrieve_materials op, recipe, jars
                
                # ms_age_check
                
                mix_ingredients op, recipe, jars
                
                return_ingredients recipe ###Make this conditional on last thing
                
                adjust_ph op, recipe, jars
                
                decant_into_vessels op, jars, recipe
                
            end
        end
        
    {}

  end
  
    def fill_collection jars, op
        batch = op.output(OUTPUT).collection
        sample = op.output(OUTPUT).sample
        samples_to_add = [sample]*jars
        batch.add_samples(samples_to_add)
    end
    
    def jar_check op
        
        enough = show do
            title "Check stock level of glass jars"
            note "Check the #{JAR_LOC}"
            note "Are there at least #{ op.input(INPUT).val} sterile jars available?"
            select ["Yes","No"], var: :x, label: "Sufficient?", default: 0
        end
        
        if enough[:x] == "Yes"
            return op.input(INPUT).val
        else 
            num_jars = show do 
                title "How many are avaiable?"
                note "How many jars are available?"
                get "number", var: :x, label: "Number of jars", default: 3
            end
            
            if num_jars[:x]== 0 
                op.error :error, "No jars available to fill with media. Check with lab manager" 
            else 
                return num_jars[:x]
            end
        end
    end

    def check_recipes(ops)
        media_sample = ops[0]
        media_ops = ops[1]
        if debug then media_sample = [Sample.find(31984),Sample.find(34390),Sample.find(34411),Sample.find(34412)].sample end
        
        recipe_hash = {31984 => MS_1, 34390 => SH1, 34411 => SH2, 34112 => SH3}
        recipe = recipe_hash[media_sample.id]
        
        if recipe.nil?
            media_ops.each do |op|
                op.error :wrong_media_sample, "The Media sample submitted in Plan #{op.plan.id}  is not a valid input for Operation Type #{op.operation_type.name}."
             end
        end
        
        return recipe
    end
  
    def retrieve_materials op, recipe, jars
        
        show do 
            title "Gather and label glassware"
            note "Retrieve #{jars} glass plant culture vessels, into a basket or tub"
            note "Label vessels with a strip of tape on the lid:"
            check "Label all jars: #{op.output(OUTPUT).collection.id}"
            check "Place jars to the side, you won't need them till the end of the protocol"
        end
        
        show do 
            title "Get a container for media"
            check "Gather a clean glass beaker with a volume at least #{(jars * 100) * 1.2} mL" #Some extra volume added to ensure there's room for mixing without spilling
        end
        
        show do 
            title "Gather media ingredients"
            recipe[:ingredients].each do |i|
                if i[1] != nil
                    check "Retrieve #{i[1][:name]} from #{i[1][:location]}"
                end
            end
        end
    end
    
    def mix_ingredients op, recipe, jars
        
        conversion = jars * VOLUME 
        
        show do 
            title "Add water and stir without heating"
            note "Add roughly #{conversion - (VOLUME.to_f/5)} mL of ddH20 to the beaker"
            check "Add a magnetic stir bar and stir at high speed but <b> do not heat </b>" #Heating will cause the phytagel to solidify prematurely. 
        end
        
        show do 
            title "Add media ingredients into  beaker"
            note "Weigh out solid ingredients at balance carefully"
            if recipe[:ingredients][:gelling_agent] != nil
                warning "Add #{recipe[:ingredients][:gelling_agent][:name]} last, once the other ingredients are well suspended (they likely will not dissolve). Add #{recipe[:ingredients][:gelling_agent][:name]} slowly, to avoid clumps forming"
            end
            recipe[:ingredients].each do |i|
                if i[1] != nil
                    check "#{i[1][:amount] * conversion} #{i[1][:units]} of #{i[1][:name]}"
                end
            end
        end
        
        recipe_record = []
        recipe[:ingredients].each do |i| 
            if i[1] != nil
                recipe_record.push("#{i[1][:amount] * conversion} #{i[1][:units]} of #{i[1][:name]}")
            end
        end
        
        batch = op.output(OUTPUT).collection
        sample_parts = batch.select{|p| p == op.output(OUTPUT).sample.id}
        sample_parts.each{|p| batch.set_part_data(:recipe, p[0], p[1], recipe)}#Note each part has a row and column position, accessed as part[0] and part[1]
        sample_parts.each{|p| batch.set_part_data(:made_on, p[0], p[1], batch.created_at.to_s[0..9])}

        
    end
    
    def return_ingredients recipe
        show do 
            title "Return media ingredients"
            recipe[:ingredients].each do |i|
                if i[1] != nil
                    check "Return #{i[1][:name]} from #{i[1][:location]}"
                end
            end
        end
        
        show do
            title "Clean balance area"
            note "Wipe down balance and surfaces with distilled water on a paper towel"
        end
        
    end
    
    def adjust_ph op, recipe, jars

        ph_specs = recipe[:ph_adjustment]
        target_ph = ph_specs['target']
        base = ph_specs['adjustor']
        amount = ph_specs['starting_amount']
        # current_ph = 0.0
        # ph_delta = sqrt((target_ph - current_ph)^2)
        # n = 0
        
        ph = show do 
            title "Adjust pH to #{target_ph}"
            check "Retrieve the pH meter"
            check "Retrieve a bottle of #{base}"
            check "Check the current pH of the medium"
            note "Add #{base} <b> till the pH is between 5.8 and 6.2 </b>."
            note "Start by adding #{amount} of #{base}"
            get "number", var: "z", label: "Enter a number", default: 5.9 
        end
        
        batch = op.output(OUTPUT).collection
        sample_parts = batch.select{|p| p == op.output(OUTPUT).sample.id}
        sample_parts.each{|p| batch.set_part_data(:ph, p[0], p[1], ph["z"])}#Note each part has a row and column position, accessed as part[0] and part[1]
        
        show do 
            title "Make up the volume"
            note "Transfer media from beaker to measuring cylinder"
            note "Add distilled water to #{jars * VOLUME}"
        end
        
        show do 
            title "Return materials"
            check "Return the pH meter"
            note "Rinse with distiled water, dry with kimwipe and return to box"
        end
    end
    
    def decant_into_vessels op, jars, recipe
        
        
        show do
            title "Measure out into labelled culture vessels"
            if recipe[:ingredients][:gelling_agent] != nil
                warning "Keep the beaker on the stir plate while dispensing. This is to avoid settling of phytagel"
            end
            note "Using a 50 mL seriological pipette measure out #{VOLUME} mL of medium into each of the #{jars} glass culture vessels"
        end
        
        show do
            title "Place in autoclave"
            warning "Ensure vessel lids are only loosely placed on top of jars, not screwed on"
            note "Add autoclave tap to each vessel, from lid to jar"
            note "Place vessels in the 'to be autoclaved' bin next to the autoclave'"
        end
        
        show do 
            title "Inform lab manager"
            note "Let a lab manager know that you have prepared this media to be autoclaved and that they should be placed on the #{STORAGE_LOC} after autoclaving"
        end
        
        op.output(OUTPUT).collection.location = STORAGE_LOC
    end

end