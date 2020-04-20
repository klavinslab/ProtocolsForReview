needs "Plant Work/Plant work General"
needs "Plant Work/Plant work Training"

# Section 1 = Prepare GUS staining solution
# Section 2 = Harvest and vaccuum infiltrate
# Section 3 = Place in incubator and clean up
# Section 4 = Calculating how long the Agro was incubated in the plant


class Protocol

    include General    
    
    def main
    
        standard_PPE
        
        show do 
            title "Gather items"
            note "Size 3 Corkborer"
            note "1.5ml tubes and rack"
        end
        
        gus_stain =  Item.where(object_type_id: ObjectType.find_by_name("Screw Cap Tube").id).select {|i| i.sample.name == "GUS staining solution"}.reject { |i| i.location == "deleted" }

            make_gus = show do
                title "Do you need to prepare new GUS staining solution?"
                note "The following GUS staining solution items are currently available?"
                note "You'll be carrying out #{operations.length} GUS stain operations but the total volume needed will be dependent on whether you pool samples from different plants or keep them seperate"
                    gus_stain.each do |gs|
                        note "#{gs.id} at #{gs.location}"
                        note "age #{(((Time.zone.now - gs.created_at) / 604800).round)}" 
                    end
                select ["Yes", "No"], var: "choice", label: "Discard these and make more?", default: 0
            end
        
        if  make_gus[:choice] == "No"
            
            tube_to_use = show do 
                note "Which tube will you use?"
                get "number", var: item_id, label: "Enter Item ID", default: gus_stain.first.id
            end
            
            gus_used = Item.find(tube_to_use[:item_id])
            
        else
                
            if gus_stain.empty? == false
                show do 
                    title "First discard the old tubes"
                    gus_stain.each do |gs|
                        check "Discard tube #{gs.id} into autoclave waste"
                        gs.mark_as_deleted
                        gs.save
                    end
                end
            end
            
            show do
                title "Gather materials"
                note "Grab the Sodium phosphate buffer from the plant lab fridge then leave the plant lab and gather the following in the Media Bay"
                check "Reagents B and C from Sigma Beta-Glurconidase Reporter gene staining kit (red box, Small Freezer 2)"
                check "A small bottle of MG H20"
                check "Pipette boy + 2 5ml tip + 1 10ml tip"
                check "p100 + tips"
                check "15ml screw top tube (falcon tube) + rack"
            end
            
            show do 
                title "Add non-toxic ingredients"
                check "Place falcon tube in a stable tube rack"
                check "2.5 ml of Reagent A (Sodium phosphate buffer)"
                check "10 µl of Reagent B"
                check "10µl of Reagent C"
                check "5.5 ml of MG H20"
            end
        
            show do 
                title "Add methanol"
                check "Don lab coat and gloves if not wearing already"
                check "Take falcon tube to lab coat in rack to the fume hood"
                check "Open the fume hood and turn on the light"
                check "Retrive a bottle of methanol from under the fume hood"
                check "Use pipette boy + seriological pipette to add <b>2 ml of Methanol</b>"
                check "Seal bottle and return to cupboard." 
                check "Close fume hood and return to media bay"
            end
            
            show do 
                title "Add GUS substrate"
                check "Add 20µl of X-GlcA solution"
                check "Seal and invert tube 7 times"
            end
            
            gus_used = produce new_sample "GUS staining solution", of: "Reagent", as: "Screw Cap Tube"
             
            show do
                title "Wrap and label"
                check "Wrap the tube in foil"
                    operations.each do |op|
                    check "On a piece of tape write: #{gus_used.id}, initials, date"
                    end
                check "Fix tape onto tube"
            end
            
            show do
                title "Clear bench"
                check "Return GUS reagents"
                check "Wipe down work area with 70% ethanol"
            end
            
               
               
                gus_used.location = "Plant lab fridge"
                gus_used.save
                
        end
   
        operations.each do |op|
            op.associate :gus_stain_used, gus_used.id
        end
    
    #### Section 2: Harvesting leaf discs and vaccuum infiltration
    
        operations.make
        
        operations.each do |op|
            show do
                title "Harvest leaf discs from plants 1-3 of tray #{op.input("Plants").item.id}"
                check "Take tray #{op.input("Plants").item.id} and place in front of you"
                check "Label a 1.5 mL tube #{op.output("Leaf discs").item.id} and place in a tube rack in front of you"
                note "Place corkborer aperture flat against one side of an infiltrated leaf spot. Press a paper towel against the other side"
                note "Extract the leaf disc by rotating the corkborer while applying pressure"
                check "Repeat for all infiltrated spots. If desired extract multiple leaf discs from each spot"
                check "Push leaf discs out of the corkborer into tube #{op.output("Leaf discs").item.id} using the metal rod"
            end
            
            show do 
                title "Vaccuum infiltrate"
                check "Add 750 µl of GUS staining solution to tube #{op.output("Leaf discs").item.id}"
                check "Push end of 10 mL blunt end syringe into the opening of the 1.5 mL tube"
                check "Pump up and down"
                note "You will see the leaf disc change from having a metallic sheen on its surface to looking uniformly dark. That indicates complete infiltration"
            end
        end
    
    
    #### Section 3: Place in incubator and clear away materials
        show do
                title "Tidy up"
                  check "Place all tubes in one tube rack and put to one side"
                check "Plants in incinerator waste (Blue bin)"
                check "Spray trays and with 70% ethanol and wipe clean with paper towels"
                check "Clean worksurface"
                check "Put away corkborer"
            end
        
        show do 
            title "Place tubes of infiltrated plant material in the 37 incubator"
            check "Remove your PPE"
            check "Place tube rack in the 37°C incubator in the main lab"
        end
        
        operations.each do |op|
            op.output("Leaf discs").item.location = "37°C Incubator"
            op.output("Leaf discs").item.save
            op.input("Plants").item.mark_as_deleted
            op.input("Plants").item.save
            op.output("Leaf discs").item.associate :plant_genotype, op.input("Plants").item.get(:plant_genotype)
        end
    
    #### Section 4
    
        operations.each do |op|
          incubation_time = hours_old op.input("Plants").item
          op.plan.associate :incubation_time, incubation_time
            show do 
              note "#{incubation_time}"
            end
        end
            
            
       
        
        return {}
    
    end
end