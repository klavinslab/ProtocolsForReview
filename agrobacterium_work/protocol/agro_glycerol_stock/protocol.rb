class Protocol

  def main
  
    operations.retrieve.make
        
        show do
            title "Prepare table to print labels"
            note "On the computer near the label printer, open Excel document titled 'Glycerol stock label template'." 
            note "Copy and paste the table below to the document and save."
                table operations.start_table 
                    .output_item("Stock") 
                    .custom_column(heading: "Sample ID") { |op| op.input("Overnight").sample.id } 
                    .custom_column(heading: "Sample Name") { |op| op.input("Overnight").sample.name[0,16] }
                .end_table
        end
        
        show do
            title "Print labels"
            note "Ensure that the correct label type is loaded in the printer: B33-181-492 should show up on the display. 
               If not, get help from a lab manager to load the correct label type."
             note "Open the LabelMark 6 software and select 'Open' --> 'File' --> 'Glycerol stocks.l6f'"
             note "A window should pop up. Under  'Start' enter #{operations.first.output("Stock").item.id} and set 'Total' to #{operations.length}. Select 'Finish.'"
             note "Click on the number in the top row of the horizontal side label and select 'Edit External Data'. A window should pop up. Select 'Finish'."
             note "Select 'File' --> 'Print' and set the printer to 'BBP33'."
             note "Collect labels."
         end
            
         show do 
             title "Pipette Glycerol into Cryo Tubes"
             check "Take #{operations.length} Cryo #{"tube".pluralize(operations.length)}"
             check "Label each tube with the printed out labels"
             check "Pipette 900 µL of 50 percent Glycerol into each tube."
             warning "Make sure not to touch the inner side of the Glycerol bottle with the pipetter."
         end

         show do 
             title "Transfer Into Cryo Tubes"
             note "Transfer <b>900 µL</b> of culture according to the following table:"
                 table operations.start_table
                     .custom_column(heading: "Overnight") { |op| op.input("Overnight").item.id } 
                     .custom_column(heading: "Glycerol Stock ID") { |op| op.output("Stock").item.id }
                 .end_table
             end
             
        show do
            title "Discard overnights"
            note "Place overnights in the rack by the sink"
        end
        
    operations.each do |op|
        op.input("Overnight").item.mark_as_deleted
      end
    
   
    operations.store
    
    return {}
  end

end
