# Author: Justin Vrana
# Deployed: 08-11-18
needs "Standard Libs/Feedback"

class Protocol
  include Feedback
  
  INPUT = "Bases"
  OUTPUT = "gBlock Fragment"
  IDT_USER = Parameter.get("IDT User")
  IDT_PASS = Parameter.get("IDT Password")

  def main
    operations.retrieve

    # Setup random sequence
    if debug
      operations.running.each do |op|
        set_fv_parameter op.input(INPUT), generate_random_sequence
      end
    end
    
    # Prepare to order primer
    prepare_to_order
    
    # Go to the gBlock webpage
    go_to_gBlock
    
    # Validate sequences
    validate_sequences 
  
    # Enter gBlock sequences into a table
    sequence_table

    create_table = Proc.new {|ops|
      ops.start_table
        .custom_column(heading: "Name", checkable: true) {|op| op.output(OUTPUT).sample.name}
        .custom_input(:idt_errors, heading: "Errors", type: "string") {|op| op.temporary[:idt_errors] || ''}
        .end_table.all
    }
    
    # order gBlocks
    order_gBlocks create_table

    num_errors = operations.running.count {|op| !op.temporary[:idt_errors].strip.empty?}
    
    # confirm selection
    confirm_selection create_table, num_errors

    idt_error_ops = operations.running.select {|op| !op.temporary[:idt_errors].strip.empty?}

    if idt_error_ops.any?
      remove_errored_entries
    end

    idt_error_ops.each do |op|
      op.error :idt_sequence_error, op.temporary[:idt_errors]
    end
    
    # Answer the IDT Biohazard Disclosure
    answer_disclosure
    
    # Finish order
    data = finish_order

    operations.running.make

    operations.running.each {|op| op.set_output_data(OUTPUT, :order_number, data[:order_number])}
    operations.running.each {|op| op.set_output_data(OUTPUT, :ng, op.temporary[:amount])}
    operations.running.store interactive: false
    
    get_protocol_feedback()

    return {}
  end
  
  # This method sets field value parameters.
  def set_fv_parameter fv, val
    op = Operation.find_by_id(fv.parent_id)
    op.set_property fv.name, val, fv.field_type.role, false, fv.allowable_field_type
  end
  
  # This method generates and returns a random sequence.
  def generate_random_sequence
    seq = 1000.times.map {'agtc AGTC'.chars.sample}.join('')
  end
  
  # This method gets the sequence associated to the input item.
  def get_sequence op
    sequence = op.input("Bases").val
    sequence = sequence[:original_value] if sequence.is_a?(Hash)
    sequence = sequence.gsub(/\s+/, "").upcase
    sequence
  end
  
  # This method tells the technician to go to the idtdna website and be prepared
  # to order primer.
  def prepare_to_order
    show do
      title "Prepare to order primer"

      check "Go to the <a href='https://www.idtdna.com/site/account' target='_blank'>IDT website</a>, log in with the lab account. (Username: #{IDT_USER}, password is #{IDT_PASS})."
      warning "Ensure that you are logged in to this exact username and password!"
    end
  end
  
  # This method tells the technician to go to the gBlock webpage.
  def go_to_gBlock
    show do
      title "Go to gBlock webpage"

      check "Go to the <a href='https://www.idtdna.com/site/Order/gblockentry' target='_blank'>gBlock Ordering</a> website."
    end
  end
  
  # This method validates valides sequences. If the sequence is not valid, the operation errors.
  def validate_sequences 
    operations.running.each do |op|
      sequence = get_sequence op

      # validate sequence
      remain = sequence.chars.uniq - 'AGTC'.chars
      if remain.include?('N') or remain.include?('K')
        op.error :invalid_sequence, "#{remain} are invalid nucleotides. Contact Manager about supporting N or K degenerate bases."
      elsif remain.any?
        op.error :invalid_sequence, "#{remain} are invalid nucleotides."
      end

      if sequence.size < 125 or sequence.size > 3000
        op.error :invalid_sequence_length, "Only 125-3000 bp are supported. Input sequence was #{sequence.size} bp. "
      end
      op.temporary[:sequence] = sequence

      amount = 0.0
      if sequence.size >= 125 and sequence.size <= 250
        amount = 250.0
      elsif sequence.size >= 251 and sequence.size <= 750
        amount = 500.0
      elsif sequence.size >= 751 and sequence.size <= 3000
        amount = 1000.0
      end
      op.temporary[:amount] = amount
    end
  end
  
  # This method prompts the technician to enter gBlock sequences.
  def sequence_table
    show do
      title "Enter gBlock sequences"

      check "Click 'Bulk Input"
      check "Select and copy/paste the following table into the 'Bulk Input' box"
      warning "Please do not select the 'Name' and 'Sequence' headers."
      warning "Be sure that 'Choose a delmiter: Tab/Excel' is checked"
      tab = operations.running.map do |op|
        [op.output(OUTPUT).sample.name, "<font size=\"1\">#{op.temporary[:sequence]}</font>"]
      end
      table tab
      # table here
    end
  end
  
  # This method instructs the technician to order gBlocks.
  def order_gBlocks create_table
    show_with_input_table(operations.running, create_table) do
      title "Order gBlocks"

      check "Click add to order"
      check "If any of the entries contain errors, copy and paste the error into the following table. Leave blank if there were no errors."
    end
  end
  
  # This method tells the technician to confirm the number of entries that errored.
  def confirm_selection create_table, num_errors
    show_with_input_table(operations.running, create_table) do
      title "Confirm selection"

      warning "Confirm there were #{num_errors} entries that errored."
      check "Recheck the website and confirm the error selection."
    end
  end
  
  # This method tells the technician to remove errored entries from the IDT webform.
  def remove_errored_entries
    show do
      title "Remove errored entries"
  
      check "Remove the following entries from the IDT webform by clicking the small trash can on the right-hand side."
  
      table idt_error_ops.start_table
        .custom_column(heading: "Name", checkable: true) {|op| op.output(OUTPUT).sample.name}
      .end_table
    end
  end
  
  # This method tells the technician to answer the IDT Biohazard Disclosure.
  def answer_disclosure
    show do
      title "Answer the IDT Biohazard Disclosure"

      check "Click Add to Order"
      check "Answer the disclosure"
      check "Sign your name and click add to cart."
    end
  end
 
 # This method prompts the technician to finish the order.
  def finish_order
    data = show do
      title "Finish order"

      check "Review the shopping cart to double check that you entered correctly. There should be #{operations.running.size} fragments in the cart."
      check "Click Checkout, then click Continue."
      check "Enter the payment information."
      # check "Enter the payment information, click the oligo card tab, select the Card1 in Choose Payment and then click Submit Order."
      check "Go back to the main page, let it sit for 5-10 minutes, return and refresh, and find the order number for the order you just placed."

      get "text", var: "order_number", label: "Enter the IDT order number below", default: 100
      data
    end
  end
end