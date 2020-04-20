
# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol
    INPUT = "Digesting Cells"
    OUTPUT = "TEMP OUTPUT"
    MICROSCOPE = "Microscope"
    DISCARD_ANS = "Discard tubes"
    IMAGE_REPS = 6
    DEBUG = true
    DENSITY_KEY = "density"
    
    CENTRIFUGATION = {:speed => "100 x g", :time => "5 minutes", :temp => "4C"}
    WASH = "10 mL of W5 buffer"
    STORAGE = "5 mL of sterile MMg"
    CONTAINER1 = "clean petri dish"
    CONTAINER2 = "50mL Falcon Tube"
    

  def main

    operations.retrieve.make
    
    isolate_protoplasts
    
    scope_check_density
    
    run_script
    
    discard_tubes
    
    operations.store

    {}

  end

    # ________________________________________________________________________________
    
     def isolate_protoplasts
        
        buffer = {:volume => "10 mL", :name => "W5", :long_name => "glass bottle of sterile W5 medium", :location => "Shelf above microscope with other protoplast prep materials",:wash_vol => 1}
        strainer = {:name => "mesh strainer", :long_name => "100 uM nylon mesh strainer", :location => "plastic bag on shelf above microscope",:wash_vol => 1}
        water = {:name => "sterile water", :long_name => "Glass bottle of sterile ddH20", :location => "Shelf above microscope with other protoplast prep materials",:wash_vol => 1}
        items = [buffer ,strainer, water]
        rinse_solutions = [buffer,water]
        
        operations.each do |op|
            if op.input(INPUT).item.associations["enzyme_start"]
                op.input(INPUT).item.associate(:enzyme_end, Time.zone.now)
                date1 = Time.parse(op.input(INPUT).item.associations["enzyme_end"])
                date2 = Time.parse(op.input(INPUT).item.associations["enzyme_start"])
                incubationTime = date1 - date2            
                op.input(INPUT).item.associate :enzyme_incubation_time, incubationTime
            end
        end
        
        
        show do 
            title "Retrieve materials to isolate protoplasts"
            note "Retrieve the following:"
            items.each do |i|
                check "#{i[:long_name]} from #{i[:location]}"
            end
            check "#{operations.length} clean 50 mL falcon tube(s)"
        end
        
        show do
            title "Prepare the Rinse"
            check "Take a spare petri dish (ususally in the box with the scissors), clean with 70% ethanol and ddH20"
            rinse_solutions.each do |r|
                check "Add #{2 * r[:wash_vol]} mL of #{r[:name]} to the spare petri dish."
            end
        end
        
        show do
            title "Preset Centrifuge Temp"
            note "Set large Sorvall centrifuge to #{CENTRIFUGATION[:temp]}"
        end
        
        show do 
            title "Prepare to strain protoplasts"
            note "Prepare #{operations.length} #{CONTAINER2}(s) in a rack"
            note "Label with item numbers:"
            operations.each do |op|
                check "#{op.input(INPUT).item.id}"
            end
            check "Take #{operations.length} fresh #{strainer[:name]}"
            check "Moisten strainer(s) with a 1:1 mix of W5 and sterile water (you can make a few mL in a clean petri dish and wipe the strainers through this)"
            check "Place strainers in #{CONTAINER2}(s)"
        end
        
        show do 
            title "Add #{buffer[:name]} to Protoplasts"
            note "Add #{buffer[:volume]} of #{buffer[:name]} to each #{CONTAINER1} of protoplasts using a seriological pipette" 
            operations.each do |op|
                check "#{op.input(INPUT).item.id}"
            end
             warning "Hold the #{CONTAINER1} at an angle and touch the tip of the pipette to the side, forming a slow trickle as you dispense. This gentle treatment will keep the protoplasts intact"   
        end
            
        show do 
            title "Strain protoplasts"
            note "With the tube held at an angle, slowly pour the cells through the #{strainer[:name]}"
            note "Afterwards remove #{strainer[:name]}, seal #{CONTAINER2} with protoplasts and discard empty #{CONTAINER1} into the Biohazard waste"
            operations.each do |op|
                check "#{op.input(INPUT).item.id}"
            end
        end
    
        show do 
            title "Pellet protoplasts"
            check "Set large Sorvall centrifuge to #{CENTRIFUGATION[:speed]}, #{CENTRIFUGATION[:time]}."
            check "Add all #{CONTAINER2}s of protplasts, balance as required with tube(s) of water"
            check "Hit Run"
        end
        
        show do 
            title "Wash"
            check "Use a seriological pipette to carefully remove and discard supernatant from each #{CONTAINER2}"
            check "Add #{WASH}. Gently invert until fully mixed"
            check "Set large Sorvall centrifuge to #{CENTRIFUGATION[:speed]}, #{CENTRIFUGATION[:time]}, #{CENTRIFUGATION[:temp]}"
            check "Add all #{CONTAINER2}s of protplasts, balance as required with tube(s) of water"
            check "Hit Run"
            check "Once run is finished, remove tubes and reset the temperature on the centrifuge to 24C"
        end
        
        show do 
            title "Add storage buffer"
            check "Remove and discard supernatant from each #{CONTAINER2} slowly and carefully with a seriological pipette"
            check "Add #{STORAGE} to each #{CONTAINER2} slowly and carefully with a seriological pipette"
            check "Place tubes in the fridge until needed"
        end
    end
    
    
    def run_script 
        
        job_id = operations.map{|op| op.jobs.ids}.uniq
        
        proto_density = show do 
            title "Run protoplast counting script"
            note "Contact Orlando de Lange (odl@uw.edu) for assistance"
            note "Record cells per mL for each sample in this Job #{job_id}"
            operations.each do |op|
                get "number", var: "#{op.id}", label: "Density", default: 10000
            end
        end
        
        operations.each do |op|
            op.input(INPUT).item.associate DENSITY_KEY.to_sym, proto_density["#{op.id}".to_sym]
        end
        
    end
    
    def scope_check_density 
        
        show do 
            title "Turn on the microscope"
            note "Light dial on the left hand of the stage"
            note "Check the USB connection is plugged into the lab top"
            note "Open the camera software (Blue circle, orange T icon)"
            note "To get a live image press the camera name on the top left in the interface"
            note "To take an image click 'snap'"
            note "To save the image, select the image in the tabs on the top, hit Save in the top left toolbar and name the image"
        end
            
        operations.each do |op|
            
            proto_tube = op.input(INPUT).item
            measurements = IMAGE_REPS
            
            show do 
                title "Prepare haemocytometer slide"
                check "Take haemocytometer slide(s). Stored above the microscope."
                check "Clean chamber with 70% ethanol and a Kimwipe"
                check " place the coverslip on the slide and secure into place."
            end
                
            show do
                title "Load samples"
                check "Thorougly mix cells in tube #{proto_tube.id} by repeated but gentle inversion"
                check "Load 20 uL from tube #{proto_tube.id}, using  a p100 with the tip cut off (to avoid squeezing protoplasts). Inject the cells between the cover slip and slide"
            end

            densities = show do 
                title "Check density at microscope with a haemocytometer"
                note "Take a total of #{measurements} images. These should be from distinct sections of the slide}"
                note "Use the 10x objective lens. Autoexposure. Ensure the focus is as crisp as possible for as many cells as possible in each image"
                check "Take #{measurements} images, save and name them #{proto_tube.id}_image-no e.g. #{proto_tube.id}_001 for the first image"
                note "Upload the #{measurements} images"
                upload var: :images
            end
            
            proto_tube.associate :microscope_images, densities[:images]
            
        end
        
        show do 
            title "Clean slide"
            note "Clean slide with ethanol and return to shelf above microscope. "
        end
        
    end

    # ________________________________________________________________________________
    
    def discard_tubes
        disposeTubes = operations.select { |op| op.input(DISCARD_ANS).val == "Yes"  }
        disposeTubes.make
        
        if(disposeTubes.any?) 
            show do 
                title "Discard tubes of protoplasts"
                note "Discard in the Biohazard waste"
                disposeTubes.each do |op|
                    tube = op.input(INPUT).item
                    check "#{tube.id}"
                    tube.mark_as_deleted
                end
            end
        end
    end
    
end