
needs "Tissue Culture Libs/TissueCulture"

class Protocol
  include TissueCulture
  
  def main
    show do
      title "Replenish inventory and check equipment"
      check "Refill serological pipettes next to the Biosafety cabinet"
      check "Sweep if necessary"
      check "Check on N2 levels for the cryogenic freezer. Log levels on sheet next to cryogenic freezer. Notify manager if below 6 inches"
      check "Check on incubator. Ensure there is enough water in the humidity chamber. Ensure CO2 is set at 5%."
      check "Check on CO2 tank levels. Notify manager if below 500 psi."
      check "Notify manager of any inventory deficiencies"
    end
    
    required_ppe STANDARD_PPE
    
    show do
      title "Clean up BSL2 Room"
      warning "Be sure you are wearing ppe for the next steps (#{STANDARD_PPE.join(', ')})"
      check "If there are bleached plates:"
      note "(1) open flasks/plates; dump liquid down sink drain."
      note "(2) briefly rinse with water; dump down drain"
      note "(3) toss plates into Biohazard Bin"
      check "Check aspirator flask on the floor to the right of the biosafety cabinet. If its full, carefully bleach the liquid in the flask. Wait 20 minutes and dump it down the drain."
      check "Take out waste if full"
    end
    return {}
  end #main
end #protocol
