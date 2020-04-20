# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    operations.retrieve.make

    show do
      title "Prepare tubes"
      
      note "Label #{operations.length} 1.5 mL tubes with #{(1..operations.length).to_a}"
      note "Label #{operations.length} 50 mL falcon tubes with #{(1..operations.length).to_a}"
    end

    show do
      title "Pour cells into 50 mL tubes"
      
      check "Pour all contents from the flask into the labeled 50 mL falcon tube according to the tabel below. Left over foams are OK."
      
      idx = 0
      table operations.start_table
        .input_item("Flask")
        .custom_column(heading: "50 mL Tube Number", checkable: true) { |op| idx += 1; idx }
        .end_table
    end

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

    show do
      title "Pour out supernatant"
      
      check "After spin, take out all 50 mL falcon tubes and place them in a rack."
      check "Take to the sink at the tube washing station without shaking tubes. Pour out liquid from tubes in one smooth motion so as not to disturb cell pellet."
      check "Recap tubes and take back to the bench."
    end

    show do
      title "Water washing in 50 mL tube"
      
      check "Add 1 mL of molecular grade water to each 50 mL tube and recap."
      check "Vortex the tubes till cell pellet is resuspended."
      check "Aliquot 1.5 mL from each 50 mL tube into the corresponding labeled 1.5 mL tube that has the same label number."
      note "It is OK if you have more than 1.5 mL of the resuspension. 1.5 mL is enough. If you have less than 1.5 mL, pipette as much as possible from tubes."
    end

    show do
      title "Water washing in 1.5 mL tube"
      
      check "Spin down all 1.5 mL tubes for 20 seconds or till cells are pelleted."
      check "Use a pipette and remove the supernatant from each tube without disturbing the cell pellet."
      check "Add 1 mL of molecular grade water to each 1.5 mL tube and recap."
      check "Vortex all tubes till cell pellet is resuspended."
      check "Spin down all 1.5 mL tubes again for 20 seconds or till cells are pelleted."
      check "Use a pipette to remove the supernatant from each tube without disturbing the cell pellet."
    end

    # ask the user to estimate the pellet volume
    show do
      title "Estimate pellet volume"
      
      check "Estimate the pellet volume using the gradations on the side of the 1.5 mL tube."
      note "The 0.1 on the tube means 100 µl and each line is another 100 µl. Noting that normally the pellet volume should be greater than 0 µl and less than 500 µl. Enter a number between 0 to 500."
      
      idx = 0
      table operations.start_table
        .custom_column(heading: "1.5 mL Tube Number") { |op| idx += 1; idx }
        .get(:pellet_vol, type: "number", heading: "Pellet Volume (µl)", default: 80)
        .end_table
    end
    
    # TODO ensure pellet volumes are between 0 and 500
    # ask the user to enter again if the pellet_volume is too large or too small.
    # (1..num).each do |x|
    #   while pellet_volume[:"#{x}".to_sym] > 500 || pellet_volume[:"#{x}".to_sym] < 0
    #     re_pellet_volume = show {
    #       title "Re-estimate the pellet volume"
    #       note "Are you really sure you pellet volume for tube #{x} is #{pellet_volume[:"#{x}".to_sym]} L? Noting that pellet volume means the spun down pellet volume. Did you spin down your tube?"
    #       note "Enter a number between 0 to 500."
    #       get "number",  var: "#{x}", label: "Re-enter an estimated volume in L of the pellet for tube #{x}", default: 80
    #     }
    #     pellet_volume[:"#{x}".to_sym] = re_pellet_volume[:"#{x}".to_sym]
    #   end
    # end

    # TODO support making multiple comp cells
    
    show do
      title "Add FCC"
      
      note "Add the following amount of FCC into each 1.5 ml tube. Vortext until pellet is resuspended:"
      table operations.start_table 
          .custom_column(heading: "1.5 mL Tube Number") { |op| operations.index(op) + 1 }
          .custom_column(heading: "Volume") { |op| op.temporary[:pellet_vol] * 4 }
          .end_table
    end
    
    operations.each_with_index do |op, idx|
      sample = op.output("Comp Cell").sample
      num_aliquots = (4.6 * op.temporary[:pellet_vol] / 50.0).floor
      num_aliquots = 3 if op.input("Flask").sample.properties["Comp_cell_limit"] == "Yes"
      
      # build list of Comp Cell items that will be made in addition to the original comp cell output
      op.temporary[:additional_aliquots] = []
      (num_aliquots - 1).times do
        op.temporary[:additional_aliquots].push produce new_sample sample.name, of: sample.sample_type.name, as: "Yeast Competent Cell"
      end
      
      show do
        title "Aliquoting competent cells from 1.5 mL tube #{idx+1}"
        
        check "Label #{num_aliquots} empty 1.5 mL tubes with the following ids: #{op.temporary[:additional_aliquots].map { |item| item.id}.push(op.output("Comp Cell").item.id).to_sentence}."
        check "Add 50 µl from tube #{idx + 1} to each newly labled tube."
      end
    end

    show do
      title "Discard and recycle tubes"
      
      note "Discard 1.5 mL tubes that were temporarily labeled with #{(1..operations.length).to_a}."
      note "Recycle all 50 mL tubes by putting into a bin near the sink."
    end

    operations.each do |op|
      culture = op.input("Flask").item
      culture.mark_as_deleted
      culture.save
    end

    show do
      title "Put into styrofoam holders in styrofoam box at M80"
      
      check "Place the aliquoted 1.5 mL tubes in styrofoam holders."
      check "Put into the styrofoam box and place in M80 for 10 minutes"
    end

    show do
      title "Wait and then retrive all aliquoted 1.5 mL tubes"
      
      timer initial: { hours: 0, minutes: 10, seconds: 0}
      
      check "Retrive all aliquoted 1.5 mL tubes from the styrofoam box at M80."
      note "Put back into M80C boxes according to the next release pages."
    end
    
    # return all newly made aliquots to fridge.
    release (operations.map { |op| op.temporary[:additional_aliquots]}.flatten).concat(operations.map { |op| op.output("Comp Cell").item }).sort, interactive: true
    
    return {}
    
  end

end
