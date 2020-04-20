needs "Cloning Libs/Cloning"
needs 'PCR Libs/GradientPcrBatching'
needs 'Standard Libs/Debug'

class Protocol
    
  # I/O
  FWD = "Forward Primer"
  REV = "Reverse Primer"
  TEMPLATE = "Template"
  FRAGMENT = "Fragment"
   
  EXTENSION = "Extension Time (sec)"
  TANNEAL = "Annealing Temperature (C)"
  POLYMERASE = "Polymerase"
  TEMPLATE_VOLUME = "Template Volume (uL)"
  
  MIX_VOLUME = { "Kapa HF Master Mix" => 25.0 } # amount of polymerase enzyme to add
  PRIMER_VOLUME = { "Kapa HF Master Mix" => 2.5 } # amount of uL of each primer stock to add
  
  # other
  SEC_PER_KB = 30 # sec, extension timer per KB for KAPA
  
  # get the gradient PCR magic
  include Cloning
  include GradientPcrBatching
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
    
    
    operations.each do |op|
        op.temporary[:polymerase_stock] = Sample.find_by_name(op.input(POLYMERASE).val).in("Enzyme Stock").first
        
        op.temporary[:water_to_add] = 50 - ((PRIMER_VOLUME[op.input(POLYMERASE).val].to_f * 2)  + op.input(TEMPLATE_VOLUME).val.to_f + MIX_VOLUME[op.input(POLYMERASE).val].to_f)
    end
        
    polymerase_stock_items = operations.map { |op| op.temporary[:polymerase_stock] }.uniq
    take polymerase_stock_items, interactive: true,  method: "boxes"
    
    #check the volumes of input primers for all operations, and ensure they are sufficient
    operations.each { |op| op.temporary[:primer_vol] = PRIMER_VOLUME[op.input(POLYMERASE).val] }
    check_volumes [FWD, REV], :primer_vol, :make_aliquots_from_stock, check_contam: true
    
    # build a pcrs hash that groups pcr by T Anneal and Extension time
    pcrs = build_pcrs_hash

    # show the result of the binning algorithm
    pcrs.each_with_index do |pcr, idx|
      show { title "pcr #{idx}"}
      log_bin_info pcr
    end if debug
    
    # prepare and label stripwells for PCR
    prepare_stripwells pcrs
    
    # add templates to stripwells for pcr
    load_templates pcrs
    
    # add primers to stripwells
    load_primers pcrs

    # add kapa master mix to stripwells
    add_mix pcrs
    
    # run the thermocycler
    start_pcr pcrs
    
    # store 
    operations.running.store io: "input", interactive: true, method: "boxes"
    release polymerase_stock_items, interactive: true
    
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
          .input_item(input, heading: "Template stock, 1 uL", checkable: true)
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
    pcr_operations = operations.map do |op|
      PcrOperation.new({
        extension_time: op.input(EXTENSION).val,
        anneal_temp: op.input(TANNEAL).val,
        unique_id: op
      })
    end

    result_hash = batch(pcr_operations)
    pcr_reactions = []
    result_hash.each do |thermocycler_group, row_groups|
      reaction = {}
      extension_time = max(thermocycler_group.max_extension, 30)
      reaction[:mm], reaction[:ss] = (extension_time.to_i).divmod(60)
      reaction[:mm] = "0#{reaction[:mm]}" if reaction[:mm].between?(0, 9)
      reaction[:ss] = "0#{reaction[:ss]}" if reaction[:ss].between?(0, 9)
      
      reaction[:ops_by_bin] = {}
      sorted_rows = row_groups.to_a.sort { |a,b| a.max_anneal <=> b.max_anneal }
      sorted_rows.each do |row_group|
          reaction[:ops_by_bin][row_group.max_anneal.round(1)] = [].extend(OperationList)
          row_group.members.sort { |a,b| a.anneal_temp <=> b.anneal_temp }.each do |pcr_op|
            reaction[:ops_by_bin][row_group.max_anneal.round(1)] << (pcr_op.unique_id)
          end
      end
      
      # trim bin if we cant fit all rows into one thermocycler
      while reaction[:ops_by_bin].keys.size > 8
        extra_ops = reaction[:ops_by_bin][reaction[:ops_by_bin].keys.last]
        extra_ops.each do |op|
            op.error :batching_issue, "We weren't able to batch this operation into a running thermocycler for this Job, try again."
        end
        reaction[:ops_by_bin].except(reaction[:ops_by_bin].keys.last)
      end
      
      reaction[:bins] = reaction[:ops_by_bin].keys
      reaction[:stripwells] = []
      reaction[:ops_by_bin].each do |bin, ops|
          ops.make
          reaction[:stripwells] += ops.output_collections[FRAGMENT]
      end
      pcr_reactions << reaction
    end
    pcr_reactions
  end
  
  # prepare and label stripwells for PCR
  def prepare_stripwells pcrs
    pcrs.each_with_index do |pcr, idx|
        show do
          title "Label and prepare stripwells for PCR ##{idx + 1}"
          
          note "Label new stripwells, and pipette molecular grade water into wells based on the following table:"
          pcr[:ops_by_bin].each do |bin, ops|
            table ops.start_table
                      .output_collection(FRAGMENT, heading: "Stripwell")
                      .custom_column(heading: "Well") { |op| op.output(FRAGMENT).column + 1 }
                      .custom_column(heading: "uL Water") { |op| op.temporary[:water_to_add] }
                      .end_table
          end
        end
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
              .input_item(TEMPLATE, heading: "Template to Add")
              .custom_column(heading: "Amount (uL)", checkable: true) { |op| op.input(TEMPLATE_VOLUME).val.to_f }
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
              .custom_column(heading: "Primer Amount (uL each)") { |op|  PRIMER_VOLUME[op.input(POLYMERASE).val] }
              .input_item(FWD, heading: "Forward Primer", checkable: true)
              .input_item(REV, heading: "Reverse Primer", checkable: true)
              .end_table
        end
        warning "Use a fresh pipette tip for each transfer.".upcase
      end
    end
  end
  
  # add master mixes to stripwells
  def add_mix pcrs
    pcrs.each_with_index do |pcr, idx|
      show do
          title "Add Master Mix for PCR ##{idx + 1}"

          note "Pipette of master mix into stripwells based on the following table:"
          pcr[:ops_by_bin].each do |bin, ops|
            table ops.start_table
                  .output_collection(FRAGMENT, heading: "Stripwell")
                  .custom_column(heading: "Well") { |op| op.output(FRAGMENT).column + 1 }
                  .custom_column(heading: "Enzyme Mix to Add") { |op| "#{op.temporary[:polymerase_stock].id}" }
                  .custom_column(heading: "Amount (uL)") { |op| MIX_VOLUME[op.input(POLYMERASE).val] }
                  .end_table
          end
          warning "USE A NEW PIPETTE TIP FOR EACH WELL AND PIPETTE UP AND DOWN TO MIX."
          check "Cap each stripwell. Press each one very hard to make sure it is sealed."
      end
    end
  end
  
  # run the thermocycler and update the positions of the stripwells
  def start_pcr pcrs
      pcrs.each_with_index do |pcr, idx|
        is_gradient = pcr[:bins].length > 1
        # log_bin_info pcr # use for debugging bad binning behavior
        resp = show do
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
            select ["yes", "no"], var: "batching_ok", label: "Batching looks okay? (Does the Thermocycler allow this temperature range?)", default: [0,1].sample
            note "The following stripwells are ordered front to back."
            
            pcr[:stripwells].map.with_index do |sw, idx|
              temp = pcr[:ops_by_bin].keys[idx].to_f
              log_info temp
              check "Place the stripwell #{sw} into a row of the thermocycler with the temperature as close as possible to <b>#{temp} C</b>"
            end
            get "text", var: "name", label: "Enter the name of the thermocycler used", default: "TC1"
          end
          check "Set the 4th time (extension time) to be #{pcr[:mm]}:#{pcr[:ss]}."
          check "Press 'Run' and select 50uL."
        end
        
        impossible_pcr_handler(pcr) if resp.get_response(:batching_ok) == "no"
        
        # set the location of the stripwell
        pcr[:stripwells].flatten.each do |sw|
          sw.move resp[:name]
        end
      end
  end
  
  def impossible_pcr_handler(pcr)
      pcr[:ops_by_bin].each do |bin, ops|
          ops.each do |op|
            op.error :batching_issue, "We weren't able to batch this operation into a running thermocycler for this Job, try again."
          end
      end
      pcr[:stripwells].each do |sw|
          sw.mark_as_deleted
      end
      
      show do
        title 'Reaction Canceled'
        note "All operations in this pcr reaction are canceled, try them again in a seperate job."
        note "The other Reactions will go forward as planned."
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