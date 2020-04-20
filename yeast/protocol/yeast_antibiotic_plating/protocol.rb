needs "Standard Libs/Feedback"
needs "Cloning Libs/Cloning"
class Protocol
    include Cloning, Feedback
  def main
    operations.running.retrieve.make
    operations.running.each do |op|
        op.plan.associate :yeast_plate, op.output("Plate").item.id# What is this association supposed to do?! Wouldn't it just get overwritten by other Yeast Antibiotic Plating operations in the same plan?
        # get operation id of corresponding Make AntiBi from input item data 
        # get output item of that operation, which is a antibiotic plate, to plate our overnight on
        spin_off = Operation.find(op.input("Overnight").item.get(:spin_off)) if !debug
        spin_off = Operation.find(103313) if debug
        op.temporary[:plate] = spin_off.output("Plate").item
        
        #the following line does not work to take off the temporary association from the overnight
        op.input("Overnight").item.associations.delete(:spin_off)
        op.input("Overnight").item.save
    end
    
        show do 
            title "Get Antibiotic Plates"
            note "retrieve the following antibiotic plates from the media bay fridge: "
            note "#{operations.running.map { |op| op.temporary[:plate] }.to_sentence}"
        end
    
      show do
        title "Transfer into 1.5 mL tube"
        
        check "Take #{operations.running.length} 1.5 mL tube, label with #{operations.running.map { |op| op.input("Overnight").item.id }}."
        check "Transfer contents from 14 mL tube to each same id 1.5 mL tube."
        check "Recycle or discard all the 14 mL tubes."
      end

      show do
        title "Resuspend in water"
        
        check "Spin down all 1.5 mL tubes in a small table top centrifuge for ~1 minute"
        check "Pipette off supernatant being careful not to disturb yeast pellet"
        check "Add 600 uL of sterile water to each eppendorf tube"
        check "Resuspend the pellet by vortexing the tube throughly"
        warning "Make sure the pellet is resuspended and there are no cells stuck to the bottom of the tube"
      end


      show do
        title "Plating"
        
        check "Relabel the following plates with your initials, the date, and the following ids on the top and side of the plate."
        table operations.running.start_table
                    .custom_column(heading: "Old ID") {|op| op.temporary[:plate].id }
                    .output_item("Plate", heading: "New ID")
                    .end_table
        check "Flip the plate and add 4-5 glass beads to it"
        check "Add 200 uL of 1.5 mL tube contents according to the following table"
        
        table operations.running.start_table
            .input_item("Overnight")
            .output_item("Plate")
        .end_table
      end

      show do
        title "Shake and incubate"
        
        check "Shake the plates in all directions to evenly spread the culture over its surface till dry"
        check "Discard the beads in a used beads container."
        check "Throw away all 1.5 mL tubes."
        check "Put the plates with the agar side up in the 30C incubator."
      end

      operations.running.each do |op|
          plate = op.output("Plate").item
          plate.location = "30 C incubator"
          plate.save
          op.input("Overnight").item.mark_as_deleted
      end
    
    operations.store
    get_protocol_feedback
    return {}
    
  end

end
