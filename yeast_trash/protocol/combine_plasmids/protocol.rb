needs "Standard Libs/Debug"
needs "Cloning Libs/Cloning"

class Protocol
  
  include Debug
  include Cloning

  STOCKS = "Stocks"
  NANO = "Nanograms (comma- or space-separated list of nanograms of each stock to use)"
  STOCK = "Stock"

  def main

    if debug
      operations.each do |op|
        op.set_input NANO, "  	600, 400   215"
      end
    end

    parse_nanograms
    
    if operations.running.none?
      show do
        title "No stocks to combine"
        
        note "Have a great day! :)"
      end
      
      return {}
    end

    operations.running.retrieve.make
    
    check_concentration operations.running, STOCKS
    
    combine_plasmids

    operations.running.store
    
    return {}
    
  end
  
  def parse_nanograms
    # ensure input array size matches nanogram list size
    operations.running.each do |op|
      op.temporary[:nanograms] = op.input(NANO).val.strip.split(/[\s,]+/).map { |ng| ng.to_i }
      
      if op.temporary[:nanograms].length != op.input_array(STOCKS).length
        log_info op.temporary[:nanograms]
        op.error :ERROR, "Please provide equally-sized lists of stocks and nanograms."
      end
    end
  end
  
  def combine_plasmids
    operations.running.each do |op|
      tab = [["Input Stock", "Volume (uL)"]]
      op.input_array(STOCKS).items.each_with_index do |s, idx|
        vol = (op.temporary[:nanograms][idx] / s.get(:concentration).to_f).round(1)
        tab.push [s.id, { content: vol, check: true }]
      end

      show do
        title "Combine plasmids for #{op.output(STOCK).sample.name}"

        note "Label a new tube #{op.output(STOCK).item.id}. This will be the new stock."

        note "Pipette the following volumes of input stocks into the output stock."
        table tab
      end
    end
  end

end
