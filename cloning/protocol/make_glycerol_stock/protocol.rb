needs "Cloning Libs/Cloning"

class Protocol

  include Cloning
  
  def main

    operations.retrieve.make
    
    # Print out labels
    print_labels

    # Pipette glycerol into cryo tubes
    pipette_glycerol

    # Transfer into cryo tubes
    transfer_into_cryo_tubes

    # Sequencing results
    sequencing_results

    # Discard overnights  
    discard_overnights

    operations.store
    
    return {}
    
  end
  
  
  # This method tells the technician to print out labels and open an Excel document
  # titled 'Glycerol stock label template'.
  def print_labels
    show do
        title "Print out labels"
        
        note "On the computer near the label printer, open Excel document titled 'Glycerol stock label template'." 
        note "Copy and paste the table below to the document and save."
        
        table operations.start_table 
            .output_item("Stock") 
            .custom_column(heading: "Sample ID") { |op| op.output("Stock").sample.id } 
            .custom_column(heading: "Sample Name") { |op| op.output("Stock").sample.name[0,16] }
        .end_table

        note "Ensure that the correct label type is loaded in the printer: B33-181-492 should show up on the display. 
          If not, get help from a lab manager to load the correct label type."
        note "Open the LabelMark 6 software and select 'Open' --> 'File' --> 'Glycerol stocks.l6f'"
        note "A window should pop up. Under  'Start' enter #{operations.first.output("Stock").item.id} and set 'Total' to #{operations.length}. Select 'Finish.'"
        note "Click on the number in the top row of the horizontal side label and select 'Edit External Data'. A window should pop up. Select 'Finish'."
        note "Select 'File' --> 'Print' and set the printer to 'BBP33'."
        note "Collect labels."
    end
  end
  
  # This method tells the technician to pipette glycerol into cryo tubes.
  def pipette_glycerol
    show do 
        title "Pipette Glycerol into Cryo Tubes"
        
        check "Take #{operations.length} Cryo #{"tube".pluralize(operations.length)}"
        check "Label each tube with the printed out labels"
        check "Pipette 900 uL of 50 percent Glycerol into each tube."
        warning "Make sure not to touch the inner side of the Glycerol bottle with the pipetter."
    end
  end
  
  # This method tells the technician to transfer culture into cryo tubes.
  def transfer_into_cryo_tubes
    show do 
        title "Transfer Into Cryo Tubes"
        
        check "Transfer <b>900 uL</b> of culture according to the following table:"
        
        table operations.start_table
            .custom_column(heading: "Overnight") { |op| op.input("Overnight").item.id } 
            .custom_column(heading: "Glycerol Stock ID", checkable: true) { |op| op.output("Stock").item.id }  
        .end_table
        
        check "Cap the Cryo tube and then vortex on a table top vortexer for about 20 seconds."
    end
  end
  
  # This method sequenues results and marks items as deleted once done.
  def sequencing_results
    operations.each do |op|
        on = op.input("Overnight").item
        gs = op.output("Stock").item
        
        pass_data "sequencing results", "sequence_verified", from: on, to: gs
        
        on.mark_as_deleted
        on.save
    end
  end
  
  # This method tells the technician to discard overnights.
  def discard_overnights
    show do 
        title "Discard overnights"
        
        note "Please discard all of the following overnights in the dishwashing area:"
        note operations.map { |op| op.input("Overnight").item.id }.to_sentence
    end
  end

end