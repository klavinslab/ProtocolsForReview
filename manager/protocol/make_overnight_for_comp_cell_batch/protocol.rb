#abemill@uw.edu


# begins overnights for cell cultures that will be used to produce e coli comp cell batch tomorrow


needs "Cloning Libs/Cloning"
needs "Standard Libs/Debug"

class Protocol
    
    include Cloning
    include Debug

    def overnight_steps(ops, ot)
        ops.retrieve.make
        
        show do
            title "Label and load overnight tubes"
            note "In the Media Bay, collect <b>#{ops.length}</b> 125mL flasks"
            note "Write the overnight id on the corresponding tube and load with the correct media type."
            table ops.start_table
              .custom_column(heading: "Media") { |op| "LB Liquid Media" }
              .custom_column(heading: "Quantity") { |op| "25 mL" }
              .output_item("Overnight", checkable: true)
              .end_table
        end
    
        show {
            title "Inoculation from #{ot}"
            note "Use 10 µl sterile tips to inoculate colonies from plate into 125 mL flask according to the following table." 
            check "Mark each colony on the plate with corresponding overnight id. If the same plate id appears more than once in the table, inoculate different isolated colonies on that plate." 
            table ops.start_table
              .input_item("Culture", heading: ot)
              .custom_column(heading: "#{ot} Location") { |op| op.input("Culture").item.location }
              .output_item("Overnight", checkable: true)
              .end_table      
        } 
    end

  def main
      
    operations.retrieve(interactive: false)
    
    overnight_steps operations, "Agar Plate"
    
    
    operations.running.each do |op|
        op.output("Overnight").item.move "37 C shaker incubator"
    end
    
    operations.store
    
    return {}

  end 
  
end 