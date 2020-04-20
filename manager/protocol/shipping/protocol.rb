# This Protocol tells you how to ship most lab items

class Protocol



  def main
      
    if debug
      operations.each do |op|
        op.input("Customer").set item: Item.find_by_object_type_id(ObjectType.find_by_name("Customer Container").id)
      end
    end


    ops_by_customer = Hash.new { |k, v| k[v] = [] }
    
    operations.each do |op|
        ops_by_customer[op.input("Customer").item.sample].push op
    end

    #forms and envelopes from main office
    get_supplies ops_by_customer
    
    #get Items to ship
    operations.retrieve only: ["Ship Out"]
    
  
    
    #Fill out forms for each customer (same for all items)
    ops_by_customer.each do | cust, ops |
        num = 0
        glycerols = ops.select { |op| op.input("Ship Out").object_type.name == "Plasmid Glycerol Stock"}.map { |op| op.input("Ship Out")}
        norm_items = ops.reject { |op| op.input("Ship Out").object_type.name == "Plasmid Glycerol Stock"}.map { |op| op.input("Ship Out")}
        
        num += 1 if glycerols.any?
        num += 1 if norm_items.any?
         
        complete_form cust, num
        
      # Specific shipping preperation instructions depending on object type
        normal_prep norm_items, cust if norm_items.any?
        glycerol_stock_prep glycerols, cust if glycerols.any?
    end
    
    # bring finished packages to main office
    send_packages
    
    # put away plasmid stocks if any
    operations.store io: "input"
    
    return {}
    
  end
  
  
  
  def get_supplies ops_by_customer
      shipping_forms = 0
      dry_ice_warnings = 0
      envelopes = 0
      
      ops_by_customer.each do | cust, ops |
        glycerols = ops.select { |op| op.input("Ship Out").object_type.name == "Plasmid Glycerol Stock"}
        other = ops.reject { |op| op.input("Ship Out").object_type.name == "Plasmid Glycerol Stock"}
        
        if glycerols.any?
          shipping_forms += 1
          dry_ice_warnings += 1
        end
        if other.any?
          shipping_forms += 1
          envelopes += 1
        end
      end
      
      
    show do 
      title "Get Supplies From Main Office"
      
      note "Grab each of the following items from the EE office:"
      check "#{envelopes} Shipping Envelope(s)" if envelopes > 0
      check "#{dry_ice_warnings} Dry Ice Warning Label(s)" if dry_ice_warnings > 0
      check "#{shipping_forms} FedEx Shipping Form(s)"
    end
  end
  
  def complete_form customer, amount
    show do 
      title "Fill Out #{amount} Shipping Form(s) for sending to #{customer.name}"
      
      note "#{customer.properties["Recipient"]}"
      note "#{customer.properties["Address"]}"
      note "#{customer.properties["Address (Line 2)"]}"
      note "#{customer.properties["Phone"]}"
      note "#{customer.properties["Email"]}"
      note "fill in any other necessary fields by bugging Cami"
    end
  end
  
  
  def normal_prep inputs, customer
    plasmid_stocks = inputs.select { |input| input.object_type.name == "Plasmid Stock"}
    other = inputs.reject { |input| input.object_type.name == "Plasmid Stock"}
    
    shipment = other.map { |input| input.item.id}
    other.each { |input| input.item.mark_as_deleted }
    
    plasmid_stocks.each_with_index do |input, i|
      data = show do
        title "How much of  the remaining #{input.item.id} are you going to send?"
        
        choices = ["All", "Part"]
        select choices, var: "fraction", label: "How much ?", default: 0
      end
      
      if data[:fraction] == "Part"
        shipment.push "PS#{i + 1}"
        show do
          title "Partition Plasmid Stock"
          
          note "fill a new container with #{data[:fraction]} of #{input.item.id} and label it PS#{i + 1}"
        end
      else
        shipment.push input.item.id
        input.item.mark_as_deleted
      end
    end

    show do 
        title "Prepare items For Shipping to #{customer.name}"
        note "For all the following items, Parafilm item completely to prevent spills while shipping"
        note "Wrap item in bubble wrap, and put in envelope"
        shipment.each do |id|
          check "#{id}"
        end
        note "Affix a shipping form to envelope"
    end
  end
  
  def glycerol_stock_prep inputs, customer
    inputs.each { |input| input.item.mark_as_deleted }
    show do 
        title "Prepare Glycerol Stocks For Shipping to #{customer.name}"
        
        note "Put the following glycerol stocks in a styrofoam box on a bed of dry ice"
        note "#{inputs.map {|i| i.item.id }.to_sentence}"
        note "Add more dry ice on top and seal box"
        note "place styofoam box inside of cardboard box"
        note "Affix dry ice warning label to box"
        note "Affix shipping form to box"
      end
  end
  
  def send_packages
    show do 
      title "Send Out packages"
      
      note "Bring all packages with attatched forms to the EE office front desk for shipment"
      note "They'll take care of the rest"
    end
  end
end
