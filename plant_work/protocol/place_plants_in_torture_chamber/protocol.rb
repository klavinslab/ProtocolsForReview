# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main
      
        show do
          title "Protocol overview"
          note "In this protocol you will heat up a chamber to 100°F and place plants in it to receive a heat-stress treatment for 2 days"
        end
        
        show do 
            title "Turn on the heater in the torture chamber"
            note "The torture chamber is the the large grow tent. There is a portable heater inside"
            note "First follow the cables of the heater and grow light back to the outlet and make sure they are turned on"
            note "Then turn on the thermostat knob of the heater all the way to 'high'. The heater will start blowing hot air. You will let it keep going till 100°F has been reached inside the chamber. At that point turn the knob to the left until you hear a click. You can read more <a href= https://images-na.ssl-images-amazon.com/images/I/81S9h79JmUS.pdf> here </a>"
        end
        
        operations.retrieve
        
        show do 
            title "Water the plants that are going to be heat-treated"
            note "100 mL water for each tray"
            operations.each do |op|
                check "#{op.input("Plants").item.id}"
            end
        end
        
        number = show do 
            title "Check how many plants are in each tray"
            operations.each do |op|
                    note "How many plants are in tray #{op.input("Plants").item.id}?"
                    get "number", var: "number_#{op.id}", label: "How many plants?", default: 6
            end
        end
        
        operations.each do |op|
            op.input("Plants").item.associate :num_plants, number["number_#{op.id}".to_sym]
        end
        
        operations.make
        
        show do 
            title "Label new trays"
            note "Take #{operations.length} clean green trays"
            note "Label as follows:"
            operations.each do |op|
                check "#{op.output("Victims").item.id}"
            end
        end
        
        show do 
            title "Transfer plants"
            operations.each do |op|
                note "Transfer #{(op.input("Plants").item.get(:num_plants)/2).round} plants from tray #{op.input("Plants").item.id} to tray #{op.output("Victims").item.id}"
            end
        end
        
        operations.each do |op|
            transferred = (op.input("Plants").item.get(:num_plants)/2).round
            new_num = op.input("Plants").item.get(:num_plants) - transferred
            op.input("Plants").item.associate :num_plants, new_num
            op.output("Victims").item.associate :num_plants, transferred
        end
            
        
        show do 
            title "Seal the chamber"
            note "Check that the temeperature has stabilized at 100°F inside the chamber"
            note "Place treatment trays inside the chamber"
            operations.each do |op|
                check "#{op.output("Victims").item.id}"
            end
            note "Seal the chamber"
        end
        
        operations.each do |op|
            op.input("Plants").item.associate :control_of, op.output("Victims").item.id
            op.output("Victims").item.associate :control_tray, op.input("Plants").item.id
            op.output("Victims").item.associate :treatment, "100°F, 2 days"
            op.output("Victims").item.associate :treatment_intiated, DateTime.now
        end
        
        operations.store(io: "input", interactive: true)
    
    return {}
    
  end

end
