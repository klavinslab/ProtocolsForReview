def precondition(_op)
  # gain access to operation instance methods 
  op = Operation.find(_op.id)
  
  # verify input parameters
  ovn_antibiotic = op.input("Overnight Antibiotic").val
  exp_antibiotic = op.input("Experimental Antibiotic").val
  media_type = op.input("Type of Media").val
  inducers = op.input("Inducer(s) as  {\"name\": mM_concentration}").val
  
  valid_inducers = ["Arabinose".to_sym, "IPTG".to_sym, "None".to_sym]
  
  inducers.each do |k, v|
      if !valid_inducers.include?(k)
          op.associate("Invalid inducer choice.", "Currently the only available inducers are #{valid_inducers}")
          return false
      end
  end
  
  
  # pass input sample and set to done, allowing downstream operations to begin
  op.pass("Target Sample", "Induction Condition")

  # set status to done, so this block will not be evaluated again
  op.status = "done"
  op.save
end