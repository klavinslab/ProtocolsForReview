class Protocol
    
    INPUT_A = "A strain"
    INPUT_ALPHA = "Alpha strain"
    OUTPUT = "Mated"
    TUBE_TYPE = "14 mL glass tube"
    MEDIA = "YPAD"
    

  def main

    operations.make
    
    prepare_tubes
    
    operations.retrieve
    
    add_inputs
    
    store_outputs

    {}

  end
  
    def prepare_tubes
        
        show do 
          title "Prepare tubes"
          check "Take #{operations.length} #{TUBE_TYPE}(s)"
          check "Add 3mL of #{MEDIA} to each tube"
        end
        
        show do 
            title "Label tubes"
            operations.each do |op|
                check "#{op.output(OUTPUT).item.id}"
            end
        end
    end
    
    def add_inputs
               
        
        show do 
            title "Add 'A' strains"
            note "Add input strains into output tubes according to table below"
            table operations.start_table
              .input_item(INPUT_A, heading: "Input item")
              .output_item(OUTPUT, heading: "Output item")
              .custom_column(heading: "Transfer") { "2.5 µL" }
              .end_table
        end
        
         show do 
            title "Add 'Alpha' strains"
            note "Add input strains into output tubes according to table below"
            table operations.start_table
              .input_item(INPUT_ALPHA, heading: "Input item")
              .output_item(OUTPUT, heading: "Output item")
              .custom_column(heading: "Transfer") { "5 µL" }
              .end_table
        end
    end
    
    def  store_outputs
        
        show do 
            title "Place yeast matings in 30°C Incubator"
            operations.each do |op|
                check "#{op.output(OUTPUT).item.id}"
            end
        end
        
        show do 
            title "Place input yeast overnights into cleaning sink"
            operations.each do |op|
                check "#{op.input(INPUT_A).item.id}"
                op.input(INPUT_A).item.mark_as_deleted
                op.input(INPUT_A).item.save
                 check "#{op.input(INPUT_ALPHA).item.id}"
                op.input(INPUT_ALPHA).item.mark_as_deleted
                op.input(INPUT_ALPHA).item.save
            end
        end
    end

end