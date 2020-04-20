needs "Standard Libs/Feedback"
needs "Yeast/CheckForGrowth"
class Protocol
        include Feedback
        include CheckForGrowth
        INPUT = 'Yeast'
  def main
      
    ot = ObjectType.where(name: "Yeast Overnight Suspension").first
    raise "Invalid object type; #{ot} does not exist" unless ot
    
    on = operations.select { |op| op.input("Yeast").item.object_type_id == ot.id }
    
    
    glycerol_stock_steps on, "Yeast" if on
    
    operations.store
    get_protocol_feedback
    return {}
  end
  
  # This method executes the steps involved with preparing glycerol stock.
  def glycerol_stock_steps(input_ops, input_name, input=nil, output=nil)

    input ? c = true : c = false
    raise "Please pass in outputs as well as inputs!" if c && !output
    
    # Verify whether each input has growth and error it if it does not
    # IMPORTANT: this must go before operations.make because it changes the number of operations to make
    check_for_growth(INPUT)
    
    input_ops = operations
    input_ops.make unless c
    take input if c
    input_ops.retrieve  unless c
    
    # Print labels
    print_labels input_ops, c, input_name

    # Pipette Glycerol into cryo tubes
    pipette_glycerol input_ops
    
    i = 0
    
    # Transfer into cryo tubes
    cyro_tubes input_ops, input_name, c
   
    c ? input.each { |i| i.mark_as_deleted } : input_ops.each { |op| op.input(input_name).item.mark_as_deleted }
    
    discard_overnights
  end
  
  # This method tells the technician to print out labels and ensure
  # that the correct label type is loaded in the printer.
  def print_labels input_ops, c, input_name
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
       note "Click on the number in the top row of the horizontal side label and select 'Edit External Data'. A window should pop up. Select 'Finish'."
       note "Ensure the correct data is displayed on the labels."
       note "Select 'File' --> 'Print' and set the printer to 'BBP33'."
       note "Collect labels."
    end
  end
  
  # This method tells the technician to pipette glycerol into cryo tubes.
  def pipette_glycerol input_ops
    show do 
      title "Pipette Glycerol into Cryo Tubes"
      check "Take #{input_ops.length} Cryo #{"tube".pluralize(input_ops.length)}"
      check "Label each tube with the printed out labels"
      check "Pipette 900 uL of 50 percent Glycerol into each tube."
      warning "Make sure not to touch the inner side of the Glycerol bottle with the pipetter."
    end
  end
  
  # This method tells the technician to transfer culture into cryo tubes.
  def cyro_tubes input_ops, input_name, c
    show do 
      title "Transfer Into Cryo Tubes"
      note "Transfer <b>900 uL</b> of culture according to the following table:"
    
      unless c 
        table input_ops.start_table
          .custom_column(heading: "Overnight") { |op| op.input(input_name).item.id } 
          .custom_column(heading: "Glycerol Stock ID") { |op| {content: op.output(input_name).item.id, check: true} }  
        .end_table
      end
    
      if c
        table input_ops.start_table
          .custom_column(heading: "Overnight") { input[0].id } 
          .custom_column(heading: "Glycerol Stock ID") { {content: output[0], check: true} } 
        .end_table
      end
     
      note "Cap the Cryo tube and then vortex on a table top vortexer for about 20 seconds."
    end
  end
  
  # This method tells the technician to discard overnights.
  def discard_overnights
    show do 
       title "Discard Overnights" 
       note "Discard all overnights used in the protocol."
    end
  end

end
