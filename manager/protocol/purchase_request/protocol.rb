# Author: Justin Vrana; 2017-07-18

class Protocol
  
  INPUT = "Requested Item"
  OUTPUT = "Ordered Item"
  QUANTITY = "Quantity"
  
  def main
    time = Time.new
    
    show do 
      title "Purchase Request Table"
      
      note "Please copy-and-paste the following into your inventory spreadsheet"
      
      table operations.start_table
            .custom_column(heading: "Date") { |op| time.strftime("%Y-%m-%d") }
            .custom_column(heading: "Cat#") { |op| op.output(OUTPUT).sample.properties['Catalog Number'] }
            .custom_column(heading: "Empty1") { |op| ''}
            .custom_column(heading: "Empty2") { |op| '' }
            .custom_column(heading: "Name") { |op| op.output(OUTPUT).sample.name }
            .custom_column(heading: "Description") { |op| op.output(OUTPUT).sample.description }
            .custom_column(heading: "Quantity") { |op| op.input(QUANTITY).val }
            .custom_column(heading: "Unit") { |op| op.output(OUTPUT).sample.properties['Unit'] }
            .custom_column(heading: "Receive Date") { |op| ""}
            .custom_column(heading: "Expiration Date") { |op| ""}
            .custom_column(heading: "Vendor") { |op| op.output(OUTPUT).sample.properties['Vendor'].name }
            .custom_column(heading: "Empty3") { |op| '' }
            .custom_column(heading: "Empty4") { |op| '' }
            .custom_column(heading: "Link") { |op| "<a href=\"#{op.output(OUTPUT).sample.properties['Weblink']}\">#{op.output(OUTPUT).sample.name} weblink</a>"}
            .custom_column(heading: "Requestor") { |op| 
                user = User.find_by_id(op.output(OUTPUT).sample.user_id)
                user.name
            }
            .custom_column(heading: "Budget") { |op| op.plan.budget.name }
            .end_table
    end
    
    vendor_hash = Hash.new
        
    operations.each do |op|
        v = op.output(OUTPUT).sample.properties['Vendor']
        user = User.find_by_id(op.output(OUTPUT).sample.user_id)
        key_name = "Vendor: #{v.name}, Requestor: #{user.name}"
        vendor_hash[key_name] = vendor_hash[key_name] || []
        vendor_hash[key_name].push(op)
    end
    
    vendor_hash.each do |key, vendor_ops|
        show do
            title "Fill out a purchase request form"
            warning "You may have to <b>zoom out</b> in your browse to see the whole table"
            title "#{key}"
            note "<b>Vendor Information</b>"
            vendor = vendor_ops.first.output(OUTPUT).sample.properties["Vendor"]
            vt = Table.new
            cols = ["Address", "Website", "Phone", "Fax", "Contact Name", "Contact Email"]
            vt.add_column("Vendor Name", [vendor.name])
            cols.each do |c|
                vt.add_column(c, [vendor.properties[c]])
            end
            table vt
            
            separator
            note "<b>Items</b>"
            it = Table.new
            it.add_column("Cat. No.", vendor_ops.map { |op| op.output(OUTPUT).sample.properties["Catalog Number"] } )
            it.add_column("Description", vendor_ops.map { |op| op.output(OUTPUT).sample.description } )
            it.add_column("Weblink", vendor_ops.map { |op| op.output(OUTPUT).sample.properties["Weblink"] } )
            it.add_column("Unit Price", vendor_ops.map { |op| op.output(OUTPUT).sample.properties["Unit Price"] } )
            it.add_column("Unit", vendor_ops.map { |op| op.output(OUTPUT).sample.properties["Unit"] } )
            it.add_column("Quantity", vendor_ops.map { |op| op.input(QUANTITY).val } )
            it.add_column("Budget", vendor_ops.map { |op| op.plan.budget.name } )
            table it
            
            separator
            note "<b>Additional notes and comments</b>"
            user = User.find_by_id(vendor_ops.first.output(OUTPUT).sample.user_id)
            budget_no = "?"
            note "Please put info about the requestor (#{user.name}) and the budget number here."
        end
    end
    
    # Associate quantity with ordered item
    operations.make
    operations.each do |op|
        # op.set_status "ordered"
        op.plan.associate "order_#{op.output(OUTPUT).item.id}", "#{op.output(OUTPUT).sample.name} has been ordered (quantity: #{op.input(QUANTITY).val})" 
        op.associate :ordered, "this item has been ordered (quantity: #{op.input(QUANTITY).val}" 
        op.output(OUTPUT).item.associate :quantity, op.input(QUANTITY).val
        op.set_output_data OUTPUT, :quantity, op.input(QUANTITY).val
    end
    
    return {}
    
  end

end
