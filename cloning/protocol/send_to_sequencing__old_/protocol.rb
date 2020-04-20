#ASK ABOUT WHY THE HECK LINE 107 IS GIVING A "WRONG NUMBER OF ARGUMENTS" ERROR BECAUSE THERE ARE THE RIGHT NUMBER OF ARGUMENTS 

class Protocol
  def check_volumes operations, input, vol_sym, opts = {}
    options = { check_contam: false }.merge opts
    
    # setup
    object_type = operations.first.input(input).object_type.name
    operations.each { |op| op.temporary[:volume_verified] = "no" }
    
    while operations.running.any? { |op| op.temporary[:volume_verified] == "no" }
        # retrieve items
        ops_to_check = operations.select { |op| op.temporary[:volume_verified] == "no" }
        take ops_to_check.map { |op| op.input(input).item }
        
        # total volumes for each item
        item_hash = Hash.new(0)
        ops_to_check.each { |op| item_hash[op.input(input).item.id] += op.temporary[vol_sym] }
        
        # ask if sufficient volume for input
        extra_vol = options[:check_contam] ? 0 : 0 # raise volume threshold if checking for contamination also
        
        verify_data = show do
          title "Verify enough volume of each #{object_type} exists#{options[:check_contam] ? ", or note if contamination is present" : ""}"
          item_hash.each do |id, v| 
            choices = options[:check_contam] ? ["Yes", "No", "Contamination is present"] : ["Yes", "No"]
            select choices, var: "#{id}", label: "Is there at least #{(v + extra_vol).round(1)} µL of #{id}?", default: 0
          end
        end
    
        # mark verified operations
        operations.each do |op|
          if verify_data[:"#{op.input(input).item.id}".to_sym] == "Yes"
            op.temporary[:volume_verified] = "yes"
          end
        end
    
        # delete items without enough volume and find replacements
        item_hash.keys.select { |id| verify_data[:"#{id}".to_sym] == "No" }.each do |id|
          # delete item
          item = Item.find(id)
          item.mark_as_deleted
          item.save
          
          # replace item
          ops_for_replacing = operations.select { |op| op.input(input).sample == item.sample }
          
          if object_type.name == "Primer Aliquot"
            new_item = make_aliquot_from_stock item.sample
          else
            new_item = Sample.find(item.sample.id).in(object_type).first
          end
          if new_item
            ops_for_replacing.each do |op|
              op.input(input).set item: new_item
            end
          else
            ops_for_replacing.each do |op|
              op.error :not_enough_volume, "Your #{object_type} did not have enough volume. Please make another!"
            end
          end
        end
    end
  end

  PLASMID = "Plasmid"
  PRIMER = "Sequencing Primer"
  SEQ_RESULT = "Plasmid for Sequencing"

  def main
      
    operations.retrieve(interactive: true)
    
    operations.each do |op|
        op.pass("Plasmid")
    end
    
    # input check
    unless debug
      operations.each do |op|
        if !op.input_data(PLASMID, :concentration)
          op.error :missing_data, "Your plasmid has no listed concentration."
        end
      end
    end
    
    # calculate volumes based on Genewiz guide
    ng_by_length_plas = [500.0, 800.0, 1000.0].zip [6000, 10000]
    ng_by_length_frag = [10.0, 20.0, 40.0, 60.0, 80.0].zip [500, 1000, 2000, 4000]
    samples_list = []
    
    operations.each do |op|
      stock = op.input(PLASMID).item
      length = stock.sample.properties["Length"]
      conc = stock.get(:concentration).to_f || rand(300) / 300
      conc = rand(4000..6000) / 10.0 if debug
      samples_list.push(op.input("Plasmid").sample)
      
      ng_by_length = stock.sample.sample_type.name == "Plasmid" ? ng_by_length_plas : ng_by_length_frag
      plas_vol = ng_by_length.find { |ng_l| ng_l[1].nil? ? true : length < ng_l[1] }[0] / conc
      plas_vol = plas_vol < 0.5 ? 0.5 : plas_vol > 12.5 ? 12.5 : plas_vol
      
      water_vol_rounded = (((12.5 - plas_vol) / 0.2).floor * 0.2).round(1)
      plas_vol_rounded = ((plas_vol / 0.2).ceil * 0.2).round(1)
      primer_vol_rounded = 2.5
      
      op.temporary[:water_vol] = water_vol_rounded
      op.temporary[:stock_vol] = plas_vol_rounded
      op.temporary[:primer_vol] = primer_vol_rounded
    end
    
    # volume check
    check_volumes operations, PLASMID, :stock_vol
    check_volumes operations, PRIMER, :primer_vol
    
    if operations.running.empty?
        show do
            title "It's your lucky day!"
            
            note "There's no sequencing to do. :)"
        end
        
        operations.store
        
        return {}
    end
    
    operations.make only: ["Plasmid for Sequencing"]
    stripwells = operations.output_collections["Plasmid for Sequencing"]
    
    show do
      title "Prepare stripwells for sequencing reaction"
      
      stripwells.each_with_index do |sw, idx|
        if idx < stripwells.length - 1
          check "Label the first well of an unused stripwell with MP#{idx * 12 + 1} and last
                 well with MP#{idx * 12 + 12}"
        else
          number_of_wells = operations.running.length - idx * 12
          check "Prepare a #{number_of_wells}-well stripwell, and label the first well with 
                 UB#{idx * 12 + 1} and the last well with UB#{operations.running.length}"
        end
      end
    end
    
    # load stripwells with molecular grade water
    show do
      title "Load stripwells #{stripwells.map { |sw| sw.id }.join(", ")} with molecular grade water"
      
      i = 0
      stripwells.each_with_index do |sw, idx|
        note "Stripwell #{idx + 1}"
        table operations.running.select { |op| sw.position op.input("Plasmid").sample }.start_table
          .custom_column(heading: "Well") { i = i + 1 }
          .custom_column(heading: "Molecular Grade Water (µL)", checkable: true) { |op| op.temporary[:water_vol] }
          .end_table
      end
    end
    
    # load stripwells with stock
    show do
      title "Load stripwells #{stripwells.map { |sw| sw.id }.join(", ")} with plasmid stock"
      idx = 0
      stripwells.each_with_index do |sw, idx|
        note "Stripwell #{idx + 1}"
        table operations.running.select { |op| sw.position op.input("Plasmid").sample }.start_table
          .custom_column(heading: "Well") { idx = idx + 1 }
          .input_item(PLASMID, heading: "Stock")
          .custom_column(heading: "Volume (µL)", checkable: true) { |op| op.temporary[:stock_vol] }
          .end_table
      end
    end
    
    # load stripwells with primer
    show do
      title "Load stripwells #{stripwells.map { |sw| sw.id }.join(", ")} with "
      
      stripwells.each_with_index do |sw, idx|
        note "Stripwell #{idx + 1}"
        table operations.running.select { |op| sw.position op.input("Plasmid").sample }.start_table
          .custom_column(heading: "Well") { idx = idx + 1 }
          .input_item(PRIMER, heading: "Primer Aliquot")
          .custom_column(heading: "Volume (µL)", checkable: true) { |op| op.temporary[:primer_vol] }
          .end_table
      end
    end
    
    # delete stripwells
    stripwells.each do |sw|
      sw.mark_as_deleted
      sw.save
    end
    
    operations.store
    
    # create Genewiz order
    genewiz = show do
      title "Create a Genewiz order"
      
      check "Go the <a href='https://clims3.genewiz.com/default.aspx' target='_blank'>GENEWIZ website</a>, log in with lab account (Username: biofab@uw.edu, password is glauber1)."
      check "Click Create Sequencing Order, choose Same Day, Online Form, Pre-Mixed, #{operations.running.length} samples, then Create New Form"
      check "Enter DNA Name and My Primer Name according to the following table, choose DNA Type to be Plasmid"
      
      table operations.start_table
        .custom_column(heading: "DNA Name") { |op| 
          stock = op.input(PLASMID).child_item
          "#{stock.id}-#{stock.sample.user.name}"
        }
        .custom_column(heading: "DNA Type") { |op| op.input(PLASMID).sample.sample_type.name == "Plasmid" ? "Plasmid" : "Purified PCR" }
        .custom_column(heading: "DNA Length") { |op| op.input(PLASMID).sample.properties["Length"] }
        .custom_column(heading: "My Primer Name") { |op| op.input(PRIMER).sample.id }
        .end_table
      
      check "Click Save & Next, Review the form and click Next Step"
      check "Enter Quotation Number MS0721101, click Next Step"
      check "Print out the form and enter the Genewiz tracking number below."
      get "text", var: "tracking_num", label: "Enter the Genewiz tracking number", default: "10-277155539"
    end

    # store stripwells in dropbox
    show {
      title "Put all stripwells in the Genewiz dropbox"
      check "Cap all of the stripwells."
      check "Wrap the stripwells in parafilm."
      check "Put the stripwells into a zip-lock bag along with the printed Genewiz order form."
      check "Ensure that the bag is sealed, and put it into the Genewiz dropbox."
    }
    
    # save order data in stripwells
    order_date = Time.now.strftime("%-m/%-d/%y %I:%M:%S %p")
    operations.each do |op|
      op.set_output_data PLASMID, :tracking_num, genewiz[:tracking_num]
      op.set_output_data PLASMID, :order_date, order_date
    end
    
    
    operations.store(interactive: false)
    return {}
    
  end

end
