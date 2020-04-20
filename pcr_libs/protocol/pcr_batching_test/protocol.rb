needs 'PCR Libs/GradientPcrBatching'
needs 'Standard Libs/Debug'
class Protocol
  include GradientPcrBatching
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
    pcr_operations = operations.map do |op|
      PcrOperation.new({
        extension_time: op.output(FRAGMENT).sample.properties["Length"] * SEC_PER_KB / 1000,
        anneal_temp: max(op.input(FWD).sample.properties["T Anneal"], op.input(FWD).sample.properties["T Anneal"]),
        unique_id: op.id
      })
    end
    
    result_hash = batch(pcr_operations)
    pcr_reactions = []
    result_hash.each do |thermocycler_group, row_groups|
      reaction = {}
      reaction[:mm], reaction[:ss] = (thermocycler_group.max_extension.to_i).divmod(60)
      reaction[:ops_by_bin] = {}
      sorted_rows = row_groups.to_a.sort { |a,b| a.max_anneal <=> b.max_anneal }
      sorted_rows.each do |row_group|
          reaction[:ops_by_bin][row_group.max_anneal] = [].extend(OperationList)
          row_group.members.sort { |a,b| a.anneal_temp <=> b.anneal_temp }.each do |pcr_op|
            reaction[:ops_by_bin][row_group.max_anneal] << (Operation.find(pcr_op.unique_id))
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
  
end