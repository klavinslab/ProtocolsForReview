
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
    

  def main

    operations.retrieve.make
    
    scope_check_density
    
    run_script
    
    discard_tubes
    
    operations.store

    {}

  end

    # ________________________________________________________________________________
    
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