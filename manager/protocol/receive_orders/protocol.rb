# Author: Justin Vrana; 2017-07-18
# TODO: Add each slice?
# TODO: Add show_with_input_table
class Protocol
  include ActionView::Helpers::TextHelper
  
  YES = "Yes"
  NO = "No"
  OUTPUT = "Received Order"
  OUTPUT_OBJECT_TYPE = "Received"
  CONTAINER = "Unit Container"
  UNITSPERCONTAINER = "Containers per Unit"
  CATNO = "Catalog Number"
  UNIT = "Unit"
  ASSOCIATED_SAMPLE = "Associated Sample"
  def main
      
    items = Item.where(object_type_id: ObjectType.find_by_name("ordered").id).reject { |i| i.deleted? }
    # items = find(:item, {object_type: {name: "ordered"}})
    non_valid = items.select { |i| !i.get(:quantity) }
    items.select! { |i| i.get :quantity }
    items.each { |i| 
        i.associate(:quantity, i.get(:quantity).to_i)
        i.save
    }
    
    if items.empty?
        show do
            title "There are no outstanding orders"
            
            if non_valid.any?
                note "The following purchase requests are missing quantity data:"
                non_valid.each do |i|
                    check "#{i}"
                end
            end
        end
        return {}
    end

    received_items = []
    items.each_slice(10) { |item_group|
        item_data = show do
          title "Outstanding Orders"
    
    
          t = Table.new
          t.add_column("Ordered Purchase Request", item_group.collect { |i| i.id })
          t.add_column("Purchase Request Name", item_group.collect { |i| i.sample.name })
          t.add_column("Cat No", item_group.collect { |i| i.sample.properties[CATNO] })
          t.add_column("Unit Quantity", item_group.collect { |i| i.get :quantity })
          t.add_column("#{UNIT} information", item_group.collect { |i|
            size = i.sample.properties[UNITSPERCONTAINER].round
            container = i.sample.properties[CONTAINER]
            unit = i.sample.properties[UNIT]
            if container and not container.empty?
                "Produces #{pluralize(size, container)} per unit (#{unit})"
            else container
                size = 1 if size == 0
                "Produces #{size} per unit (#{unit})"
            end
          })
          table t
    
          # 1 '' per each 
            note "Has any of the following ordered been received?"
          item_group.each do |i|
            select [NO, YES], var: "x#{i.id}", label: "Purchase Request: #{i.id} #{i.sample.name}, (##{i.sample.properties[CATNO]})", default: 1
          end
        end
    
        if debug
          item_group.each do |i|
            item_data["x#{i.id}"] = YES
          end
        end
    
        received_items += item_group.select { |i| item_data["x#{i.id}".to_sym] == YES }
    }

    confirmed = false
    while not confirmed
      quantity_data = show do
        title "Confirm quantity received"
        received_items.each do |i|
            q = i.get(:quantity) || 1
            select (0..q).to_a.map { |num| num.to_s }, var: "received_#{i.id}".to_sym, label: "Quantity of #{i.id} #{i.sample.name} received (#{i.sample.properties[UNIT]}):", default: 0
        #   get "number", var: "received_#{i.id}", label: "Quantity of #{i.id} #{i.sample.name} received (#{i.sample.properties[UNIT]}):", default: q
        end
      end

        if debug
            received_items.each do |i|
                q = i.get(:quantity) || 1
                quantity_data["received_#{i.id}".to_sym] = (1..q).to_a.sample
            end
        end

      confirmation = show do
        title "Order Received Table"

        t = Table.new
        t.add_column("Ordered Purchase Request", received_items.collect { |i| i.id })
        t.add_column("Name", received_items.collect { |i| i.sample.name })
        t.add_column("Cat No", received_items.collect { |i| i.sample.properties[CATNO] })
        t.add_column("Quantity Received", received_items.collect { |i|
          quantity_data["received_#{i.id}".to_sym]
        })
        t.add_column("Quantity Remaining", received_items.collect { |i|
          num_received = quantity_data["received_#{i.id}".to_sym].to_i
          q = i.get(:quantity) || 1
          q - num_received
        })
        t.add_column("#{UNIT} information", received_items.collect { |i|
          size = i.sample.properties[UNITSPERCONTAINER].round
          u = i.sample.properties[UNIT]
          "#{size.round} per #{u}"
        })
        table t

        select [NO, YES], var: "confirm", label: "Confirm the above received orders?", default: 0
      end
      confirmed = confirmation[:confirm] == YES
      if debug
        confirmed = true
      end

      #   if confirmed
      #       show do
      #           title "Are you sure?"
      #           warning "By confirming you will produce the following containers in Aquarium."
      #           # table displaying number of containers
      #       end
      #   end
    end

    # Update quantity, delete purchase request
    received_items.each do |i|
      num_received = quantity_data["received_#{i.id}".to_sym].to_i
      
      num_remaining = i.get(:quantity) - num_received
      i.associate :quantity, num_remaining

      if num_remaining <= 0
        i.mark_as_deleted
      end
    end
    
    # Produce new purchase request
    # received_items.each do |i|
    #   num_received = quantity_data["received_#{i.id}".to_sym].to_i
    #   if num_received > 0
    #     # Produce "ordered" item
    #     o = produce new_sample i.sample.name, of: i.sample.sample_type.name, as: OUTPUT_OBJECT_TYPE
    #     o.associate :quantity, num_received
    #   end
    # end

    # Produce containers if available
    items_with_containers = received_items.select { |i| ObjectType.find_by_name(i.sample.properties[CONTAINER]) }
    items_without_containers = received_items.select { | i| !items_with_containers.include? i }
    if items_with_containers.any?
        produce_items = show do
            title "Produce Aquarium Items?"
    
            note "The following Object_Types were found to be associated with the Purchases Requests."
    
            t = Table.new
            t.add_column("Ordered Purchase Request", items_with_containers.collect { |i| i.id })
            t.add_column("Purchase Request Name", items_with_containers.collect { |i| i.sample.name })
            t.add_column("Cat No.", items_with_containers.collect { |i| i.sample.properties[CATNO] })
            t.add_column("Container", items_with_containers.map { |i| i.sample.properties[CONTAINER] } )
            t.add_column("Sample", items_with_containers.collect { |i| 
                s = i.sample.properties[ASSOCIATED_SAMPLE]
                if s
                    s = s.name
                else
                    s = 'None'
                end
                s
            } )
            table t


            note "Would you like to create Objects/Containers for the following items?"
        
            items_with_containers.each do |i|
                c =  ObjectType.find_by_name(i.sample.properties[CONTAINER])
                s = i.sample.properties[ASSOCIATED_SAMPLE]
                note "Sample #{s.name}" if s
                msg = "Produce #{quantity_data["received_#{i.id}".to_sym].to_i} #{c.name}"
                msg += " of sample #{s.name}" if s
                msg += "?"
                select [NO, YES], var: "#{i.id}", label: msg, default: 1
            end
        end
        
        if debug
            items_with_containers.each do |i|
                produce_items["#{i.id}".to_sym] = YES
            end
        end
        new_items = []
        to_be_produced = items_with_containers.select { |i| produce_items["#{i.id}".to_sym] == YES }
        items_without_containers += items_with_containers.select { |i| !to_be_produced.include? i }

        
        show do
            title "Label new items"
            to_be_produced.each do |i|
                c = ObjectType.find_by_name(i.sample.properties[CONTAINER])
                s = i.sample.properties[ASSOCIATED_SAMPLE]
                new_item = nil
                if s
                    st = SampleType.find_by_id(s.sample_type_id)
                    new_item = produce new_sample s.name, of: st.name, as: c.name
                else
                    new_item = produce new_object c.name
                end
                new_items << new_item
            end
            
            t = Table.new
            t.add_column("Item id", new_items.map { |i| "<b>#{i.id}</b>" })
            t.add_column("Sample", new_items.map { |i| 
                s = i.sample
                s = s.name if s 
                s ||= "No Sample"
            })
            t.add_column("Sample Type", new_items.map { |i|
                st = i.sample.sample_type if i.sample
                st = st.name if st 
                st ||= "No Sample Type"
            })
            t.add_column("Object Type", new_items.map { |i| i.object_type.name })
            t.add_column("Item id", new_items.map { |i| i.id })
            table t
        end if to_be_produced.any?
        new_items.each { |i| i.store }
        
        if items_without_containers.any?
            locations = show do
                title "Put away received items"
                
                check "Please put away newly received items. You may have to check the storage temperature and conditions to ensure they are stored properly."
                items_without_containers.each do |i|
                    get "text", var: "location_of_#{i.id}".to_sym, label: "Enter the location of items associated with #{i.sample.name}", default: "bench"
                end
            end
            
            items_without_containers.each do |i|
                l = locations["location_of_#{i.id}".to_sym]
                operations.each do |op|
                    op.associate "order_#{i.id}_location".to_sym, "Items associated with #{i.sample.name} were moved to #{l}"
                    op.plan.associate "order_#{i.id}_location".to_sym, "Items associated with #{i.sample.name} were moved to #{l}"
                end
                i.associate "received_items_location", "Items associated with #{i.sample.name} were moved to #{l}"
            end
        end
    
        release(new_items,interactive: true) if new_items.any?
        
        received_items.each do |i|
            operations.each do |op|
                op.associate "order_#{i.id}".to_sym, "recieved order for #{i.sample.name}"
                op.plan.associate "order_#{i.id}".to_sym, "recieved order for #{i.sample.name}"
            end
        end
    end
    

    return {}

  end

end
