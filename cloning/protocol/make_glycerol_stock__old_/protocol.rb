# TODO: unverified plasmid stocks should exist in some quick, temporary location for the technicians to grab?

class Protocol
    
  def main

    # debuggin'
    if debug
      operations.each do |op| 
        op.plan.associate "Item #{op.input("Plasmid").item.id} sequencing ok?", ["yes somestuff", "no foo", "resequence bar"].sample
      end
    end
    
    operations.retrieve interactive: false 
    
    # Gather user responses
    query_user
    
    # Discard plates of sequenced and verified plasmids
    discard_good_plates
    
    # Discard plasmid stocks for with bad sequencing results
    discard_bad_stocks
    
    # convienence variable
    correct_seq_ops = operations.select { |op| op.temporary[:yes] }
    
    # Make glycerol stocks for ops with verified sequences
    if correct_seq_ops.any?
      correct_seq_ops.make only: ["Plasmid"]
      
      print_labels correct_seq_ops
      
      add_glycerol correct_seq_ops            
    end
     
    # grab all overnights that will be used and/or discarded
    ops_w_discardable_overnight = operations.reject { |op| op.temporary[:resequence] }
    take(ops_w_discardable_overnight.map { |op| op.input("Overnight").item}, interactive: true) if ops_w_discardable_overnight.any?
    
    # finish making glycerol stocks by adding overnight
    add_overnight correct_seq_ops
    
    # Discard overnights for correct and incorrect sequenced plasmids (not ops slated for resequencing)
    discard_overnights ops_w_discardable_overnight
    
    operations.each { |op| op.input_array("Result").items.each { |res| res.mark_as_deleted } }
    
    # Store completed glycerol stocks
    release(correct_seq_ops.map { |op| op.output("Plasmid").item }, interactive: true, method: "boxes")
    
    return {}
  end
  
  
  
  
  def query_user
    vps = ObjectType.where(name: "Plasmid Stock")[0]
    operations.select { |op| op.plan.get("Item #{op.input("Plasmid").item.id} sequencing ok?") }.each do |op|
      ans = op.plan.get("Item #{op.input("Plasmid").item.id} sequencing ok?").downcase
      if ans.include? "yes"
        item = op.input("Plasmid").item
        item.object_type_id = vps.id
        item.save
        op.output("Stock").set item: item
        
        op.temporary[:yes] = true
      elsif ans.include? "resequence"
        op.plan.associate :notice, "Glycerol Stock not made and plasmid stock not verified; please resubmit this stock for sequencing."
        
        op.temporary[:resequence] = true
      else
        op.plan.associate :notice, "Overnight #{op.input("Overnight").item.id} and plasmid stock #{op.input("Plasmid").item.id} will be discarded."
        
        op.temporary[:no] = true
      end
    end
  end
      
  def discard_good_plates
    show do 
        title "Discard plates from good sequencing results"
        
        note "Please discard the following plates: "
        operations.select { |op| op.temporary[:yes] }.each do |op|
          pl = op.input("Plate").item
          note "Plate #{pl.id} at #{pl.location}"
          pl.mark_as_deleted
          pl.save
        end
    end if operations.any? { |op| op.temporary[:yes] }
  end
    
  def discard_bad_stocks
    show do
      title "Discard Plasmid Stocks from bad sequencing results"
      
      note "Please discard the following Plasmid Stocks:"
      operations.select { |op| op.temporary[:no] }.each do |op|
        stock = op.input("Plasmid").item
        note "Plasmid Stock #{stock.id} at #{stock.location}"
        stock.mark_as_deleted
      end
    end if operations.any? { |op| op.temporary[:no] }
  end
    
  def print_labels correct_seq_ops
    show do
      title "Print out labels"
      
      note "On the computer near the label printer, open Excel document titled 'Glycerol stock label template'." 
      note "Copy and paste the table below to the document and save."
      
      table correct_seq_ops.start_table 
          .output_item("Plasmid") 
          .custom_column(heading: "Sample ID") { |op| op.output("Plasmid").sample.id } 
          .custom_column(heading: "Sample Name") { |op| op.output("Plasmid").sample.name[0,16] }
      .end_table

      note "Ensure that the correct label type is loaded in the printer: B33-181-492 should show up on the display. 
        If not, get help from a lab manager to load the correct label type."
      note "Open the LabelMark 6 software and select 'Open' --> 'File' --> 'Glycerol stocks.l6f'"
      note "A window should pop up. Under  'Start' enter #{correct_seq_ops.first.output("Plasmid").item.id} and set 'Total' to #{correct_seq_ops.length}. Select 'Finish.'"
      note "Click on the number in the top row of the horizontal side label and select 'Edit External Data'. A window should pop up. Select 'Finish'."
      note "Select 'File' --> 'Print' and set the printer to 'BBP33'."
      note "Collect labels."
    end
  end
    
  def add_glycerol correct_seq_ops
    show do 
      title "Pipette Glycerol into Cryo Tubes"
      
      check "Take #{correct_seq_ops.length} Cryo #{"tube".pluralize(correct_seq_ops.length)}"
      check "Label each tube with the printed out labels"
      check "Pipette 900 uL of 50 percent Glycerol into each tube."
      warning "Make sure not to touch the inner side of the Glycerol bottle with the pipetter."
    end
  end
    
  def add_overnight correct_seq_ops
    if correct_seq_ops.any?
      show do 
        title "Transfer Into Cryo Tubes"
        
        note "Transfer <b>900 uL</b> of culture according to the following table:"
        
        table correct_seq_ops.start_table
            .custom_column(heading: "Overnight") { |op| op.input("Overnight").item.id } 
            .custom_column(heading: "Glycerol Stock ID", checkable: true) { |op| op.output("Plasmid").item.id }  
        .end_table
        
        note "Cap the Cryo tube and then vortex on a table top vortexer for about 20 seconds."
      end
    end
  end
    
  def discard_overnights ops_w_discardable_overnight
    if ops_w_discardable_overnight.any?
      ops_w_discardable_overnight.each do |op|
        op.input("Overnight").item.mark_as_deleted
      end
      
      show do 
        title "Discard overnights"
        
        note "Please discard all of the following overnights in the dishwashing area:"
        note ops_w_discardable_overnight.map { |op| op.input("Overnight").item.id }.to_sentence
      end
    end
  end
end
