# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

    def main
        
    selections = operations.map { |op| op.output("Large Volume").sample.properties["Agro Selection"] }
    gent = selections.count "Gentamycin"
    spec = selections.count "Spectinomycin"
    kan = selections.count "Kanamycin"
    gent_tubes = gent.to_f / 10
    spec_tubes = spec.to_f / 10 
    gent_overnights = operations.select { |op| op.output("Large Volume").sample.properties["Agro Selection"] == "Gentamycin"}
    spec_overnights = operations.select { |op| op.output("Large Volume").sample.properties["Agro Selection"] == "Spectinomycin"}
    kan_overnights = operations.select { |op| op.output("Large Volume").sample.properties["Agro Selection"] == "Kanamycin"}
    #Find all 400 mL Liquid items of YEB medium
    yeb = find(:item, {sample: {name: "YEB medium"}, object_type: {name: "400 mL Liquid"}})
    #Create an array composed of all the id numbers of those items, converted from symbols to strings.
    yeb_ids = yeb.collect {|y| y.id.to_s}
    
    
            operations.retrieve.make
    
            show do
                title "Thaw antibiotics for selective medium"
                note "Go to the media bay"
                check "Thaw #{spec_tubes.ceil} tubes of Ampicillin, and #{gent_tubes.ceil} tubes of Gentamycin"
                warning "Wear gloves to handle antibiotics"
            end
            
            show do 
                title "Label flasks"
                check "Grab #{operations.length} 250 ml <b>baffled</b> conical #{"flask".pluralize(operations.length)}"
                note " Label flasks with the following:"
                operations.each do |op|
                    check "#{op.output("Large Volume").item.id}   #{DateTime.now.month}/#{DateTime.now.day}"
                end
            end
            
            show do
                title "Measure out YEB medium into flasks"
                note "Using a measuring cylinder add 100 ml of YEB to each flask"
                  operations.each do |op|
                    check "#{op.output("Large Volume").item.id}"
                end
            end
            
            show do 
                title "Add Gentamycin to flasks"
                note "Add 100 l of Gentamycin stock to each flask"
                 operations.each do |op|
                    check "#{op.output("Large Volume").item.id}"
                end
            end
            
            if kan_overnights.empty? == false || spec_overnights.empty? == false
                show do
                        title "Add Spec or Kan"
                        kan_overnights.each do |go|
                            check "Add 100 l Spectinomycin stock to flask #{go.output("Large Volume").item.id}"
                        end
                        spec_overnights.each do |go|
                            check "Add 100 l Kanamycin stock to flask #{go.output("Large Volume").item.id}"
                        end
                    end
            end
            
            show do
                title "Inoculate flasks"
                note "Pour the contents of the overnight culture into the corresponding flask according to the following table:"
                table operations.start_table
                .input_item("Overnight", heading: "Overnight")
                .output_item("Large Volume", heading: "Flask label", checkable: true)
                .end_table
            end
            
            show do 
                title "Clean up"
                check "Place flasks in 30 C shaker"
                check "Discard overnight cultures in rack by the cleaning sink"
            end
            
            # yeb_discard = show do
            #     note "Did you use up any of these items?"
            #     select yeb_ids, var: "xy", label: "Did you use up any of these items?", default: 0
            # end
            
            # show do
            #     note "#{yeb_discard[:xy]}"
            # end
      
            # # trash = yeb.select {|y| y.id == yeb_discard[:xy].to_sym}
            # yeb_to_discard = yeb.select { |y| y.id == yeb_discard[:xy] }
            
            # # yeb_discard[:xy]
            
            # show do
            #     note "#{yeb_to_discard.first.id}"
            # end
            
            # yeb_to_discard.mark_as_deleted
            # yeb_to_discard.save
            
            operations.each do |op|
                op.output("Large Volume").item.location = "30 C shaker incubator"
                op.output("Large Volume").item.save
                op.input("Overnight").item.mark_as_deleted
                op.input("Overnight").item.save
            end
        
            operations.store
    
    end

end