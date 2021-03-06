eval Library.find_by_name("Preconditions").code.first.content
extend Preconditions

def precondition(op)
    if op.input("Plasmid").item
      order_name = op.input("Plasmid").item.get "seq_order_name_#{op.input("Plasmid").column}".to_sym
      
      # associate old sequencing name style (just in case)
      if order_name.nil?
        op.input("Plasmid").item.associate "seq_order_name_#{op.input("Plasmid").column}".to_sym, "#{op.input("Plasmid").item.id}_#{op.input("Plasmid").column}"
      end
    end
    
    # time_elapsed op, "Plasmid", hours: 8
    true
end