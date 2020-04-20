class Protocol

OUTPUT = "Enzyme mix"
WORK_BAY = "DAWGMA work bay, on shelf above work bench"
CHEM_BAY = "the shelf with solid chemicals, opposite fume hood"
LARGE_FRIDGE_DOOR = "inside door of fridge R1"
SMALL_FRIDGE = "small fridge next to the the autoclave"
CONTAINER = "15 mL Falcon Tube"
DISH = "plastic weigh boat"
HEAT = true
FILTER = false
PRE_HEAT_TEMP = 50
 
RECIPE = [
    {:type => "liquid", :name => "MES pH 5.7", :amount => 10, :unit => "mL", :location => WORK_BAY, :format => "250 mL glass bottle with tape-label"},
    {:type => "solid", :name => "Calcium chloride", :amount => 0.01, :unit => "g", :location => CHEM_BAY, :format => "White plastic bottle"} ,
    {:type => "solid", :name => "Cellulase R-10", :amount => 0.15, :unit => "g", :location => LARGE_FRIDGE_DOOR, :format => "Small brown glass bottle"}, 
    {:type => "solid", :name => "Macerozyme R-10", :amount => 0.04, :unit => "g", :location => LARGE_FRIDGE_DOOR, :format => "Small brown glass bottle" }, 
    {:type => "solid",:name => "Bovine Serum Albumin", :amount => 0.01, :unit => "g", :location => SMALL_FRIDGE , :format => "White plastic bottle with red cap"}
    ]


    
    STORAGE = "Storage_Temp"

  def main
    
    operations.retrieve.make
    
    associate_data
    
    label_tubes
    
    prepare_digestion_fluid(RECIPE)
    
    set_location(STORAGE)

    operations.store

    {}

  end
    
    ##-------------------------------------------## 
      def associate_data
            operations.each do |op|
              op.output(OUTPUT).item.associate :storage_temp, op.input(STORAGE).val
            
            #Checks associations
                # show do
                #     note "This is #{op.output(OUTPUT).item.id}storage temp #{op.output(OUTPUT).item.associations}"
                # end
            end
        end

    ##-------------------------------------------## 

    def set_location(loc)
        
        operations.each do |op|
            op.output(OUTPUT).item.location = op.input(loc).val
            op.output(OUTPUT).item.save
        end
        
    end
  
    def label_tubes
      
         show do 
            title "Label a #{CONTAINER} for each operation"
            check "Get #{operations.length} #{CONTAINER}(s)"
            operations.each do |op|
                check "Label a #{CONTAINER} #{op.output(OUTPUT).item.id}"
            end
        end
    
    end
  
  
  def prepare_digestion_fluid(recipe)
        
        buffer = recipe.select{|i| i[:type] == "liquid"}[0]
        chems = recipe.select{|i| i[:type] == "solid"}
        
        operations.each do |op|
            op.output(OUTPUT).item.associate :digestion_mix_recipe, recipe
            op.associate :digestion_mix_recipe, recipe
        end
        
        show do 
            title "Retrieve a glass beaker"
            check "A glass beaker at least #{operations.length * 25} mL"
        end
    
        show do 
            title "Add buffer"
            note "Retrieve #{buffer[:name]} from #{buffer[:location]}"
            check "Add #{operations.length * buffer[:amount]} #{buffer[:unit]} to the glass beaker with a seriological pipette or measuring cylinder"
            note "Move to balance area, bring computer with you"
            if HEAT then check "Place into bead bath, set to #{PRE_HEAT_TEMP} C" end
        end
        
        show do 
            title "Retrieve solid chemicals"
            chems.each do |c|
                check "Retrieve #{c[:name]} from #{c[:location]}"
            end
        end
        

        show do 
            title "Weigh out solid chemicals into #{DISH}"
            note "Use a clean spatula for each chemical"
            note "Weigh onto weighing paper and then add each chemical to a #{DISH}"
            chems.each do |c|
                check "#{(operations.length * c[:amount]).round(2)} #{c[:unit]} of #{c[:name]}"
            end
            note " Once finished clean the balance area with a paper towel wet with distilled water"
        end
            
        show do 
            title "Add chemicals to the glass beaker"
            check "Add chemicals to glass beaker"
            note "The solution should be a clear brown"
        end
        
        show do 
            title "Return solid chemicals"
            chems.each do |c|
                check "Return #{c[:name]} to #{c[:location]}"
            end
        end
        
        show do 
            title "Dispense enzyme mix"
            check "Using a seriological pipette, pipette the contents of the beaker up and down 7 times to ensure it is well mixed"
            note "Dispense the following:"
            operations.each do |op|
                check "#{buffer[:amount]} #{buffer[:unit]} into tube #{op.output(OUTPUT).item.id}"
            end
        end
        
    end

end
