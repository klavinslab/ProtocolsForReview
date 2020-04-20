needs "Tissue Culture Libs/TemporaryExtensions"

class Protocol
  include TemporaryExtensions

  INPUT = "Addgene Number"
  OUTPUT = "Plasmid"
  VENDOR = "Vendor"
  ADDGENE = "Addgene"
  YES = "Yes"
  NO = "No"
  def main

    # operations.retrieve interactive: false
    operations.running.each do |op|
      ft = FieldType.new(
        name: VENDOR,
        ftype: "sample",
        parent_class: "OperationType",
        parent_id: nil
      )
      fv = FieldValue.new(
        name: VENDOR,
        child_item_id: nil,
        child_sample_id: Sample.find_by_name(ADDGENE).id,
        role: "input",
        parent_class: "Operation",
        parent_id: op.id,
        field_type_id: ft.id
      )
      fv.save
      # op.add_input VENDOR, Sample.find_by_name(ADDGENE), ObjectType.all.first()
    end

    def url id
      id = id.to_i
      "<a    href=\"http://www.addgene.org/#{id}\" target=\"_blank\">Addgene ##{id}</a>"
    end

    operations.each do |op|
      op.temporary[:n] = op.input(INPUT).val.to_i
      op.temporary[:url] = url(op.temporary[:n])
      op.temporary[:id] = op.temporary[:n]
    end

    show do
      title "Order Addgene Plasmids"
      note "You will be ordering the following plasmids."
      check "Click \"OK\" to continue."
      table operations.start_table
              .output_sample(OUTPUT)
              .custom_column(heading: "Name") { |op| op.output(OUTPUT).sample.name }
              .custom_column(cheackable: true, heading: "Addgene URL") { |op| url(op.temporary[:n]) }
              .end_table
    end

    create_order_table = Proc.new { |ops|
      ops.start_table
        .custom_column(heading: "Webpage URL") { |op| "<a href=\"#{op.temporary[:url]}\">#{op.temporary[:url]}</a>" }
        .custom_boolean(:valid_url, heading: "URL is valid?") { |op| "Y" }
        .custom_column(heading: "Expected Marker") { |op| op.output(OUTPUT).sample.properties["Bacterial Marker"] }
        .custom_boolean(:matches, heading: "Marker on webpage matches expected marker?") { |op| "Y" }
        .end_table.all
    }

    show_with_input_table(operations.running, create_order_table) do
      title "Check Addgene URL"

      check "Click on each url below"
      check "Check to make sure the url brings you to an Addgene page. If not type \"N\" in the \"URL is valid?\""
      check "Check to make sure the expected marker matches the bacterial marker on the addgene page."
    end

    operations.running.each do |op|
      unless op.temporary[:valid_url]
        op.error :addgene_number_invalid, "The addgene number you entered #{op.temporary[:n]} is invalid! Please re-submit your \
                    addgene order with the correct plasmid number."
      end
      unless op.temporary[:matches]
        op.associate :marker_mismatch_warning, "Warning! The marker in the sample definition of #{op.output(OUTPUT).sample.name} \
                    did not match the resistance indicated on addgene.org/#{op.temporary[:n]}."
      end
    end

    operations.running.make

    show do
      title "Purchase Request Table"

      note "Please copy-and-paste the following into your inventory spreadsheet"

      table operations.start_table
              .custom_column(heading: "Date") { |op| Time.zone.now.strftime("%Y-%m-%d") }
              .custom_column(heading: "Cat#") { |op| op.temporary[:id] }
              .custom_column(heading: "Empty1") { |op| ''}
              .custom_column(heading: "Empty2") { |op| '' }
              .custom_column(heading: "Name") { |op| op.output(OUTPUT).sample.name }
              .custom_column(heading: "Description") { |op| op.output(OUTPUT).sample.description }
              .custom_column(heading: "Quantity") { |op| 1 }
              .custom_column(heading: "Unit") { |op| 'each' }
              .custom_column(heading: "Receive Date") { |op| ""}
              .custom_column(heading: "Expiration Date") { |op| ""}
              .custom_column(heading: "Vendor") { |op| op.input(VENDOR).sample.name }
              .custom_column(heading: "Empty3") { |op| '' }
              .custom_column(heading: "Empty4") { |op| '' }
              .custom_column(heading: "Link") { |op| op.temporary[:url] }
              .custom_column(heading: "Requestor") { |op|
        user = User.find_by_id(op.output(OUTPUT).sample.user_id)
        user.name
      }
              .custom_column(heading: "Budget") { |op| op.plan.budget.name }
              .end_table
    end

    vendor_hash = Hash.new

    operations.each do |op|
      v = op.input(VENDOR).sample
      user = User.find_by_id(op.output(OUTPUT).sample.user_id)
      key_name = "Vendor: #{v.name}, Requestor: #{user.name}"
      vendor_hash[key_name] = vendor_hash[key_name] || []
      vendor_hash[key_name].push(op)
    end

    show do
      title "Fill out a purchase request form"
      warning "You may have to <b>zoom out</b> in your browse to see the whole table"
      title "Order Addgene Plasmids"
      note "<b>Vendor Information</b>"
      vendor = operations.running.first.input(VENDOR).sample
      vt = Table.new
      cols = ["Address", "Website", "Phone", "Fax", "Contact Name", "Contact Email"]
      vt.add_column("Vendor Name", [vendor.name])
      cols.each do |c|
        vt.add_column(c, [vendor.properties[c]])
      end
      table vt
      separator
      note "<b>Items</b>"
      table operations.running.start_table
              .custom_column(heading: "Cat. No") { |op| op.temporary[:id] }
              .custom_column(heading: "Description") { |op| op.output(OUTPUT).sample.description }
              .custom_column(heading: "Weblink") { |op| op.temporary[:url] }
              .custom_column(heading: "Unit Price") { |op| 60.0 }
              .custom_column(heading: "Unit") { |op| "each" }
              .custom_column(heading: "Quantity") { |op| 1 }
              .custom_column(heading: "Budget") { |op| op.plan.budget.name }
              .end_table

    end

  operations.running.each do |op|
    op.output(OUTPUT).item.associate :addgene_number, op.temporary[:n]
  end

  return {}

  
end
  end