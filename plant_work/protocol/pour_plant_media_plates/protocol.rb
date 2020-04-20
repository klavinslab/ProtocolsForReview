#Substantial portions copied from #Reagents/Pour plates on 03.11.20

class Protocol
    
    INPUT = "Media"
    OUTPUT = "Plates"

  def main
    
    operations.retrieve
    
    prepare_flow_hood
    
    operations.each do |op|
        pour_plates(op)
    end
    
    clean_flow_hood
    
    operations.store io: "input"
  
  end

    def prepare_flow_hood
        
        show do 
            title "Prepare flow hood"
            check "Open hood. Turn on light"
            check "Clean inside with 70% alocohol"
        end
        
    end
    
    def pour_plates(op)
           
        batch = Collection.new_collection "Agar Plate Batch"
        sample = op.input(INPUT).sample
        
        vols = [200,400,800]
        
        vols.each do |v|
            if op.input(INPUT).item.object_type.name.include?(v.to_s) 
                op.temporary[:plate_num] = v/25 
                break
            end
        end

        show do
            title "Prepare plates"
            note "#{op.temporary[:plate_num]} sterile petri dishes"
            warning "Keep lids on plates while outside of the flow hood to maintain sterility"
            check "Label each plate with the media sample ID (#{op.input(INPUT).sample.id}) and todays date"
        end
        
        show do 
            title "Prepare media"
            warning "Do not leave the microwave unattended. Be ready to open it if the media is about to boil over"
            check "Heat bottle of media #{op.input(INPUT).item.id} in the microwave until melted."
        end
        
        show do 
            title "Go to flow hood"
            check "Take the media and plates to the flow hood"
            check "Put on a clean lab coat or clean your bare arms with alcohol"
            check "Place this computer somewhere near to the flow hood but not inside"
        end
        
        show do 
            title "Pour plates"
            note "Read all instructions before commencing"
            check "Put on clean gloves and sterilize with alcohol"
            check "Lay out all the plates, with their lids off and placed behind them (towards the back of the hood)"
            check "Pour roughly 25 mL from bottle #{op.input(INPUT).item.id} into each plate"
            check "Place the lids back on the plates and allow to cool"
            note "There may not be enough media for all plates. Do not half fill plates, rather distribute the small excess between the other plates"
        end
        
        num_of_plates = show do
            title "Record Number"
            note "Record the number of plates poured."
            get "number" , var: "num" , label: "Enter a number" , default: 30
        end
        
        number = num_of_plates[:num]
        batch.add_samples [sample]*number
        
        batch.move "Media Bay Fridge"
        release [batch], interactive: true
        op.input(INPUT).item.mark_as_deleted
        
    end
    
    def clean_flow_hood
        show do 
            title "Clean hood"
            note "Clean the flow hood. Use water to remove bits of media and then sterilize entire interior with alcohol"
            note "Close the front of the hood and turn off the light"
        end
    end

end