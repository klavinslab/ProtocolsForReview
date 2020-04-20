class Protocol

  def glycerol_stock_steps(input_ops, input_name, input=nil, output=nil)
  
        input ? c = true : c = false
        
        raise "Please pass in outputs as well as inputs!" if c && !output
        
        input_ops.make unless c
        
        
        take input if c
        input_ops.retrieve  unless c
        
        
        
        i = 0
        
        show do
            title "Print out labels"
            note "On the computer near the label printer, open Excel document titled 'Glycerol stock label template'." 
            note "Copy and paste the table below to the document and save."
            unless c
                table input_ops.start_table 
                    .output_item(input_name) 
                    .custom_column(heading: "Sample ID") { |op| op.input(input_name).sample.id } 
                    .custom_column(heading: "Sample Name") { |op| op.input(input_name).sample.name[0,16] }
                .end_table
            end

            
            if c
                table input_ops.start_table.custom_column(heading: "thing") { i = i + 1 }
                 .custom_column(heading: "Item ID") { "" }
                 .end_table
                # .custom_column(heading: "Sample ID") { input[i].sample.id  i = i + 1 } 
                # .custom_column(heading: "Sample Name") { input[(i = i + 1)].sample.name[0,16] } 
                    
                
            end
            
            note "Ensure that the correct label type is loaded in the printer: B33-181-492 should show up on the display. 
               If not, get help from a lab manager to load the correct label type."
             note "Open the LabelMark 6 software and select 'Open' --> 'File' --> 'Glycerol stocks.l6f'"
             note "A window should pop up. Under  'Start' enter #{input_ops.first.output(input_name).item.id} and set 'Total' to #{input_ops.length}. Select 'Finish.'"
             note "Click on the number in the top row of the horizontal side label and select 'Edit External Data'. A window should pop up. Select 'Finish'."
             note "Select 'File' --> 'Print' and set the printer to 'BBP33'."
             note "Collect labels."
         end
            
         show do 
             title "Pipette Glycerol into Cryo Tubes"
             check "Take #{input_ops.length} Cryo #{"tube".pluralize(input_ops.length)}"
             check "Label each tube with the printed out labels"
             check "Pipette 900 µL of 50 percent Glycerol into each tube."
             warning "Make sure not to touch the inner side of the Glycerol bottle with the pipetter."
         end
        
         i = 0
        
            
         show do 
             title "Transfer Into Cryo Tubes"
             note "Transfer <b>900 µL</b> of culture according to the following table:"
            
             unless c 
                 table input_ops.start_table
                     .custom_column(heading: "Overnight") { |op| op.input(input_name).item.id } 
                     .custom_column(heading: "Glycerol Stock ID") { |op| op.output(input_name).item.id }  
                 .end_table
             end
            
             if c
                 table input_ops.start_table
                     .custom_column(heading: "Overnight") { input[0].id } 
                     .custom_column(heading: "Glycerol Stock ID") { output[0] } 
                 .end_table
             end
         end
        
        
      show do 
        title "Discard overnights"
        
        note "Please discard all of the following overnights in the dishwashing area:"
        note c ? input.map { |i| i.id }.to_sentence : input_ops.map { |op| op.input(input_name).item.id }.to_sentence
      end
      c ? input.each { |i| i.mark_as_deleted } : input_ops.each { |op| op.input(input_name).item.mark_as_deleted }
    end

  def main
      
    operations.retrieve(interactive: false)
      
    ot = ObjectType.where(name: "Yeast Overnight Suspension").first
    raise "Invalid object type; #{ot} does not exist" unless ot
    
    on = operations.select { |op| op.input("Yeast").item.object_type_id == ot.id }
    
    
    glycerol_stock_steps on, "Yeast" if on
    
    operations.store
    
    return {}
  end
end
