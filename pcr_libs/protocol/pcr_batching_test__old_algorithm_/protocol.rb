needs 'Cloning Libs/Gradient Pcr'
needs 'Standard Libs/Debug'
class Protocol
  include GradientPCR
  include Debug
    
  # I/O
  FWD = "Forward Primer"
  REV = "Reverse Primer"
  TEMPLATE = "Template"
  FRAGMENT = "Fragment"
  
  # other
  SEC_PER_KB = 30 # sec, extension timer per KB for KAPA
  
  
  def main
    
    require 'benchmark'
    result_hash = nil
    
    time = Benchmark.measure { result_hash = build_pcrs_hash }
    show do
        title "operations batched"
        note "#{time.to_s}" 
    end
    
    log_info result_hash
      
    {}
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
  
end