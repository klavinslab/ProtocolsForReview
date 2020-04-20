needs "OLASimple/OLAConstants"

class Protocol
  include OLAConstants
  
  def main
      
    show do
        title "This protocol assigns creates two samples and assigns a kit number " \
        "for the rest of the OLASimple protocol."
    end
    
    # do pre workflow checks
    if operations.length > 1
        raise "Batch size greater than 2 not supported. Please have supervisor rebatch." 
    end

    kit_nums = operations.map { |op| op.input("Kit Number").value }
    if kit_nums.length > 1
        raise "Multiple kits found. Please replan." 
    end
    kit_num = kit_nums.first
    
    
    operations.retrieve.make
    
    # assign pre-labels to output tubes
    operations.running.each do |op|
        s1 = op.output("Sample 1").item
        s1.associate(KIT_KEY, kit_num)
        s1.associate(UNIT_KEY, "")
        s1.associate(COMPONENT_KEY, "A")
        s1.associate(SAMPLE_KEY, "A")
        s2 = op.output("Sample 2").item
        s2.associate(KIT_KEY, kit_num)
        s2.associate(UNIT_KEY, "")
        s2.associate(COMPONENT_KEY, "A")
        s2.associate(SAMPLE_KEY, "B")
    end
    
    show do
        title "The next protocol is \"OLASimple PCR\"."
        title "Please assign a technician to run kit #{kit_num}."
        warning "Remember, only one technician can run a kit."
    end
    
    return {}
    
  end

end
