#O. de Lange, June 2017. 
class Protocol

    
  def main

    operations.retrieve.make
    
    operations.each do |op|
        op.output("Overnight").item.location = "30 C shaker incubator"
        op.output("Overnight").item.save
      end
    
    #Relevant if new antiobiotic need to be made later on
    yeb_400 = find(:item, {sample:{name: "YEB medium"}, object_type:{name: "400 mL Liquid"}}).first 
    
    show do
      title "Label test tubes"
      note "Go to media preparation area"
      check "Take #{operations.length} 14 ml Test #{"tube".pluralize(operations.length)} and put them in a rack"
      check "Write down the following ids on the cap of each test tube using dot labels:"
        operations.each do |op|
            check "#{op.output("Overnight").item.id}"
        end
    end
    
    #Creates new hashes containing the operations of each antibiotic type
    gent_overnights = operations.select { |op| op.output("Overnight").sample.properties["Agro Selection"] == "Gentamycin"}
    spec_overnights = operations.select { |op| op.output("Overnight").sample.properties["Agro Selection"] == "Spectinomycin"}
    kan_overnights = operations.select { |op| op.output("Overnight").sample.properties["Agro Selection"] == "Kanamycin"}
    
    
    # SPEC OVERNIGHTS
    if spec_overnights.empty? == false
        yeb_spec = find(:item, {sample:{name: "YEB Gent + Spec"}, object_type:{name: "200 mL Liquid"}}).first
            if yeb_spec.nil? == false
                    show do
                        title "Retrieve bottle of YEB Rif/Gent/Spec"
                        note "Go to the Plant room and retrieve bottle #{yeb_spec.id} from the fridge"
                        note "No need to put on plant room PPE if you are just accessing the fridge"
                    end
            end
            
            if yeb_spec.nil? == true
                yeb_spec_liquid = produce new_sample "YEB Gent + Spec", of: "Media", as: "200 ml Liquid"
                yeb_spec_liquid.location = "Plant room fridge"
                yeb_spec_liquid.save
                show do 
                    title "Thaw Antiobiotics to make YEB Rif/Gent/Spec liquid medium"
                    check "thaw a tube of Spectinomycin"
                    check "thaw a tube of Gentamycin"
                    check "Retrieve a tube of 5 mg/ml Rifampicin (should already be liquid)"
                    warning "Wear gloves while handling antibiotics"
                end
        
                show do
                    title "Make YEB Rif/Gent/Spec liquid medium"
                    check "Take a clean 250 ml bottle and label #{yeb_spec_liquid.id}, 'YEB Rif/Gent/Spec'"
                    check "Pour in 100ml of YEB liquid medium from #{yeb_400.id}"
                    check "Add 100 µl of Spectinomycin"
                    check "Add 100 µl of Gentamycin"
                    check "Vortex the tube of Rifampicin and then add 200 µl"
                    note "Seal bottle and invert 7x to mix"
                end
            end
                
            show do
                title "Prepare tubes of YEB Rif/Gent/Spec"
                note "Use a pipetteboy and seriological pipette to transfer 2 mL of YEB Rif/Gent/Spec into each of the following tubes"
                spec_overnights.each do |sp|
                    check "#{sp.output("Overnight").item.id}"
                end
            end
            
            show do 
            title "Inoculate YEB Rif/Gent/Spec tubes"
            bullet "Take a sterile 10 L tip and scrape up a visible blob of bacteria on the end of the tip and drop it in the media."
            warning "Take from a single colony if possible"
                    spec_overnights.each do |sp|
                check "From plate #{sp.input("Plate").item.id} into tube #{sp.output("Overnight").item.id}"
            end
        end
            
    end
    
     # KAN OVERNIGHTS
    if kan_overnights.empty? == false
        yeb_kan = find(:item, {sample:{name: "YEB Gent + Kan"}, object_type:{name: "200 mL Liquid"}}).first
            if yeb_kan.nil? == false
                    show do
                        title "Retrieve bottle of YEB Rif/Gent/Kan"
                        note "Go to the Plant room and retrieve bottle #{yeb_kan.id} from the fridge"
                        note "No need to put on plant room PPE if you are just accessing the fridge"
                    end
            end
            
            if yeb_kan.nil? == true
                yeb_kan_liquid = produce new_sample "YEB Gent + Kan", of: "Media", as: "200 ml Liquid"
                yeb_kan_liquid.location = "Plant room fridge"
                yeb_kan_liquid.save
                show do 
                    title "Thaw Antiobiotics to make YEB Rif/Gent/Kan liquid medium"
                    check "thaw a tube of Kanamycin"
                    check "thaw a tube of Gentamycin"
                    check "Retrieve a tube of 5 mg/ml Rifampicin (should already be liquid)"
                    warning "Wear gloves while handling antibiotics"
                end
        
                show do
                    title "Make YEB Rif/Gent/Kan liquid medium"
                    check "Take a clean 250 ml bottle and label #{yeb_kan_liquid.id}, 'YEB Rif/Gent/Kan'"
                    check "Pour in 100ml of YEB liquid medium from #{yeb_400.id}"
                    check "Add 100 µl of Kanamycin"
                    check "Add 100 µl of Gentamycin"
                    check "Vortex the tube of Rifampicin and then add 200 µl"
                    note "Seal bottle and invert 7x to mix"
                end
            end
                
            show do
                title "Prepare tubes of YEB Rif/Gent/Kan"
                note "Use a pipetteboy and seriological pipette to transfer 2 mL of YEB Rif/Gent/Spec into each of the following tubes"
                kan_overnights.each do |k|
                    check "#{k.output("Overnight").item.id}"
                end
            end
            
            show do 
            title "Inoculate YEB Rif/Gent/Kan tubes"
            bullet "Take a sterile 10 L tip and scrape up a visible blob of bacteria on the end of the tip and drop it in the media."
            warning "Take from a single colony if possible"
                    kan_overnights.each do |k|
                check "From plate #{k.input("Plate").item.id} into tube #{k.output("Overnight").item.id}"
            end
        end
            
    end
    
    #GENT OVERNIGHTS
    
    if gent_overnights.empty? == false
        yeb_gent = find(:item, {sample:{name: "YEB Gent"}, object_type:{name: "200 mL Liquid"}}).first
            if yeb_gent.nil? == false
                    show do
                        title "Retrieve bottle of YEB Rif/Gent"
                        note "Go to the Plant room and retrieve bottle #{yeb_gent.id} from the fridge"
                        note "No need to put on plant room PPE if you are just accessing the fridge"
                    end
            end
            
            if yeb_gent.nil? == true
                yeb_gent_liquid = produce new_sample "YEB Gent", of: "Media", as: "200 ml Liquid"
                yeb_gent_liquid.location = "Plant room fridge"
                yeb_gent_liquid.save
                show do 
                    title "Thaw Antiobiotics to make YEB Rif/Gent liquid medium"
                    check "thaw a tube of Gentamycin"
                    check "Retrieve a tube of 5 mg/ml Rifampicin (should already be liquid)"
                    warning "Wear gloves while handling antibiotics"
                end
        
                show do
                    title "Make YEB Rif/Gent liquid medium"
                    check "Take a clean 250 ml bottle and label #{yeb_gent_liquid.id}, 'YEB Rif/Gent'"
                    check "Pour in 100ml of YEB liquid medium from #{yeb_400.id}"
                    check "Add 100 µl of Gentamycin"
                    check "Vortex the tube of Rifampicin and then add 200 µl"
                    note "Seal bottle and invert 7x to mix"
                end
            end
                
            show do
                title "Prepare tubes of YEB Rif/Gent"
                note "Use a pipetteboy and seriological pipette to transfer 2 mL of YEB Rif/Gent into each of the following tubes"
                gent_overnights.each do |g|
                    check "#{g.output("Overnight").item.id}"
                end
            end
            
            show do 
            title "Inoculate YEB Rif/Gent tubes"
            bullet "Take a sterile 10 L tip and scrape up a visible blob of bacteria on the end of the tip and drop it in the media."
            warning "Take from a single colony if possible"
                    kan_overnights.each do |g|
                check "From plate #{g.input("Plate").item.id} into tube #{g.output("Overnight").item.id}"
            end
        end
            
    end

    
    show do
        title "Return media and wrap plates"
        note "Return media items to plant lab fridge"
        note "Wrap each plate in parafilm"
        operations.each do |op|
            check "#{op.input("Plate").item.id}"
        end
    end
    
    
    operations.store
    
    end

end