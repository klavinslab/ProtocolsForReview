

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol
    
  INPUT = "Seedstock"
  OUTPUT = "Aliquots"
  STORAGE = "draw under plant growth tent GT1"

  def main

    operations.retrieve.make
    
    gather_materials
    
    dispense_seeds
    
    check_input_item

    operations.store

    {}

  end
  
    def check_input_item
      
      ans = show do 
          title "Were any tubes of seeds used up?"
            operations.each do |op|
              note "Item #{op.input(INPUT).item.id}?"
              select ["Yes","No"], var: "#{op.input(INPUT).item.id}", label: "used up?", default: 0
            end
        end
        
        operations.each do |op|
            i = op.input(INPUT).item
            if ans["#{i.id}".to_sym] == "Yes"
                show do 
                    title "Discard tube"
                    note "Discard tube #{i.id}"
                end
                i.mark_as_deleted
                i.save
            end
        end
    end
  
  def gather_materials
        required_materials = ['Box of 0.6 ml microcentrifuge tubes', 'A 0.6 mL tube rack']
        show do 
          title "Gather required materials"
            required_materials.each do |r|
              check "#{r}"
            end
        end
  end
  
  def dispense_seeds 
        operations.each do |op|
            
            show do 
                title "Dispense seeds"
                note "Dispense roughly 25-50 seeds from seedstock #{op.input(INPUT).item.id} into a 0.6 mL microcentrifuge tube"
                #Add an image of what this should look like. 
                note "Seal tube, take a new tube and repeat as often as you like or until Seedstock is empty"
                note "Waxed weighing paper can be a good tool to aliquot seeds. Fold several sheets in half to create channels for seeds, pour between several sheets to help isolate a small number of seeds and pour into microcentrifuge tube"
            end
            
            number = show do 
              title "How many seedstock aliquots did you create?"
              get "number", var: "z", label: "Enter a number", default: 5
            end
            
            number[:z].times do 
                op.output(OUTPUT).collection.add_one(op.input(INPUT).sample)
            end
            
            show do 
                title "Label and Store seeds"
                check "Take a small ziplock bag and label #{op.output(OUTPUT).collection.id}"
                check "Place aliquoted seedstock tubes into the bag"
                check "Store in the #{STORAGE}"
            end
        end
  end
  
  

end
