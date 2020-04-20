needs "Cloning Libs/Midiprep + Maxiprep"
needs "Standard Libs/Feedback"

class Protocol
  include Feedback
  include MidiprepMaxiprep
    
  def main
    
    midimaxi_steps operations, :maxiprep
    
    get_protocol_feedback()
    
    return {}
    
  end

end
