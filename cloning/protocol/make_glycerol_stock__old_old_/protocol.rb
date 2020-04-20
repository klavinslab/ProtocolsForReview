# TODO: unverified plasmid stocks should exist in some quick, temporary location for the technicians to grab?
class Protocol
  def main

    # debuggin'
    if debug
        operations.each do |op| 
            op.plan.associate "Item #{op.input("Plasmid").item.id} sequencing ok?", ["yes somestuff", "no foo", "resequence bar"].sample
            op.plan.associate "overnight_#{op.input("Plasmid").sample.id}", Item.where(object_type_id: ObjectType.find_by_name("TB Overnight of Plasmid").id).sample.id
            op.plan.associate "plate_#{op.input("Plasmid").sample.id}", Item.where(object_type_id: ObjectType.find_by_name("E coli Plate of Plasmid").id).sample.id
        end
    end

    # Associate overnights and plates
    operations.each do |op|
        op.temporary[:overnight] = Item.find(op.plan.get("overnight_#{op.input("Plasmid").sample.id}") || Item.find(op.plan.get(:overnight)))
        op.temporary[:plate] = Item.find(op.plan.get("plate_#{op.input("Plasmid").sample.id}") || Item.find(op.plan.get(:plate)))
    end

    operations.retrieve(interactive: false)
    
    # Gather user responses
    vps = ObjectType.where(name: "Plasmid Stock")[0]
    operations.select { |op| op.plan.get("Item #{op.input("Plasmid").item.id} sequencing ok?") }.each do |op|
        ans = op.plan.get("Item #{op.input("Plasmid").item.id} sequencing ok?").downcase
        if ans.include? "yes"
            item = op.input("Plasmid").item
            item.object_type_id = vps.id
            item.save
            op.output("Stock").set item: item
            # op.pass "Plasmid", "Stock"
            
            op.temporary[:yes] = true
        elsif ans.include? "resequence"
            op.plan.associate :notice, "Glycerol Stock not made and plasmid stock not verified; please resubmit this stock for sequencing."
            
            op.temporary[:resequence] = true
        else
            op.plan.associate :notice, "Overnight #{op.temporary[:overnight].id} and plasmid stock #{op.input("Plasmid").item.id} will be discarded."
            
            op.temporary[:no] = true
        end
    end
    
    # Discard plates for yes
    show do 
        title "Discard plates from good sequencing results"
        
        note "Please discard the following plates: "
        operations.select { |op| op.temporary[:yes] }.each do |op|
            pl = op.temporary[:plate]
            note "Plate #{pl.id} at #{pl.location}"
            pl.mark_as_deleted
            pl.save
        end
    end if operations.any? { |op| op.temporary[:yes] }
    
    # Discard plasmid stocks for no
    show do
        title "Discard Plasmid Stocks from bad sequencing results"
        
        note "Please discard the following Plasmid Stocks:"
        operations.select { |op| op.temporary[:no] }.each do |op|
            stock = op.input("Plasmid").item
            note "Plasmid Stock #{stock.id} at #{stock.location}"
            stock.mark_as_deleted
            stock.save
        end
    end if operations.any? { |op| op.temporary[:no] }
    
    # Make glycerol stocks for yes
    yes_ops = operations.select { |op| op.temporary[:yes] }
    if yes_ops.any?
        yes_ops.make only: ["Plasmid"]
        
        show do
            title "Print out labels"
            
            note "On the computer near the label printer, open Excel document titled 'Glycerol stock label template'." 
            note "Copy and paste the table below to the document and save."
            
            table yes_ops.start_table 
                .output_item("Plasmid") 
                .custom_column(heading: "Sample ID") { |op| op.output("Plasmid").sample.id } 
                .custom_column(heading: "Sample Name") { |op| op.output("Plasmid").sample.name[0,16] }
            .end_table
    
            note "Ensure that the correct label type is loaded in the printer: B33-181-492 should show up on the display. 
              If not, get help from a lab manager to load the correct label type."
            note "Open the LabelMark 6 software and select 'Open' --> 'File' --> 'Glycerol stocks.l6f'"
            note "A window should pop up. Under  'Start' enter #{yes_ops.first.output("Plasmid").item.id} and set 'Total' to #{yes_ops.length}. Select 'Finish.'"
            note "Click on the number in the top row of the horizontal side label and select 'Edit External Data'. A window should pop up. Select 'Finish'."
            note "Select 'File' --> 'Print' and set the printer to 'BBP33'."
            note "Collect labels."
        end
            
        show do 
            title "Pipette Glycerol into Cryo Tubes"
            
            check "Take #{yes_ops.length} Cryo #{"tube".pluralize(yes_ops.length)}"
            check "Label each tube with the printed out labels"
            check "Pipette 900 uL of 50 percent Glycerol into each tube."
            warning "Make sure not to touch the inner side of the Glycerol bottle with the pipetter."
        end
        
        show do 
            title "Transfer Into Cryo Tubes"
            
            note "Transfer <b>900 uL</b> of culture according to the following table:"
            
            table yes_ops.start_table
                .custom_column(heading: "Overnight") { |op| op.temporary[:overnight].id } 
                .custom_column(heading: "Glycerol Stock ID", checkable: true) { |op| op.output("Plasmid").item.id }  
            .end_table
            
            check "Cap the Cryo tube and then vortex on a table top vortexer for about 20 seconds."
        end
    end
    
    # Discard overnights for yes and no (not resequence)
    discard_on_ops = operations.reject { |op| op.temporary[:resequence] }
    if discard_on_ops.any?
        discard_on_ops.each do |op|
            on = op.temporary[:overnight]
            if on
                on.mark_as_deleted
                on.save
            end
        end
        
        show do 
            title "Discard overnights"
            
            note "Please discard all of the following overnights in the dishwashing area:"
            note discard_on_ops.map { |op| op.temporary[:overnight].id }
        end
    end

    return {}
    
  end

end
