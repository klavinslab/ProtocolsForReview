needs "Standard Libs/Feedback"
class Protocol
  IDT_USER = Parameter.get("IDT User")
  IDT_PASS = Parameter.get("IDT Password")
  include Feedback

  def main
    operations.retrieve.make
    
    # login to idt and prepare to order
    idt_login

    # make primer table
    primer_tab = build_primer_table

    # make lists of primers categorized by lengths
    primers_over_60, primers_over_90  = build_primer_lists
    
    # order primers using primer table, and update IDT order numbers for output Primer items
    show_primer_table primer_tab, primers_over_60, primers_over_90
    get_protocol_feedback
    return {}
  end
  
  # This method instructs the technician to go to idtna.com and log in to order the primer.
  def idt_login
    show do
      title "Prepare to order primer"
      
      check "Go to the <a href='https://www.idtdna.com/site/account' target='_blank'>IDT website</a>, log in with the lab account. (Username: #{IDT_USER}, password is #{IDT_PASS})."
      warning "Ensure that you are logged in to this exact username and password!"
    end
  end
  
  # This method creates a primer table. 
  def build_primer_table
    operations.map do |op|
      primer = op.output("Primer").sample
      [primer.id.to_s + " " + primer.name, primer.properties["Overhang Sequence"] + primer.properties["Anneal Sequence"]]
    end
  end
  
  # Creates two primer lists: one list of primers over a length of 60 but less than 90,
  # 
  # @return "[primers_over_60, primers_over_90]" [List] is the list of primers of over length 60 and primers of over length 90
  def build_primer_lists
    operations.each { |op| op.temporary[:length] = (op.output("Primer").sample.properties["Overhang Sequence"] + op.output("Primer").sample.properties["Anneal Sequence"]).length }
    
    primers_over_60 = operations.select do |op| 
      length = op.temporary[:length]
      length > 60 && length <= 90
    end.map do |op| 
        primer = op.output("Primer").sample
        "#{primer} (##{operations.index(op) + 1})"
    end.join(", ")
    
    primers_over_90 = operations.select do |op| 
      length = op.temporary[:length]
      length > 90
    end.map do |op| 
        primer = op.output("Primer").sample
        "#{primer} (##{operations.index(op) + 1})"
    end.join(", ")
    
    [primers_over_60, primers_over_90]
  end
  
  # Shows the primer table that was created in an earlier call and sets the output data.
  def show_primer_table primer_tab, primers_over_60, primers_over_90
    data = show do
      title "Create an IDT DNA oligos order"
      
      warning "Oligo concentration for primer(s) #{primers_over_60} will have to be set to \"100 nmole DNA oligo.\"" if primers_over_60 != ""
      warning "Oligo concentration for primer(s) #{primers_over_90} will have to be set to \"250 nmole DNA oligo.\"" if primers_over_90 != ""
      
      #check "Click Custom DNA Oligos, click Bulk Input. Copy paste the following table and then click the Update button."
      
      check "Under \"Custom DNA Oligos\", click \"DNA Oligos\", then under \"Single-stranded DNA\" click \"Order now\", and click \"Bulk input\". Copy and paste the following table there."
      table primer_tab
      
      check "Click Add to Order, review the shopping cart to double check that you entered correctly. There should be #{operations.length} primers in the cart."
      check "Click Checkout, then click Continue."
      check "Enter the payment information, click the oligo card tab, select the Card1 in Choose Payment and then click Submit Order."
      check "Go back to the main page, let it sit for 5-10 minutes, return and refresh, and find the order number for the order you just placed."
      
      get "text", var: "order_number", label: "Enter the IDT order number below", default: 100
    end

    operations.each { |op| op.set_output_data("Primer", :order_number, data[:order_number]) }
  end
end