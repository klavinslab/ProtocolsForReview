class Protocol
    
    INPUT = "Jar"
    

  def main

    operations.retrieve.make
    
    prepSeedlings
    
    deleteItems
    
  end  
    
    
    def prepSeedlings
            
        show do
            title "Gather Equipment"
            check "Please gather a couple sorting dishes to put the sprouts in as you count them."
            check "Get yourself a pair of tweezers (Or two if you want)"
        end
        
        operations.each do |op| #Eveything is put in one loop so that the technician can folllow the whole procedue through with one Jar at a time
            
            show do# With tweezers remove all seedlings and seeds into seperate petri dishes
                note "Use the tweezers to remove seeds and sprouts from #{op.input(INPUT).item.id} and place them into the sorting dishes to be counted."
                warning "Make sure to take note of any seeds stuck to the sprouts."
            end
            
            sprout_verified = "No"
            
            n = 0
            
            while sprout_verified == "No"
                
                sproutCounts = show do
                    title "Count the sprouts which have germinated"
                    get "number", var: "#{op.input(INPUT).item.id}_sprouts", label: "Enter the # of gernminated seedlings", default: -1 #rand(10..50)
                end
                
                verification = show do 
                    title "Verification"
                    note "You have entered #{ sproutCounts["#{op.input(INPUT).item.id}_sprouts".to_sym]} as the number of germinated seedlings"
                    select ["Yes", "No"], var: :x, label: "Are you sure?", default: 1
                end
                
                sprout_verified = verification[:x]
                n = n + 1
                if n > 3 then break end
            end
            
            n = 0
            seeds = -1
            while seeds < 0
                seedCounts = show do
                    title "Count the ungerminated seeds."
                    get "number", var: "#{op.input(INPUT).item.id}_seeds", label: "Enter the # of ungerminated seeds", default: -1 #Fix this so they cant enter a negative number
                end
                
                seeds = "#{seedCounts["#{op.input(INPUT).item.id}_seeds".to_sym]}"
                seeds = seeds.to_i
                
                if seeds < 0
                    show do
                        title "That doesn't seem right..."
                        note "You set your seed count to #{seeds.to_i} please enter a POSITIVE number."
                    end
                end
                
                n = n + 1
                if n > 3
                    show do
                        title "FINE! Have it your way..."
                        note "ThERes a nEgAtiVE nUMbeR oF SeEds on mY pLAte.  <--- You apparently"
                    end
                    break
                end
            end
            
            
            contamination = show do      # Inspect each petri dish under dissecting scope for signs of microbial growth
                title"Contamination Check"
                note "Does the petri dish show any signs of contamination"
                select ["yes","no"], var: "#{op.input(INPUT).item.id}_dish" , label: "YESNO", default: 1
                note "Does the jar show signs of microbial growth"
                select ["yes","no"], var1: "#{op.input(INPUT).item.id}_jar" , label: "YESNO", default: 1 #Theses output to the same variable
                

            end
            
            show do    
                title"Clean up workspace"
                check "Scrape seeds and sprouts back into the jar you got them from." #May change in later vesions of the protocol
                check "Clean the sorting dish and tweezers."
                note "Set everything aside aside to dispose of later."
            end
            
            # Associate the data with the input item 
            op.input(INPUT).item.associate :germ_count, sproutCounts["#{op.input(INPUT).item.id}_sprouts".to_sym]
            op.input(INPUT).item.associate :seed_count, seedCounts["#{op.input(INPUT).item.id}_seeds".to_sym]
            op.input(INPUT).item.associate :contamination, contamination["#{op.input(INPUT).item.id}_jar".to_sym]
            op.input(INPUT).item.associate :contamination, contamination["#{op.input(INPUT).item.id}_dish".to_sym]

            
        #   #Debug
        #     if debug
        #         show do
        #             title "DEBUG"
        #             note "This your sprout count#{sproutCounts}"
        #             note "This is your seed count #{seedCounts}"
        #             warning "This is contamination level:#{contamination}"
        #         end
        #     end
        end
    end
    
    def deleteItems# Delete the input items from the inventory e.g. operations.each{|op| op.input(INPUT).item.mark_as_deleted}
        show do
            operations.each do |op| 
                op.input(INPUT).item.mark_as_deleted
                note "Please dispose of all plant material and media from #{op.input(INPUT).item.id} in the biohazard waste."
                note "Take all glass containers and petri dishes to the sink bin to be washed."
            end
        end
    end
    

    # Iterate through each operation in the Job (operations.each)
    
    # Instructions to check for germination and contamination
            # With tweezers remove all seedlings and seeds into seperate petri dishes
            # Record how many of each. http://klavinslab.org/aquarium/api/Krill/ShowBlock.html#get-instance_method (We could use this to check germination if we are interested)
            # Inspect each petri dish under dissecting scope for signs of microbial growth
            # Inspecting remaining media in jar for signs of microbial growth
    
    # Ask the tech if there is any contamination and record answer. Yes or No.
        #http://klavinslab.org/aquarium/api/Krill/ShowBlock.html#select-instance_method
 
    
    # Instructions to dispose of all contents by scooping into biohazard waste with paper towel. Then place jar in cleaning bucket. 
    
    # Associate the data with the input item 
    
    # Delete the input items from the inventory e.g. operations.each{|op| op.input(INPUT).item.mark_as_deleted}
    
    def stuff
        colors = ["blue","red","green"]
        colors.each do |c|
            show do 
                note "#{c}"
            end
        end
        
        operations.each do |op|
            show do 
                note "#{op.input(INPUT).item.id}"
            end
        end
        
     
        value = show do 
            operations.each do |op|
                select ["yes","no"], var: "#{op.input(INPUT).item.id}" , label: "YESNO", default: 0
            end
        end
        
        
        operations.each do |op|
            op.input(INPUT).item.associate :key, value["#{op.input(INPUT).item.id}".to_sym]
        end
    end


end