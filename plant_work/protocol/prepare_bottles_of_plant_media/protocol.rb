## Updated 8.8.19 based on recommendations from file:///Users/Orlando/Downloads/phytagelgeling.pdf

needs "Plant Work/Plant_Media_Recipes"

class Protocol
    include Recipes
    OUTPUT = 'Media'
    
#Library with the recipes
  def main

    operations.retrieve.make
    
    get_volumes
    
    label_bottles
    
    prepare_media
    
    clean_and_autoclave
        
    {}

  end
  
    def clean_and_autoclave
      
        show do
            title "Place in autoclave"
            warning "Ensure vessel lids are only loosely placed on top of jars, not screwed on"
            note "Add autoclave tap to each vessel, from lid to jar"
            note "Place vessels in the 'to be autoclaved' bin next to the autoclave'"
        end
        
        show do 
            title "Inform lab manager"
            note "Let a lab manager know that you have prepared this media to be autoclaved"
        end
        
        show do 
            title "Clean up"
            check "Thoroughly clean up media bay and balance with distilled water, then spray and wipe down bench top with 70% ethanol"
        end
        
    end
  
  def get_volumes
      
        operations.each do |op|
            if op.output(OUTPUT).item.object_type.name.include?("400") then op.associate :vol, 400
            elsif op.output(OUTPUT).item.object_type.name.include?("200") then op.associate :vol, 200
            end
        end      
  end
  
    def label_bottles
      medium = operations.select{|op| op.output(OUTPUT).object_type.name.include?("200")}
      large = operations.select{|op| op.output(OUTPUT).object_type.name.include?("400")}
      
      bottles = [{:ops => medium, :size => "250"},{:ops => large, :size => "500"}]
    
        show do 
            title "Retrieve bottles"
            bottles.each do |b|
                unless b[:ops].nil?
                    check "Retrive #{b[:ops].length} #{b[:size]} mL glass bottles"
                    note "Label #{b[:size]} mL bottles"
                    b[:ops].each do |i|
                      check "#{i.output(OUTPUT).item.id} #{i.output(OUTPUT).sample.name}"
                    end
                end
            end
        end
    end
      
      
    def prepare_media
        
        operations.each do |op|
            
            assign_recipe(op)
            
            gather_materials(op)
            
            mix_ingredients(op)

            adjust_ph(op)
            
            decant_into_bottle(op)
        end
    
    end
    
    def assign_recipe(op)
        
        media_sample = op.output(OUTPUT).sample
        if debug then media_sample = [Sample.find(31984),Sample.find(34390),Sample.find(34411),Sample.find(34412)].sample end
        
        recipe_hash = {31984 => MS_1, 34390 => SH1, 34411 => SH2, 34412 => SH3}
        recipe = recipe_hash[media_sample.id]
        
        if recipe.nil?
            op.error :wrong_media_sample, "The Media sample submitted in Plan #{op.plan.id}  is not a valid input for Operation Type #{op.operation_type.name}."
        end
        
        op.associate :recipe, recipe
    end    
        
    def gather_materials(op)
        
        vol = op.get(:vol)
        recipe = op.get(:recipe)

        show do 
            title "Gather materials"
            check "Gather a clean glass beaker with a volume at least #{vol * 1.2} mL. Label #{op.output(OUTPUT).item.id}" #Some extra volume added to ensure there's room for mixing without spilling
            note "Gather reagents"
            recipe[:ingredients].each do |i|
                if i[1] != nil
                    check "Retrieve #{i[1][:name]} from #{i[1][:location]}"
                end
            end
        end
        
    end
    
    
    def mix_ingredients(op)
        
        vol = op.get(:vol)
        recipe = op.get(:recipe)
        
        show do 
            title "Add water and stir without heating"
            note "Add roughly #{vol - (vol.to_f/5)} mL of ddH20 to  beaker #{op.output(OUTPUT).item.id}"
            check "Add a magnetic stir bar and stir at high speed but <b> do not heat </b> (important if media ingredients include Phytagel)" #Heating will cause the phytagel to solidify prematurely. 
        end
        
        show do 
            title "Add media ingredients into  beaker"
            note "Weigh out solid ingredients at balance carefully"
            if recipe[:ingredients][:gelling_agent] != nil
                warning "Add #{recipe[:ingredients][:gelling_agent][:name]} last, once the other ingredients are well suspended (they likely will not dissolve). Add #{recipe[:ingredients][:gelling_agent][:name]} slowly, to avoid clumps forming"
            end
            recipe[:ingredients].each do |i|
                if i[1] != nil
                    check "#{i[1][:amount] * vol} #{i[1][:units]} of #{i[1][:name]}"
                end
            end
        end
        
        show do 
            title "Return media ingredients"
            recipe[:ingredients].each do |i|
                if i[1] != nil
                    check "Return #{i[1][:name]} from #{i[1][:location]}"
                end
            end
        end

        
        recipe_record = []
        recipe[:ingredients].each do |i| 
            if i[1] != nil
                recipe_record.push("#{i[1][:amount] * vol} #{i[1][:units]} of #{i[1][:name]}")
            end
        end
        
        op.output(OUTPUT).item.associate :recipe, recipe

    end
    
    
    def adjust_ph(op)
        
        vol = op.get(:vol)
        recipe = op.get(:recipe)

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
        
        op.output(OUTPUT).item.associate :ph, ph["z"]
        
        show do 
            title "Make up the volume"
            note "Transfer media from beaker to measuring cylinder"
            note "Add distilled water to #{vol}"
        end
        
        show do 
            title "Return materials"
            check "Return the pH meter"
            note "Rinse with distiled water, dry with kimwipe and return to box"
        end
    end
    
    def decant_into_bottle(op)
        
        show do 
            title "Transfer to bottle"
            note "Ensure solid ingredients are fully dissolved or well suspended before transfering"
            note "Use a funnel if you are unsure of your ability to pour cleanly from a beaker to a bottle"
            check "Pour entire contents of beaker #{op.output(OUTPUT).item.id} into glass bottle #{op.output(OUTPUT).item.id}"
        end
    end

end