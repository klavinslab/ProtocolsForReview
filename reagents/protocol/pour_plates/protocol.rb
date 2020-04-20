class Protocol

  def main
operations.retrieve

    operations.each do |op|
        batch = Collection.new_collection "Agar Plate Batch"
        sample = op.input("Media").sample
        
         show do
                title "Prepare Plates"
                check "Lay out ~40 plates on the bench"
         end
            
        show do
                title "Pour Plates for #{op.input("Media").sample.name}"
                check "Carefully pour ~25 mL into each plate. For each plate, pour until the agar completely covers the bottom of the plate."
                check "If there is a large number of bubbles in the agar, use a small amount of ethanol to pop the bubbles."
         end
            
        num_of_plates = show do
                title "Record Number"
                note "Record the number of plates poured."
                get "number" , var: "num" , label: "Enter a number" , default: 30
            end
         number = num_of_plates[:num]
         batch.add_samples [sample]*number
         show do
                title "Wait for Plate to Solidify"
                
                note "Wait until all plates have completely solidified."
                note "This should take about 10 minutes."
            end
            
            show do
                title "Stack and Label Plates"
                note "Stack the plates agar side up."
                note "Label each stack with \'#{batch.id}\', \'#{sample.name}\', and today's date."
            end
            batch.move "Media Bay Fridge"
            release [batch], interactive: true
            op.output("Plate Batch").set item: batch
            op.input("Media").item.mark_as_deleted
    end
              operations.store io: "input"
   return {}
    
    
  end

end