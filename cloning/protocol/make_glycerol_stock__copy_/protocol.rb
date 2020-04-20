# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

# TODO: unverified plasmid stocks should exist in some quick, temporary location for the technicians to grab?
# TODO: so this is going to change the item id, will the technician have to change the id on the tube?
# TODO: will this be destroying the original item id?
class Protocol
    


  def main

    operations.retrieve(interactive: false)
    
    
    vps = ObjectType.where(name: "Plasmid Stock")[0]
    
    # yes_ops = []
    no_ops = []
    
    # operations.select { |op| op.plan.get("Item #{op.input("Plasmid").item.id} sequencing ok?") }.each do |op|
    #     ans = op.plan.get("Item #{op.input("Plasmid").item.id} sequencing ok?")
    #     if ans.include? "yes"
    #         item = op.input("Plasmid").item
    #         item.object_type_id = vps.id
    #         item.save
    #     elsif ans.include? "resequence"
    #         op.plan.associate :notice, "Glycerol Stock not made and plasmid stock not verified; please resubmit this stock for sequencing."
    #     else
    #         no_ops << op
    #         op.plan.associate :notice, "Overnight #{op.plan.get(:overnight).id} and plate #{op.plan.get(:plate).id} will be discarded."
    #     end
    # end
    
    show do 
        title "Discarding plates and plasmid stocks from failed sequencing results"
        
        note "Please discard the following plates: "
        no_ops.each do |op|
            pl = Item.find_by_id(op.plan.get(:plate))
            note "Plate #{pl.id} at #{pl.location}"
            pl.mark_as_deleted
            pl.save
        end
        
        note "Please discard the following Plasmid Stocks: "
        no_ops.each do |op|
            stock = op.input("Plasmid").item
            note "Plasmid Stock #{stock.id} at #{stock.location}"
            stock.mark_as_deleted
            stock.save
        end
    end
    
    yes_ops = operations.reject { |op| op.plan.get(:notice) }
    
    yes_ops.make

        
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
        
        i = 0
        
            
        show do 
            title "Transfer Into Cryo Tubes"
            note "Transfer <b>900 uL</b> of culture according to the following table:"
                table yes_ops.start_table
                    .custom_column(heading: "Overnight") { |op| op.plan.get(:overnight) } 
                    .custom_column(heading: "Glycerol Stock ID") { |op| op.output("Plasmid").item.id }  
                .end_table
        end
        
        yes_ops.each do |op|
            on = op.plan.get(:overnight)
            Item.find_by_id(on).mark_as_deleted if on
        end
        
        show do 
            title "Discard all the overnights"
            note "Please discard all the overnights in the dishwashing area."
        end
        
    
    # yes_ops.make.each do |op|
    #   op.add_successor(
    #       type: "Make Glycerol Stock",
    #       from: "Plasmid Stock",
    #       to: "Sequenced DNA",
    #       routing: [
    #           { symbol: "G", sample: op.output("Plasmid Stock").sample }
    #       ]
    #   ) 
    # end
    
    
    return {}
    
  end

end
