



class Protocol

  def main
      
        benthi = operations.select{|op| op.input("Pot").sample.sample_type.name == "Nicotiana benthamiana"}
        arabidopsis = operations.select{|op| op.input("Pot").sample.sample_type.name == ("Arabidopsis line" or "Arabidopsis T-DNA line")}
      
        show do
            title "Put on the appropriate PPE?"
            check "Lab coat"
            check "Overshoes"
            check "Gloves. (Working with soil dries out your skin)"
        end
        
        show do
            title "Prepare workbench"
            note "Work at the potting bench"
            check "1 clean black tray"
            check "#{operations.length} clean green #{"tray".pluralize(operations)}"
            check "#{operations.length} clean plant #{"label".pluralize(operations)}"
            if arabidopsis.empty? == false
                check "Clear plastic tub for soaking jiffy pellets"
                check "Bag of jiffy pellets"
            end
            if arabidopsis.empty? == false
                check "Tub for soil mixing"
                check "Bag of potting soil and measuring scoops"
            end
            check "500ml plastic measuring beaker"
        end
        
        if arabidopsis.empty? == false
            show do
                title "Soak jiffy pellets"
                note "Place #{arabidopsis.length * 20} jiffy pellets in a clear plastic tub"
                note "Add #{arabidopsis.length * 500} ml of tap water to the tub"
                note"<a href='https://www.google.com/search?q=5+minute+timer&oq=5+minute+t&aqs=chrome.0.0j69i57j0l4.1391j0j7&sourceid=chrome&ie=UTF-8'>
                        Set a 5 minute timer on Google</a>. Once its done the pellets should be fully soaked"
            end
        end
        
        if benthi.empty? == false
            show do
                title "Prepare soil"
                check "Add #{benthi.length * 2} large scoops of soil to a clear plastic tub"
                check "Add #{benthi.length * 200} mL of water"
                check "Add #{benthi.length} cap fulls of osmocote (fertilizer)"
                check "Mix well to evenly wet the soil. If the soil is still dry add more water. Ensure fertilizer granules are evenly distributed"
            end
        end
       
        operations.retrieve.make
        
        show do
            title "Label  trays"
            check "Take #{operations.length} clean black green plant trays"
            note "Write Item ID on label and stick onto tray"
            operations.each do |op|
                check "#{op.output("Tray").item.id}"
            end
        end

        
        if arabidopsis.empty? == false
            show do
                title "Add jiffy pellets"
                check "Add 20 pellets to each tray"
                arabidopsis.each do |op|
                    check "#{op.output("Tray").item.id}"
                 end
            end
        end
        
        arabidopsis.each do |a|
            show do
                title "Transfer seedlings from seedling pot #{a.input("Pot").item.id}"
                note "Using tweezers gently transfer one seedling into each expanded jiffy pellet in tray #{a.output("Tray").item.id}"
                warning "Avoid disturbing the roots as much as possible"
                note "Gently push soil into place around the seedling after transplanting"
            end
            
            a.output("Tray").item.associate :num_plants, 20
        end
        
        benthi.each do |b|
            show do
                title "Add soil to pots"
                check "Lay out 3 black pots in tray #{b.output("Tray").item.id}"
                check "Add 1 large scoop of soil mix to each pot"
                check "Gently press down the soil to a smooth surface that almost fills the pot"
            end
            
            show do
                title "Transfer seedlings from benthi seedling pot #{b.input("Pot").item.id}"
                note "Using tweezers gently transfer one seedling into each pot in tray #{b.output("Tray").item.id}"
                warning "Avoid disturbing the roots as much as possible"
                note "Gently push soil into place around the seedling after transplanting"
            end
            
            b.output("Tray").item.associate :num_plants, 3
        end
        
        
        show do 
            title "Discard pots"
            operations.each do |op|
                if op.input("Pot fate").val == "discard"
                    check "#{op.input("Pot").item.id}"
                    op.input("Pot").item.mark_as_deleted
                    op.input("Pot").item.save
                end
            end
        end
        
        operations.each do |op|
            if op.input("Pot fate").val == "Convert to flat"
                flat = ObjectType.find_by_name("Flat of ecotype")
                    op.input("Pots").item.object_type_id = flat.id
                    op.input("Pots").item.save
            end
            
            op.output("Tray").item.associate :provenance, op.input("Pot").item.id
        end
        
        operations.store(io: "input", interactive: true)
        operations.store(io: "output", interactive: false)
        
        show do
            title "Return trays"
            warning "Check that plants are centred in the tray (the front and back receive less light)"
            warning "Check that trays are sitting level on their shelf to avoid water pooling at one end"
            table operations.start_table
                .output_item("Tray", heading: "Tray")
                .custom_column(heading: "Location"){|op| op.output("Tray").item.location}
                .end_table
        end
        
        
        show do
            title "Clear workbench"
            check "Return bag of jiffy pellets, soaking tub and beaker"
            check "Clean work surface with 70% ethanol"
        end
    
    return {}
    
  end

end
