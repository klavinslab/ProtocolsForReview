
INPUT = "Protos"
TRANSFECTION_TIME_KEY = "transfection_time"
VOL = 30

class Protocol

  def main

    operations.retrieve
    
    calculate_transfection_time

    score_transfection

    operations.store

    {}

  end
  
    def calculate_transfection_time
          
        operations.each do |op|
              
            if debug
                 op.associate TRANSFECTION_TIME_KEY.to_sym, 2.5
            else
                seconds_per_hour = 60*60
                item_age = Time.zone.now - op.input(INPUT).item.created_at 
                rounded_item_age = item_age.round(1)
                op.associate TRANSFECTION_TIME_KEY.to_sym, rounded_item_age
            end
              
        end          
    end
  
    def score_transfection
        
        set_up_microscope
        
        operations.each do |op|
            
            transfer_to_slide(op)
            
            image_and_score(op)
            
        end
        
        shut_down_clean_up
    end
    
    def set_up_microscope
        
        show do 
            title "Turn on, set up"
            check "Turn on Microscope"
            check "Turn on laser, from the computer - 'Sola'. 50% intensity"
            check "Open 'Las AF' software'"
        end
            
    end
    
    def transfer_to_slide(op)
        
        show do 
            title "Pipette cells into Neubauer"
            note "Transfer cells from tube of transfected protoplasts #{op.input(INPUT).item.id}"
            bullet "#{VOL} µL into Naubauer haemocytometer chamber, using a cut tip"
        end
            
    end
    
    def image_and_score(op)
        
        show do 
            title "Capture images"
            note "Capture-paired Brightfield/FP images and then save as an overlaid JPEG"
            images = upload  
            image_key = "#{op.input(INPUT).item.get(TRANSFECTION_TIME_KEY)}_hrs_Images".to_sym
            op.input(INPUT).item.associate image_key, images
        end
        
        show do 
            title "Clean slide"
            bullet "Remove slide from stage"
            bullet "Wipe with 70% ethanol and a Kimwipe"
        end
    end
    
    def shut_down_clean_up
        
        show do 
            title "Shut down and clean up"
        end
        
    end
    


end
