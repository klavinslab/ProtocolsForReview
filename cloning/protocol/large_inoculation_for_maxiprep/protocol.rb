needs "Cloning Libs/Large Inoculation"
needs "Cloning Libs/Cloning"
needs "Standard Libs/Feedback"

class Protocol

  include LargeInoculation, Cloning, Feedback
    
  def main
    inoculation_steps operations, :maxiprep
    incubate operations, "shaker", "Small", "Large"
    operations.store
    get_protocol_feedback()
    
    return {}
    
  end

end