needs "Cloning Libs/Large Inoculation"
needs "Cloning Libs/Cloning"
needs "Standard Libs/Feedback"

class Protocol
  include LargeInoculation
  include Cloning
  include Feedback
    
  def main
    inoculation_steps operations, :midiprep
    incubate operations, "shaker", "Small", "Large"
    operations.store
    get_protocol_feedback()
    
    return {}
    
  end

end
