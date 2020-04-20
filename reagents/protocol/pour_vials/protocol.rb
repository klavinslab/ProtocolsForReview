class Protocol

  def main

    operations.retrieve.make
    
    operations.each do |op|
        
        sample = op.input("Media").sample
        
        num_of_vials = show do
            title "Making Vial Batch of: #{sample.name}"
            note "Record the number of #{sample.name} vials to be made"
            get "number" , var: "num" , label: "Enter a number" , default: 5
        end
        
        number = num_of_vials[:num]
        
        show do
            title "Prepare Vials"
            check "Lay out #{number} autoclaved glass vials on the bench"
        end
        
        show do
            title "Pour Plates"
            check "Carefully pour ~3 mL of #{op.input("Media").sample.name} : #{op.input("Media").item.id} into each vial."
            check "If there is a large number of bubbles in the agar, use a small amount of ethanol to pop the bubbles."
        end
        
        batch = op.output("Vial Batch").collection
        
        batch.add_samples [sample] * number

        show do
            title "Wait for Vials to Solidify"
            note "Wait until all Agar Vials have completely solidified."
            note "This should take about 10 minutes."
        end
        
        show do
            title "Group and label Vials"
            note "put Vials into ziplock bags"
            note "Label bag used for this batch with \'#{batch.id}\', \'#{sample.name}\', and today's date."
        end
        
        batch.move "Media Bay Fridge"
        release [batch], interactive: true
    end
    
    return {}
  end
end
