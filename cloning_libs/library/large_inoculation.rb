module LargeInoculation
    def inoculation_steps operations, type
        media_vol = type == :midiprep ? 62.5 : 250
        inoc_vol = type == :midiprep ? 125 : 250
        
        operations.make
    
        show do
          title "Media preparation in media bay"
            
          if (type == :midiprep)  
            check "Retrieve a 250 mL flask."
          elsif (type == :maxiprep) 
            check "Retrieve a 1L flask."
          end
          check "Label new tubes, and add #{media_vol} mL of media and marker(s) to them according to the following table."
          
          table operations.start_table
            .output_item("Large")
            .custom_column(heading: "Marker", checkable: true) { |op| "TB+" + op.input("Small").sample.properties["Bacterial Marker"][0, 3].capitalize }
          .end_table
        end
    
        operations.retrieve
    
        show do
          title "Inoculation from small overnight"
    
          note "Inoculate #{inoc_vol} µL from each of the following small overnights into the large tubes according to the following table."
    
          table operations.start_table
            .input_item("Small", heading: "Small Overnight ID")
            .output_item("Large", heading: "Large Overnight ID", checkable: true)
          .end_table
        end
        
        show do
          title "Discard overnight"
          
          check "Discard the overnight that went into the dilution."
          
        end
    
        operations.each do |op|
          small_on = op.input("Small").item
          small_on.mark_as_deleted
          small_on.save
        end
    end
end