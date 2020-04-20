needs "Cloning Libs/Cloning"
needs "Cloning Libs/Gradient PCR"
needs 'Standard Libs/Debug'

class Protocol
    
  # I/O
  FWD = "Forward Primer"
  REV = "Reverse Primer"
  TEMPLATE = "Template"
  FRAGMENT = "Fragment"
  
  # other
  SEC_PER_KB = 30 # sec, extension timer per KB for KAPA
  
  # get the gradient PCR magic
  include Cloning
  include GradientPCR
  include Debug

  def main
      
    if debug
      operations.retrieve interactive: false
      item = operations[0].input(FWD).item
      operations.each do |op|
        if rand(2) < 1
          op.input(REV).set item: item
          op.input(FWD).set item: item
        end
      end
    end
    # grab all necessary items
    dilute_stocks_and_retrieve TEMPLATE
    kapa_stock_item = find(:sample, name: "Kapa HF Master Mix")[0].in("Enzyme Stock")[0]
    take [kapa_stock_item], interactive: true,  method: "boxes"
    
    #check the volumes of input primers for all operations, and ensure they are sufficient
    operations.each { |op| op.temporary[:primer_vol] = 2.5 }
    check_volumes [FWD, REV], :primer_vol, :make_aliquots_from_stock, check_contam: true
    
    # build a pcrs hash that groups pcr by T Anneal
    pcrs = build_pcrs_hash

    # show the result of the binning algorithm
    pcrs.each_with_index do |pcr, idx|
      show { title "pcr #{idx}"}
      log_bin_info pcr
    end if debug

    # generate a table for stripwells
    stripwell_tab = build_stripwell_table pcrs
    
    # prepare and label stripwells for PCR
    prepare_stripwells stripwell_tab
    
    # add templates to stripwells for pcr
    load_templates pcrs
    
    # add primers to stripwells
    load_primers pcrs

    # add kapa master mix to stripwells
    add_mix stripwell_tab, kapa_stock_item
    
    # run the thermocycler
    start_pcr pcrs
    
    # store 
    operations.running.store io: "input", interactive: true, method: "boxes"
    release [kapa_stock_item], interactive: true
    
    return {batches: pcrs}
  end
  
  # dilute to 1ng/uL stocks if necessary
  def dilute_stocks_and_retrieve input
  
    # only use inputs that haven't been diluted and that don't have diluted stocks already
    ops_w_undiluted_template = operations.reject { true }
    operations.each do |op|
        next if op.input(input).object_type.name.include?("1 ng/µL") || op.input(input).object_type.name.include?("50X PCR Template")
        
        sample = op.input(input).sample
        ot_name = op.input(input).object_type.name.include?("Unverified") ? "1 ng/µL Plasmid Stock" : "1 ng/µL " + sample.sample_type.name + " Stock"
        diluted_stock = sample.in(ot_name).first
        
        if diluted_stock
            op.input(input).set item: diluted_stock
        else
            new_stock = produce new_sample sample.name, of: sample.sample_type.name, as: ot_name
            op.temporary[:diluted_stock] = new_stock
            
            ops_w_undiluted_template.push op
        end
    end
    
    # retrieve operation inputs (doesn't include the stocks replaced by diluted stocks above)
    ops_w_undiluted_template.retrieve
    
    # all stocks may be diluted already
    if ops_w_undiluted_template.empty?
        operations.retrieve
        return
    end
    
    # ensure concentrations
    check_concentration ops_w_undiluted_template, input
    
    # dilute stocks
    show do
      title "Make 1 ng/µL Template Stocks"
      
      check "Grab #{ops_w_undiluted_template.length} 1.5 mL tubes, label them with #{ops_w_undiluted_template.map { |op| op.temporary[:diluted_stock].id }.join(", ")}"
      check "Add template stocks and water into newly labeled 1.5 mL tubes following the table below"
      
      table ops_w_undiluted_template
          .start_table
          .custom_column(heading: "Newly-labeled tube") { |op| op.temporary[:diluted_stock].id }
          .input_item(input, heading: "Template stock, 1 L", checkable: true)
          .custom_column(heading: "Water volume", checkable: true) { |op| op.input(input).item.get(:concentration).to_f - 1 }
          .end_table
      check "Vortex and then spin down for a few seconds"
    end
    
    # return input stocks
    release ops_w_undiluted_template.map { |op| op.input(input).item }, interactive: true, method: "boxes"
    
    # retrieve the rest of the inputs
    operations.reject { |op| ops_w_undiluted_template.include? op }.retrieve
    
    # set diluted stocks as inputs
    ops_w_undiluted_template.each { |op| op.input(input).set item: op.temporary[:diluted_stock] }
  end
  
  
  # TODO dilute from stock if item is aliquot
  # Callback for check_volume.
  # takes in lists of all ops that have input aliquots with insufficient volume, sorted by item,
  # and takes in the inputs which were checked for those ops.
  # Deletes bad items and remakes each from primer stock
  def make_aliquots_from_stock bad_ops_by_item, inputs
    # bad_ops_by_item is accessible by bad_ops_by_item[item] = [op1, op2, op3...]
    # where each op has a bad volume reading for the given item
    
    # Construct list of all stocks needed for making aliquots. Error ops for which no primer stock is available
    # for every non-errored op that has low item volume,
    # replace the old aliquot item with a new one. 
    aliquots_to_make = 0
    stocks = []
    ops_by_fresh_item = Hash.new(0)
    stock_table = [["Primer Stock ID", "Primer Aliquot ID"]]
    transfer_table = [["Old Aliquot ID", "New Aliquot ID"]]
    bad_ops_by_item.each do |item, ops|
      stock = item.sample.in("Primer Stock").first ######## items is a string?
      if stock.nil?
        ops.each { |op| op.error :no_primer, "You need to order a primer stock for primer sample #{item.sample.id}." }
        bad_ops_by_item.except! item
      else
        stocks.push stock
        aliquots_to_make += 1
        item.mark_as_deleted
        fresh_item = produce new_sample item.sample.name, of: item.sample.sample_type.name, as: item.object_type.name
        bad_ops_by_item.except! item
        ops_by_fresh_item[fresh_item] = ops
        ops.each do |op| 
          input = inputs.find { |input| op.input(input).item == item }
          op.input(input).set item: fresh_item
        end
        stock_table.push [stock.id, {content: fresh_item.id, check: true}]
        if item.get(:contaminated) != "Yes"
          transfer_table.push [item.id, {content: fresh_item.id, check: true}]    
        end
      end
    end
    
    bad_ops_by_item.merge! ops_by_fresh_item
    take stocks, interactive: true
    
    # label new aliquot tubes and dilute
    show do 
      title "Grab 1.5 mL tubes"
      
      note "Grab #{aliquots_to_make} 1.5 mL tubes"
      note "Label each tube with the following ids: #{bad_ops_by_item.keys.map { |item| item.id }.sort.to_sentence}"
      note "Using the 100 uL pipette, pipette 90uL of water into each tube"
    end
  
    # make new aliquots
    show do 
      title "Transfer primer stock into primer aliquot"
      
      note "Pipette 10 uL of the primer stock into the primer aliquot according to the following table:"
      table stock_table
    end
    
    
    if transfer_table.length > 1
      show do
        title "Transfer Residual Primer"
        
        note "Transfer primer residue from the low volume aliquots into the fresh aliquots according to the following table:"
        table transfer_table
      end
    end
    
    release stocks, interactive: true
  end
  
  # build a pcrs hash that groups pcr by T Anneal
  def build_pcrs_hash
    pcrs = distribute_pcrs operations.running, 4
    pcrs.each do |pcr|
      lengths = pcr[:ops_by_bin].values.flatten.collect { |op| op.output(FRAGMENT).sample.properties["Length"] }
      extension_time = (lengths.max)/1000.0*SEC_PER_KB
      # adding more extension time for longer size PCR.
      if lengths.max < 2000
        extension_time += 30
      elsif lengths.max < 3000
        extension_time += 60
      else
        extension_time += 90
      end
      extension_time = 3 * 60 if extension_time < 3 * 60
      pcr[:mm], pcr[:ss] = (extension_time.to_i).divmod(60)
      pcr[:mm] = "0#{pcr[:mm]}" if pcr[:mm].between?(0, 9)
      pcr[:ss] = "0#{pcr[:ss]}" if pcr[:ss].between?(0, 9)

      # set up stripwells (one for each temperature bin)
      pcr[:ops_by_bin].each do |bin, ops|
          ops.make
          pcr[:stripwells] += ops.output_collections[FRAGMENT]
      end
    end
    pcrs
  end
  
  # generate a table for stripwells
  def build_stripwell_table pcrs
    stripwells = pcrs.collect { |pcr| pcr[:stripwells] }.flatten
    stripwell_tab = [["Stripwell", "Wells to pipette"]] + stripwells.map { |sw| ["#{sw.id} (#{sw.num_samples <= 6 ? 6 : 12} wells)", { content: sw.non_empty_string, check: true }] }
  end
  
  # prepare and label stripwells for PCR
    def prepare_stripwells stripwell_tab
    show do
      title "Label and prepare stripwells"
      
      note "Label stripwells, and pipette 19 L of molecular grade water into each based on the following table:"
      table stripwell_tab
      stripwell_tab
    end
  end
  
  # add templates to stripwells for pcr
  def load_templates pcrs
    pcrs.each_with_index do |pcr, idx|
      show do
        title "Load templates for PCR ##{idx + 1}"
        
        pcr[:ops_by_bin].each do |bin, ops|
          table ops
              .start_table
              .output_collection(FRAGMENT, heading: "Stripwell")
              .custom_column(heading: "Well") { |op| op.output(FRAGMENT).column + 1 }
              .input_item(TEMPLATE, heading: "Template, 1 L", checkable: true)
              .end_table
        end
        warning "Use a fresh pipette tip for each transfer.".upcase
      end
    end
  end
  
  # add primers to stripwells
  def load_primers pcrs
    pcrs.each_with_index do |pcr, idx|
      show do
        title "Load primers for PCR ##{idx + 1}"
        
        pcr[:ops_by_bin].each do |bin, ops|
          table ops.start_table
              .output_collection(FRAGMENT, heading: "Stripwell")
              .custom_column(heading: "Well") { |op| op.output(FRAGMENT).column + 1 }
              .input_item(FWD, heading: "Forward Primer, 2.5 L", checkable: true)
              .input_item(REV, heading: "Reverse Primer, 2.5 L", checkable: true)
              .end_table
        end
        warning "Use a fresh pipette tip for each transfer.".upcase
      end
    end
  end
  
  # add kapa master mix to stripwells
  def add_mix stripwell_tab, kapa_stock_item
      show do
          title "Add Master Mix"
          
          note "Pipette 25 L of master mix (#{kapa_stock_item}) into stripwells based on the following table:"
          table stripwell_tab
          warning "USE A NEW PIPETTE TIP FOR EACH WELL AND PIPETTE UP AND DOWN TO MIX."
          check "Cap each stripwell. Press each one very hard to make sure it is sealed."
      end
  end
  
  # run the thermocycler and update the positions of the stripwells
  def start_pcr pcrs
      pcrs.each_with_index do |pcr, idx|
        is_gradient = pcr[:bins].length > 1
        # log_bin_info pcr # use for debugging bad binning behavior
        thermocycler = show do
          if !is_gradient
            title "Start PCR ##{idx + 1} at #{pcr[:bins].first} C"
            
            check "Place the stripwell(s) #{pcr[:stripwells].collect { |sw| "#{sw}" }.join(", ")} into an available thermal cycler and close the lid."
            get "text", var: "name", label: "Enter the name of the thermocycler used", default: "TC1"
            check "Click 'Home' then click 'Saved Protocol'. Choose 'YY' and then 'CLONEPCR'."
            check "Set the anneal temperature to #{pcr[:bins].first}. This is the 3rd temperature."
          else
            title "Start PCR ##{idx + 1} (gradient) over range #{pcr[:bins].first}-#{pcr[:bins].last} C"
            check "Click 'Home' then click 'Saved Protocol'. Choose 'YY' and then 'CLONEPCR'."
            check "Click on annealing temperature -> options, and check the gradient checkbox."
            check "Set the annealing temperature range to be #{pcr[:bins].first}-#{pcr[:bins].last} C."
            note "The following stripwells are ordered front to back."
            
            pcr[:stripwells].map.with_index do |sw, idx|
              #TODO FIX v
              #pcr[ops_by_bin].keys and pcr[:bins] are not always equivalent. Sometimes pcr[ops_by_bin].keys has items that are not in pcr[:bins]
              temp = pcr[:ops_by_bin].keys[idx].to_f
              log_info temp
              row_num = pcr[:bins].index temp
              log_info row_num
              row_letter = ('H'.ord - row_num).chr
              row_letter = 'A' if pcr[:bins].length == 2 && idx == 1
              check "Place the stripwell #{sw} into Row #{row_letter} (#{temp} C) of an available thermal cycler."
            end
            get "text", var: "name", label: "Enter the name of the thermocycler used", default: "TC1"
          end
          check "Set the 4th time (extension time) to be #{pcr[:mm]}:#{pcr[:ss]}."
          check "Press 'Run' and select 50 L."
        end
        
        # set the location of the stripwell
        pcr[:stripwells].flatten.each do |sw|
          sw.move thermocycler[:name]
        end
      end
  end

  def log_bin_info pcr
    show do
      title "bin info"
      note "ops_by_bin"
      pcr[:ops_by_bin].each do |bin, ops|
        opids = ops.map { |op| op.id }
        check "#{bin.to_s}  =>  #{opids.to_s}"
      end

      note "bins"
      pcr[:bins].each do |bin|
        check "#{bin.to_s}"
      end
    end
  end
end