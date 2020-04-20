class Protocol
    
    def main
    
        operations.retrieve.make
        

        i = 0
        operations.each do |op|
            i = i + op.input_array("Strains").length
        end
        
        show do 
            title "Protocol summary"
            note "In this protocol you will prepare OD600 0.16 suspensions of all strains and then mix them in a 1:1 ratio to get a final volume of 4 mL of Agro Mix"
        end
        
        show do
            title "Gather materials"
            note "For this protocol work in the main lab."
            check "A box of 1.5 ml tubes and a tube rack"
            check "p1000, p100 and p10 pipettes and tips"
            check "#{i + operations.length}  15 mL falcon tubes in a rack"
        end
        
        show do 
            title "Label falcon tubes and fill with Agro overnights"
            operations.each do |op|
                op.input_array("Strains").items.each do |s|
                    check "Label falcon #{s.id} and pour in 3 mL of culture from the corresponding overnight"
                end
            end
        end
        
        show do
            title "Pellet bacteria"
            check "Arrange falcon tubes in the large eppendorf centrifuge such that they are balanced"
            warning "If there are an odd number of tubes, use a falcon with 3 mL of water. You can damage the centrifuge otherwise"
            check "Run the centrifuge for 10 minutes at 4000 x g"
        end
        
        aim_data = show do
            title "Retrieve AIM"
            note "How old is this AIM in weeks?"
            get "number", var: "age", label: "age in weeks?", default: 2
            select ["5.5", "Undetermined"], var: "pH", label: "Was this AIM pH adjusted to 5.5", default: 0
        end
        
        operations.each do |op|
            op.plan.associate :aim_age, aim_data[:age]
            op.plan.associate :aim_ph, aim_data[:pH]
        end
      
        
        show do 
            title "Resuspend bacteria in AIM"
            check "Discard the supernatant into a bacterial waste bottle (one is located at each work bench)"
            note "Add 250 µl AIM to each tube and vortex to resuspend"
             operations.each do |op|
                op.input_array("Strains").items.each do |s|
                    check "#{s.id}"
                end
            end
        end
        
        show do
            title "Measure suspensions at the nanodrop"
            note "Start up a new instance of the Nanodrop software"
            note "Select cell cultures. Initiate with water and blank with AIM"
        end
        
 
        target = show do
            title "Choose target OD600 for each agro mix"
            operations.each do |op|
                note "What is the target OD for Agro Mix #{op.output("Mix").sample.name}?"
                get "number" , var: "cells_#{op.id}" , label: "Target" , default: 0.16
            end
        end
    
        operations.each do |op|
            op.plan.associate :agro_od, target["cells_#{op.id}".to_sym]
        end
   
        operations.each do |op|
            
            target_od = op.plan.get(:agro_od)
            
            op.input_array("Strains").items.each do |st|
                4.times do |i|
                    od =show do 
                        note "Measure OD600 of #{st.id}"
                        note "Target OD is #{target_od}"
                        note "Load 2 µl onto the pedestal and measure"
                        get "number", var: "OD600", label: "What is the OD600 of this suspension?", default: 0.2
                        note "wipe with a neatly folded kimwipe. Discard the kimwip every few measurements"
                    end
                    
                    if od[:OD600] > (target_od - 0.02) or od[:OD600] < (target_od - 0.017) then break  
                    
                    else
                        new_vol = (od[:OD600]/target_od) * 250 - 250
                        if new_vol > 0
                            show do
                                title "Adjust OD600 of suspension #{st.id}"
                                check "Add #{new_vol} µl of AIM"
                                check "Vortex to mix"
                            end
                        elsif new_vol < 0
                            show do 
                                title "You've overshot the dilution"
                                check "Pellet 1 mL bacteria from overnight culture #{st.id} in the tabletop eppendorf in a 1.5mL tube"
                                check "resuspend in 100 µl AIM and add a few µl"
                            end
                        end
                        
                    end
                end
            end
        end
    
        show do
            title "Clean nanodrop"
            note "Clean pedestal with 70% ethanol on a Kimwipe and a drop of MG H20"
            note "Dry and wipe pedestal with a kimwipe"
        end
        
        operations.each do |op|
            
            show do
                title "Prepare agro mix"
                check "Grab a clean 15ml falcon and label #{op.output("Mix").item.id}"
                check "Add 1 ml each of the following Agro suspensions:"
                strains = op.input_array("Strains").items
                    strains.each do |st|
                        check "Suspension #{st.id}"
                    end
                check "Add #{4 - op.input_array("Strains").length} additional ml of AIM"
                check "Seal and mix well by inverting 7 times"
            end
        
        end
        
        show do
            title "Leave Agro mixes to incubate"
            check "Place Agro mixes in the plant lab on the bench"
            note"<a href= 'https://www.google.com/search?q=1+hr+timer&oq=1+hr+timer&aqs=chrome..69i57j0l5.1783j0j7&sourceid=chrome&ie=UTF-8'>
                    Set a 1 hr timer on Google</a>."
        end
        
        show do
            title "Clean up"
            check "Return AIM to the plant lab fridge"
            check "Place overnights in cleaning rack next to the sink"
            check "Discard falcon tubes containing dilutions of individual strains"
        end
            
        operations.each do |op|
        strains = op.input_array("Strains").items
            strains.each do |st|
                st.mark_as_deleted
                st.save
                    end
        op.output("Mix").item.location = "Plant lab workbench"
        op.output("Mix").item.save
    end
        
        return {}
    
  end

end
