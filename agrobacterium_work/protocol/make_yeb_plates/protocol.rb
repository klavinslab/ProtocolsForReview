
class Protocol
    
  def main

# How many plates of each type?

    plates = show do 
        title "How many plates of each type would you like to make?"
        get "number", var: "spec", label: "How many Gent/Spec plates?", default: 2
        get "number", var: "kan", label: "How many Gent/Kan plates?", default: 3
        get "number", var: "gent", label: "How many Gent plates?", default: 4
    end
    
    rif_refill = show do
        title "Check rifampicin"
        select ["Yes", "No"], var: "refill_rif_stock", label: "Are there at least #{plates[:spec] + plates[:kan] + plates[:gent]}µl of 5 mg/ml Rifampicin stock?", default: 1
    end
    
    if rif_refill[:refill_rif_stock] == "No"
            show do 
                title "Prepare rif stock"
                check "Put on lab coat, gloves, safety goggles and face mask"
                check "Weigh out 100 mg of Rifampicin powder in a plastic weighing boat with a disposable spatula"
                warning "Antibiotic powders are hazardous if swallowed, so exercise caution but fume hood unnecessary"
                check "Pour into a 15ml faclon tube"
                check "Dissolve in 10ml of <b>100% ethanol</b>. It isn't soluble in water"
                note "You can vortex as necessary or warm to 37C if it doesn't dissolve instantly"
                note "It will be bright red. And it stains. Be careful"
                check "Dispense into 7-10 1.5 ml tubes and label 'Rif 5 mg/ml'"
            end
            
            show do 
                title "Put away Rifampicin"
                check "Clean up the balance area"
                note "As with all solid chemicals use ddH20 to wipe the balance area and clean equipment. Discard any waste into the normal trash, not autoclave waste"
                check "Return rifampicin powder"
                check "Store rifampicin stocks"
            end
    end
    
    show do 
            title "Assemble what you will need"
            check "1 bottle YEB agar"
            check "1 tube Rifampicin stock solution"
            check "1 tube Gentamycin stock solution"
            check "#{plates[:spec] + plates[:kan] + plates[:gent]} petri dishes"
            if plates [:spec] != 0
                check "1 tube Spectinomycin stock solution"
            elsif plates [:kan] != 0
                check "1 tube Kanamycin stock solution"
            end
        end
    
    if plates[:spec] != 0
        
        spec_batch = produce new_collection "Agar Plate Batch"
        spec_plates = Sample.find_by_name("YEB Gent + Spec")
        plates[:spec].to_i.times {spec_batch.add_one spec_plates }
        spec_batch.location = "Plant lab fridge"
        spec_batch.save
        
        refill_spec = show do
            title "Check Spec"
            select ["Yes", "No"], var: "refill_sp_stock", label: "Are there at least #{plates[:spec] +1}l of 50 mg/ml Spectinomycin stock?", default: 1
        end
    
        
        if refill_spec[:refill_sp_stock] == "No"
            show do 
                title "Prepare Spec stock"
                check "Put on lab coat, gloves, safety goggles and face mask"
                warning "Antibiotic powders are hazardous if swallowed, so exercise caution but fume hood unnecessary"
                check "Weigh out 0.25g of Spectinomycin powder"
                check "Pour into a 15 ml falcon tube"
                check "Dissolve in 5ml of MG H20. Vortex as needed"
                check "Dispense into 5 tubes and label 'Spec'"
            end
        end
        
        show do
            title "Melt YEB agar and prepare #{plates[:spec]} YEB Gent/Spec plates"
            check "Melt YEB agar in the microwave"
            check "Allow to cool for 1 minute. The antibiotics can be destroyed by boiling temperatures"
            check "Pour #{(plates[:spec] +1) * 20} ml of molten YEB agar into a clean glass bottle"
            check "Add #{(plates[:spec] +1) * 20}µl of <b>50 mg/ml</b> Spectinomycin."
            check "Add #{(plates[:spec] +1) * 20}µl of <b>40 mg/ml</b> Gentamycin"
            check "Add #{(plates[:spec] +1) * 80}µl of <b>5 mg/ml</b> Rifampicin"
            check "Seal bottle and swirl to mix"
        end
        
        show do 
            title "Pour plates"
            check "Stack #{plates[:kan]} plates and label with a RED marker pen stripe"
            check "Lay out the petri dishes"
            check "Pour roughly 20ml into each petri dish"
            check "Swirl plate or use pipette tip to remove bubbles"
            check "Allow to cool with lids mostly on"
        end
    end
    
    if plates[:kan] != 0
        
        kan_batch = produce new_collection "Agar Plate Batch"
        kan_plates = Sample.find_by_name("YEB Gent + Kan")
        plates[:kan].to_i.times { kan_batch.add_one kan_plates }
        kan_batch.location = "Plant lab fridge"
        kan_batch.save
        
        refill_kan = show do
            title "Check Kan stock"
            select ["Yes", "No"], var: "refill_kan_stock", label: "Are there at least #{plates[:kan] +1}l of 50 mg/ml Kanamycin stock?", default: 1
        end
    
        
        if refill_kan[:refill_kan_stock] == "No"
            show do 
                title "Prepare Kan stock"
                check "Put on lab coat, gloves, safety goggles and face mask. Antibiotic powders are hazardous!"
                check "Weigh out 0.25g of Kanamycin powder"
                check "Dissolve in 5ml of MG H20"
                check "Dispense into 5 tubes and label 'Spec'"
            end
        end
        
        show do
            title "Melt YEB agar and prepare #{plates[:kan]} YEB Gent/Kan plates"
            check "Melt YEB agar in the microwave"
            check "Allow to cool for 1 minute. The antibiotics can be destroyed by boiling temperatures"
            check "Pour #{(plates[:kan] +1) * 20} ml of YEB agar into a clean glass bottle"
            check "Add #{(plates[:kan] +1) * 10}l of <b>50 mg/ml</b> Kanamycin."
            check "Add #{(plates[:kan] +1) * 20}l of <b>40 mg/ml</b> Gentamycin"
            check "Add #{(plates[:kan] +1) * 80}l of <b>5 mg/ml</b> Rifampicin"
        end
        
        show do 
            title "Pour plates"
            check "Stack #{plates[:kan]} plates and label with a GREEN marker pen stripe"
            check "Lay out #{plates[:kan]} petri dishes"
            check "Pour roughly 20ml into each petri dish"
            check "Swirl plate or use pipette tip to remove bubbles"
            check "Allow to cool with lids mostly on"
        end
        
            
    end
    
    if plates[:gent] != 0
        gent_batch = produce new_collection "Agar Plate Batch"
        gent_plates = Sample.find_by_name("YEB Gent")
        plates[:gent].to_i.times { gent_batch.add_one gent_plates }
        gent_batch.location = "Plant lab fridge"
        gent_batch.save
        
        show do
            title "Melt YEB agar and prepare #{plates[:gent]} YEB Gent/Kan plates"
            check "Melt YEB agar in the microwave"
            check "Allow to cool for 1 minute. The antibiotics can be destroyed by boiling temperatures"
            check "Pour #{(plates[:gent] +1) * 20} ml of molten YEB agar into a clean glass bottle"
            check "Add #{(plates[:gent] +1)*20}l of <b>40 mg/ml</b> Gentamycin"
            check "Add #{(plates[:gent] +1)*80}l of <b>5 mg/ml</b> Rifampicin"
        end
        
        show do 
            title "Pour plates"
            check "Stack #{plates[:gent]} plates and label with a black stripe"
            check "Lay out #{plates[:gent]} petri dishes"
            check "Pour roughly 20ml into each petri dish"
            check "Swirl plate or use pipette tip to remove bubbles"
            check "Allow to cool with lids mostly on"
        end
    end
    
    show do 
        title "Clear area"
        check "Return tubes of antiobiotic (discard empties)"
        check "Place used 250 mL glass bottles in the cleaning tub by the sink"
        check "Return any media bottles with YEB agar still left in to the solid media shelf"
        check "Wipe area with a kimwipe sprayed with 70% ethanol"
    end
    
    show do 
        title "Gather up plates and label"
        check "Gather up dried plates"
        check "Label with appropriate colored stripes for Kan or Spec"
        note  "Don't bother labeling with Rif or Gent or YEB. The fact that the plates are red is a sufficient indication"
        check "Place in the plant lab fridge together. Preferabely in a box labelled YEB rif/Gent + Spec or Kan"
    end

    
    return {}
    
  end

end
