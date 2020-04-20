# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

#Edited 1.10.18; 3.21.18 by Ayesha Saleem (added code to make sure each aliqout created had an item ID and a location, and said location/item ID was presented to techs; sequential item ids)
needs "Standard Libs/Feedback"
class Protocol
    include Feedback
  def main

    operations.retrieve
    
    # prepare tubes 
    prepare_tubes

    # pour cells into 50 ml tubes
    pour_cells

    # centrifuge at 3000xg for 5 min"
    centrifuge

    # pour out supernatant
    pour_supernatant

    # water washing in 50ml tube
    water_washing_50ml

    # water washing in 1.5 ml tube
    water_washing_small

    # ask the user to estimate the pellet volume
    estimate_pellet_volume
    
    # add FCC
    add_FCC


    # TODO support making multiple comp cells
    aliquot_comp_cells

    # Discard and recycle tubes
    discard_recycle_tubes


    operations.each do |op|
      culture = op.input("Flask").item
      culture.mark_as_deleted
      culture.save
    end
    
    # Put into styrofoam holders in styrofoam box at M80
    put_in_styrofoam_holders

    # wait and then retrieve ml tubes
    retrive_ml_tubes

    
    release (operations.collect { |op| op.output("Comp Cell").item }.push operations.collect { |op| op.temporary[:additional_aliquots].each { |i| i } }).flatten!.sort, interactive: true
    
    
    operations.store(interactive: false)
    get_protocol_feedback
    return {}
    
  end
  
  # This method tells the technician to prepare and label tubes.
  def prepare_tubes
    show do
      title "Prepare tubes"
      
      note "Label #{operations.length} 1.5 mL tubes with #{(1..operations.length).to_a}"
      note "Label #{operations.length} 50 mL falcon tubes with #{(1..operations.length).to_a}"
    end
  end
  
  # This method tells the technician to pour cells into 50 mL tubes.
  def pour_cells
    show do
      title "Pour cells into 50 mL tubes"
      
      check "Pour all contents from the flask into the labeled 50 mL falcon tube according to the tabel below. Left over foams are OK."
      
      idx = 0
      table operations.start_table
        .input_item("Flask")
        .custom_column(heading: "50 mL Tube Number", checkable: true) { |op| idx += 1; idx }
        .end_table
    end
  end
  
  # This method instructs the technician how to use the centrifuge.
  def centrifuge
    show do
      title "Centrifuge at 3000xg for 5 min"
      
      note "If you have never used the big centrifuge before, or are unsure about any aspect of what you have just done. ASK A MORE EXPERIENCED LAB MEMBER BEFORE YOU HIT START!"
      check "Balance the 50 mL tubes so that they all weigh approximately (within 0.1g) the same."
      check "Load the 50 mL tubes into the large table top centerfuge such that they are balanced."
      check "Set the speed to 3000xg."
      check "Set the time to 5 minutes."
      warning "MAKE SURE EVERYTHING IS BALANCED"
      check "Hit start"
    end
  end
  
  # This method tells the technician to pour out supernatant from tubes.
  def pour_supernatant
    show do
      title "Pour out supernatant"
      
      check "After spin, take out all 50 mL falcon tubes and place them in a rack."
      check "Take to the sink at the tube washing station without shaking tubes. Pour out liquid from tubes in one smooth motion so as not to disturb cell pellet."
      check "Recap tubes and take back to the bench."
    end
  end
  
  # This method tells the technician to vortex tubes with water until the cell pell is resuspended.
  def water_washing_50ml
    show do
      title "Water washing in 50 mL tube"
      
      check "Add 1 mL of molecular grade water to each 50 mL tube and recap."
      check "Vortex the tubes till cell pellet is resuspended."
      check "Aliquot 1.5 mL from each 50 mL tube into the corresponding labeled 1.5 mL tube that has the same label number."
      note "It is OK if you have more than 1.5 mL of the resuspension. 1.5 mL is enough. If you have less than 1.5 mL, pipette as much as possible from tubes."
    end
  end
  
  # This method tells the technician to vortex tubes with water until the cell pell is resuspended.
  def water_washing_small
    show do
      title "Water washing in 1.5 mL tube"
      
      check "Spin down all 1.5 mL tubes for 20 seconds or till cells are pelleted."
      check "Use a pipette and remove the supernatant from each tube without disturbing the cell pellet."
      check "Add 1 mL of molecular grade water to each 1.5 mL tube and recap."
      check "Vortex all tubes till cell pellet is resuspended."
      check "Spin down all 1.5 mL tubes again for 20 seconds or till cells are pelleted."
      check "Use a pipette to remove the supernatant from each tube without disturbing the cell pellet."
    end
  end
  
  # This method asks the technician to estimate the pellet volume in the 1.5 mL tube.
  def estimate_pellet_volume
    show do
      title "Estimate pellet volume"
      
      check "Estimate the pellet volume using the gradations on the side of the 1.5 mL tube."
      note "The 0.1 on the tube means 100 L and each line is another 100 L. Noting that normally the pellet volume should be greater than 0 L and less than 500 L. Enter a number between 0 to 500."
      
      idx = 0
      table operations.start_table
        .custom_column(heading: "1.5 mL Tube Number") { |op| idx += 1; idx }
        .get(:pellet_vol, type: "number", heading: "Pellet Volume (uL)", default: 80)
        .end_table
    end
  end
  
  # This method tells the technician to add FCC into each 1.5 mL tube.
  def add_FCC
    show do
      title "Add FCC"
      
      note "Add the following amount of FCC into each 1.5 ml tube. Vortex until pellet is resuspended:"
      idx = 0
      table operations.start_table 
          .custom_column(heading: "1.5 mL Tube Number") { |op| idx += 1; idx }
          .custom_column(heading: "Volume") { |op| op.temporary[:pellet_vol] * 4 }
          .end_table
    end
  end
  
  # This method calculates the number of aliquots in each operation and asks 
  # the technician to label the same number of empty 1.5 mL tubes with item ids.
  def aliquot_comp_cells
    operations.each_with_index do |op, idx|
      operations.select { |o| o.id == op.id }.make
      num_aliquots = (4.6 * op.temporary[:pellet_vol] / 50.0).floor
      aliquot_ids = []
      if op.input("Flask").sample.properties["Comp_cell_limit"] == "Yes"
        num_aliquots = 3
      end
      (num_aliquots - 1).times do 
            item = produce new_sample "#{op.output("Comp Cell").sample.name}", of: "Yeast Strain", as: "Yeast Competent Cell"
            aliquot_ids.push item
      end
      
      op.temporary[:additional_aliquots] = aliquot_ids
      aliquot_ids.blank? ? additional_ids = "" : additional_ids = ", #{aliquot_ids.collect { |i| i.id }.join(", ")}" 
      
      show do
        title "Aliquoting competent cells from 1.5 mL tube #{idx+1}"
        
        check "Label #{num_aliquots} empty 1.5 mL tubes with the following ids #{op.output("Comp Cell").item.id}" + additional_ids + "."
        check "Add 50 uL from tube #{idx + 1} to each newly labled tube."
      end
    end
  end
  
  # This method tells the technician to discard and recycle all tubes.
  def discard_recycle_tubes
    show do
      title "Discard and recycle tubes"
      
      note "Discard 1.5 mL tubes that were temporarily labeled with #{(1..operations.length).to_a}."
      note "Discard 50 mL falcon tubes in biohazard waste."
    end
  end
  
  # This method tells the technician to place aliquoted 1.5 mL tubes into styrofoam holders.
  def put_in_styrofoam_holders
    show do
      title "Put into styrofoam holders in styrofoam box at M80"
      
      check "Place the aliquoted 1.5 mL tubes in styrofoam holders."
      check "Put into the styrofoam box and place in M80 for 10 minutes"
    end
  end
  
  # This method tells the technician to retrive aliquoted 1.5 mL tubes.
  def retrive_ml_tubes
    show do
      title "Wait and then retrieve all aliquoted 1.5 mL tubes"
      
      timer initial: { hours: 0, minutes: 10, seconds: 0}
      
      check "Retrive all aliquoted 1.5 mL tubes from the styrofoam box at M80."
      note "Put back into M80C boxes according to the next release pages."
    end
  end

end
