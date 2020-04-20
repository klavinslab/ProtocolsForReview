#O. de Lange, July 2017. 
class Protocol
    


    def make_yeb_gent
        new_yeb_gent = produce new_sample "YEB Gent", of: "Media", as: "200 ml Liquid"
            #Makes a list of 400ml YEB liquid medium items
        yeb_400 = Sample.find_by_name("YEB medium")
        liquid_400 = ObjectType.find_by_name("400 ml Liquid")
        yeb_400_bottles = yeb_400.items.select { |i| i.object_type_id == liquid_400.id }
        show do 
            title "Thaw Gentamycin"
            note "Thaw a tube of Gentamycin"
            warning "Wear gloves while handling antibiotics"
        end
        
        show do
            title "Make YEB gent liquid medium"
            note "Take a clean 250 ml bottle and label #{new_yeb_gent} 'YEB Gent'"
            note "Pour in 100ml of YEB from #{yeb_400_bottles.first}"
             check "Add 100µl of Gentamycin"
            check "Add 200µl of 5 mg/ml Rifampicin"
            note "Seal bottle and invert 7x to mix"
        end
    end

    def get_yeb_gent
        yeb_gent = Sample.find_by_name("YEB Gent")
        liquid = ObjectType.find_by_name("400 ml Liquid")
        yeb_gent_liquid = yeb_gent.items.select { |i| i.object_type_id == liquid.id }
            if yeb_gent_liquid.empty? == true
                make_yeb_gent
            elsif yeb_gent_liquid.empty? == false
                show do
                    note "Take YEB gent bottle #{yeb_gent_liquid.first.item.id} from the fridge"
                end
            end
    end

    
    def make_yeb_spec
        new_yeb_spec = produce new_sample "YEB Gent + Spec", of: "Media", as: "200 ml Liquid"
            #Makes a list of 400ml YEB liquid medium items
        yeb_400 = Sample.find_by_name("YEB medium")
        liquid_400 = ObjectType.find_by_name("400 ml Liquid")
        yeb_400_bottles = yeb_400.items.select { |i| i.object_type_id == liquid_400.id }
        show do 
            title "Thaw Spectinomycin"
            note "thaw a tube of Spectinomycin"
            warning "Wear gloves while handling antibiotics"
        end
        
        show do
            title "Make YEB spec liquid medium"
            note "Take a clean 250 ml bottle and label #{new_yeb_spec}, 'YEB Gent + Spec'"
            note "Pour in 100 ml from #{yeb_400_bottles.first}"
            note "Add 200 µl of Spectinomycin (Final conc. = 100g/ml)"
            check "Add 100 µl of Gentamycin"
            check "Add 200 µl of 5 mg/ml Rifampicin"
            note "Seal bottle and invert 7x to mix"
        end
    end
    
    def get_yeb_spec
        yeb_spec = Sample.find_by_name("YEB Gent + Spec")
        liquid = ObjectType.find_by_name("200 ml Liquid")
        yeb_spec_liquid = yeb_spec.items.select { |i| i.object_type_id == liquid.id }
            if yeb_spec_liquid.empty? == true
                make_yeb_spec
            elsif yeb_spec_liquid.empty? == false
                show do
                    note "Take YEB Spec bottle #{yeb_spec_liquid.item.id.first} from the fridge"
                end
            end
    end

    def make_yeb_kan
        new_yeb_kan = produce new_sample "YEB Gent + Kan", of: "Media", as: "200 ml Liquid"
        yeb_400 = Sample.find_by_name("YEB medium")
        liquid_400 = ObjectType.find_by_name("400 ml Liquid")
        yeb_400_bottles = yeb_400.items.select { |i| i.object_type_id == liquid_400.id }
        
        show do 
            title "Thaw Gentamycin"
            note "Thaw a tube of Gentamycin"
            warning "Wear gloves while handling antibiotics"
        end
        
        show do
            title "Make YEB Gent/Kan liquid medium"
            note "Take a clean 200 ml bottle and label #{new_yeb_kan}, 'YEB Gent/Kan'"
            note "Pour in 100 ml from #{yeb_400_bottles.first}"
            note "Add 100 µl of Kanamycin"
            check "Add 100 µl of Gentamycin"
            check "Add 200 µl of 5 mg/ml Rifampicin"
            note "Seal bottle and invert 7x to mix"
        end
    end

    def get_yeb_kan
        yeb_kan = Sample.find_by_name("YEB Gent + Kan")
        liquid = ObjectType.find_by_name("200 ml Liquid")
        yeb_kan_liquid = yeb_kan.items.select { |i| i.object_type_id == liquid.id }
            if yeb_kan_liquid.empty? == true
                make_yeb_kan
            elsif yeb_kan_liquid.empty? == false
                show do
                    note "Take YEB kan bottle #{yeb_gent_liquid.item.id.first} from the fridge"
                end
            end
    end
    
  def main

    operations.retrieve.make
    
    operations.each do |op|
        op.output("Overnight").item.location = "30 C shaker incubator"
        op.output("Overnight").item.save
      end
    
    show do
      title "Label test tubes"
      note "Go to media preparation area"
      check "Take #{operations.length} 14 ml Test #{"tube".pluralize(operations.length)} in a rack"
      check "Write down the following ids on the cap of each test tube using dot labels #{operations.map { |op| op.output("Overnight").item.id}}"
    end
    
    #Creates new hashes containing the operations of each antibiotic type
    gent_overnights = operations.select { |op| op.output("Overnight").sample.properties["Agro Selection"] == "Gentamycin"}
    spec_overnights = operations.select { |op| op.output("Overnight").sample.properties["Agro Selection"] == "Spectinomycin"}
    kan_overnights = operations.select { |op| op.output("Overnight").sample.properties["Agro Selection"] == "Kanamycin"}
    
    #The following blocks check what media are needed and then generate instructions to get or make media based on methods defined at the start
    
    if gent_overnights.empty? == false
    get_yeb_gent
    end
    
    if spec_overnights.empty? == false
    get_yeb_spec
    end
    
    if gent_overnights.empty? == false
    get_yeb_kan
    end

    show do
        title "Add selective media"
        note "Use a pipetteboy and seriological pipette to transfer YEB liquid medium"
        note "2ml YEB + Antibiotic into each tube"
        table operations.start_table
            .output_item("Overnight", heading: "14ml Tube Id")
            .custom_column(heading: "Selective media", checkable: true){|op| op.input("Plate").sample.properties["Agro Selection"]}
            .end_table
        note "Gentamycin = YEB Gent. Ampicillin = YEB Gent + Amp. Kanamycin = YEB Gent + Kan"
    end
    
    show do
        title "Return media"
        note "Return media items to fridge"
    end

    show do
        title "Inoculation"
        note "Return to workbench"
        note "Inoculate Agro into test tube according to the following table."
        bullet "Take a sterile 10 L tip, pick up a medium sized colony by gently scraping the tip to the colony."
        table operations.start_table
            .input_item("Plate", heading: "Plate")
            .output_item("Overnight", heading: "14 mL Tube Id", checkable: true)
            .end_table
    end
    
    operations.store
    
    end

end

