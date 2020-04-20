# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main
      
    operations.make
    
        #This should add 20 items to the output collection for each strain. 
    operations.each do |op|
        strain = Sample.find_by_name(op.input("Strain").sample.name)
        20.to_i.times { op.output("Batch").collection.add_one strain }
    end
    
    glycerol = find(:item, {sample:{name: "10% Glycerol"}, object_type:{name: "400 mL Liquid"}})
    
   second_bottle_query = show do
        title "Pre-chill glycerol"
        check "Grab 10% Glycerol, item number #{glycerol.first.id} from #{glycerol.first.location}"
        select ["Yes" , "No"], var: "glycerol_bottle", label: "Are there at least #{operations.length * 60} mL of glycerol in this bottle", default: 1
    end

        
    if second_bottle_query[:glycerol_bottle] == "No"
        show do
       check "Grab 10% Glycerol, item number #{glycerol.second.id} from #{glycerol.second.location}"
       check "Pre-chill the 10% glycerol in the -20C freezer in the side lab until needed"
        end
    glycerol.first.mark_as_deleted
    glycerol.first.save
    end
    
    if second_bottle_query[:glycerol_bottle] == "Yes"
        show do
       check "Pre-chill the 10% glycerol in the -20C freezer in the side lab until needed"
        end
    end
    
    show do
        title "Pre-chill centrifuge"
         check "Pre-chill the big centrifuge to 4C"
    end
    
    show do
        title "Pre-chill aliquot tubes"
        check "Grab #{operations.length} tube #{"rack".pluralize(operations.length)}"
        check "Grab a box of 0.5 ml tubes"
        check "Place 20 0.5 ml tubes into each tube rack"
    end
    
    show do 
        title "Print tube labels"
        check "Print 20 dot labels with each of the following ID numbers using the label printer"
        operations.each do |op|
            check "#{op.input("Strain").sample.id}"
        end
        check "Stick the labels onto the 0.5 ml tubes."
        check "Place the tubes, on racks, into the M20 in the side lab until needed"
    end
    
    show do
        title "Prepare 50 ml tubes"
        check "Grab #{operations.length * 2} 50 ml screw cap tubes"
        note "Label 2 tubes for each sample with the following:"
        operations.each do |op|
            check "2 tubes labelled #{op.input("Strain").sample.id}"
        end
    end

    show do
        title "Divide overnight cultures into 50 mL tubes"
        check "Pour 40 ml of overnight culture into each labelled 50 ml tube. Don't worry if there's some left over culture in the flask."
        table operations.start_table
            .input_item("Strain", heading:"Flask ID")
            .input_sample("Strain", heading: "Falcon tubes labelled", checkable: true)
            .end_table
    end

    show do
      title "Centrifuge at 3000xg for 5 min"
      note "If you have never used the big centrifuge before, ASK A MORE EXPERIENCED LAB MEMBER BEFORE YOU HIT START!"
      check "Load the 50 mL tubes into the large table top centerfuge such that they are balanced."
      check "Set the speed to 3000xg."
      check "Set the time to 5 minutes."
      check "Hit start"
    end
    
    show do
        title "Clean up/prepare for next steps"
        check "Place flasks into the cleaning tub next to the sink"
        check "Grab a clean 500 ml bottle. With a piece of tape label the bottle 'Agro culture waste'"
        check "Grab a styrofoam box with ice block"
    end

    show do
      title "Pour out supernatant"
      check "After spin, take out all 50 mL falcon tubes and place them in a rack."
      check "Pour out liquid from tubes into the Agro culture waste bottle, in one smooth motion so as not to disturb cell pellet."
      check "Recap tubes and take back to the bench."
    end
    
    show do
        title "Add 20 ml of 10% glyercol"
        check "Grab the ice cold glycerol from the M80"
        check "Pour <b>ice-cold</b> 10% glycerol up to the 20 ml mark for each tube"
        check "Place back into centrifuge and spin again for 5mins at 3000xg"
        check "Place glycerol on the ice block"
    end
    
    show do 
        title "Prepare boxes"
        check " Grab #{operations.length} white, cardboard sample boxes without dividers"
        note "Prepare the following labels, written on tape, for each box"
        operations.each do |op|
            check "#{op.output("Batch").collection.id}, #{op.output("Batch").sample.name}, #{DateTime.now.month}/#{DateTime.now.day}/#{DateTime.now.year}"
        end
        check "Fix labels onto boxes and leave on bench till needed"
    end
    
      show do
      title "Pour out supernatant"
      check "After spin, take out all 50 mL falcon tubes and place them in a rack."
      check "Pour out supernatant into waste bottle, as previously."
    end
    
    show do
        title "Add 4 ml of 10% glyercol"
        check "Using pipette-boy add 4 ml of ice-cold 10% glycerol to each tube"
        check "Place back into centrifuge and spin again for 5mins at 3000xg"
    end
    
    show do
      title "Pour out supernatant"
      check "After spin, take out all 50 mL falcon tubes and place them in a rack."
      check "Remove liquid from tubes with a p1000 pipette. Discard into waste bottle"
      check "Recap tubes"
    end
    
    show do
        title "Add 2ml of 10% glyercol"
        check "Pipette 2 ml of ice-cold 10% glycerol to each tube"
        check "Place back into centrifuge and spin again for 5mins at 3000xg"
    end
    
    show do
      title "Remove supernatant"
      check "After spin, take out all 50 mL falcon tubes and place them in a rack."
      check "Remove liquid from tubes with a pipette. Discard into liquid waste"
      check "Recap tubes"
    end
    
    show do
        title "Add 600 µL of 10% glyercol and combine"
        check "Pipette 600 µL of ice-cold 10% glycerol to each 50 ml tube"
        check "Gather #{operations.length} 1.5 ml tubes"
        check "Label #{operations.collect {|op| "#{op.input("Strain").sample.id}"}.join(",")}"
        check "Mix well by pipetting up and down 3x with 1000 µl pipette tip"
        check "Place tubes on ice block"
        
    end

    
    operations.each do |op|
       
        op.output("Batch").collection.location = "M80"
        op.output("Batch").collection.save
        
        show do
            title "Aliquot cells for strain #{op.input("Strain").sample.id}"
            check "Grab tubes and box labelled #{op.input("Strain").sample.id} from the M20"
            check "Using 100 µL pipette tip dispense 50 µL of cells into each labelled 0.5 mL tube. Flash freeze in N2(l)"
            note "There may be a little left over in the 1.5 ml tube. That's ok."
            check "Fish out of Liquid Nitrogen with a metal sieve and place into the appropriately labelled box"
            check "Return to #{op.output("Batch").collection.location}"
        end
    end
    
    operations.each do |op|
      op.input("Strain").item.mark_as_deleted
      op.input("Strain").item.save
    end
    
  end

end
