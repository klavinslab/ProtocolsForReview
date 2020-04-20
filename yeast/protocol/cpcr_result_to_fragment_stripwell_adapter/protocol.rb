needs "Standard Libs/Debug"
needs "Standard Libs/Feedback"
class Protocol

include Debug
include Feedback
  def main

    operations.retrieve.make
    
    if operations.length > 12
      raise "maximum batch of 12 operations"
    end
    
    # Label output stripwell
    label_stripwell

    fragment_well = 0 
    
    operations.each do |op|
      fragment_well += 1

      transfer_table = [["Input Stripwell", "Input Well Index", "Output Stripwell", "Output Well Index"]]
      op.input_array("Strain").each do |input|
        transfer_table.push [input.collection.id, input.column + 1, op.output("Fragment").collection.id, { content: fragment_well, check: true }]
      end
      
      # Set input and mark as deleted if necessary
      modify_inputs op
      
      # Combine Wells
      combine_wells transfer_table

    end
    operations.store
    get_protocol_feedback
    return {}
    
  end
  
  # This method tells the technician to label the output stripwell.
  def label_stripwell
    show do 
      title "Label output stripwell"
      note "Get a fresh stripwell and label it #{operations.first.output("Fragment").collection.id}"
    end
  end
  
  # This method tells the technician to combine wells.
  def combine_wells transfer_table
    show do 
      title "Combine Wells"
      note "Combine contents of CPCR result samples into a single well of an output stripwell according to the follwing table"
      table transfer_table
    end
  end
  
  # This method clears the value at (row,col) in the input's collection.
  def modify_inputs op
    op.input_array("Strain").each do |input|
      input.collection.set input.row, input.column,  nil
      if input.collection.empty?
        input.item.mark_as_deleted
      end
    end
  end

end