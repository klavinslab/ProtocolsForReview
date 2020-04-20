
class Protocol 
    def main
      operations.retrieve.make


      show do 
        title "Centrifuge Samples" #1 uL assumes glycogen is 20ug/uL from sigma aldrich
        check "set the medium centrifuge to 4 degrees Celsius"
        check "centrifuge all samples at 16,000 g for 15 minutes"
        check "Carefully remove the supernatant."
        warning "There may or may not be a visible pellet."
      end
  
      show do
        title "Make 70% ethanol"
        if operations.length < 3 then check "Grab a 1.5 mL eppendorf tube and label it with '70% etOH'" else check "Grab a 15 mL falcon tube and lable it with '70% etOH'" end
        check "add #{300 * operations.length} uL of molecular grade water to the tube labeled '70% etOH'"
        check "add #{700 * operations.length} uL of 100% ethanol to the tube labeled '70% etOH'"
      end
      show do
        title "Wash with 70% ethanol"
        check "Add 750 uL of 70% ethanol from the tube labeled '70% etOH' to all the sample tubes, then relabel the tubes according to the table below."
        warning "Do NOT vortex!"
        check "centrifuge the samples for 3 minutes at 16,000 g"
        check "remove the supernatant"
        check "Allow the samples to air dry at 42 degrees C for 15 minutes. make labels for the tubes according to the table below."
        table operations.start_table
          .input_item("DNA", heading: "Old Label")
          .output_item("Purified Plasmid", heading: "New label")
        .end_table
        timer initial: {hours: 0, minutes: 15, seconds: 0} 
        check "resuspend each sample in molecular grade water according to the table below:"
        table operations.start_table
            .output_item("Purified Plasmid")
            .custom_column(heading: "molecular grade water (uL)", checkable: true) { |op| if op.input("DNA").item.get_association("concentration") == nil then "15".to_f.round(1) elsif (op.input("DNA").item.get_association("concentration").value.to_f*48)/150.round(1) < 6 then "6".to_f.round(1) else "15".to_f.round(1) end}
        .end_table
      end
      
      #if op.input("DNA").item.get_association("concentration") == nil then "50".to_f.round(1) elsif (op.input("DNA").item.get_association("concentration").value.to_f*48)/150.round(1) < 6 then "6".to_f.round(1) else (op.input("DNA").item.get_association("concentration").value.to_f*48)/150.round(1) end
      
      operations.each do |op|
          op.output("Purified Plasmid").item.associate(:volume, if op.input("DNA").item.get_association("concentration") == nil then "13".to_f.round(1) elsif (op.input("DNA").item.get_association("concentration").value.to_f*48)/150.round(1) < 6 then "4".to_f.round(1) else "13".to_f.round(1) end) #18 or 4 because of nanodrop
          
      end
      

     responses = show do 
        title "Nanodrop and Enter Concentration"
        note "Nanodrop each purified plasmid and enter the concentration below"
        table operations.start_table
            .output_item("Purified Plasmid")
            .get(:concentration, type: "number", heading: "Concentration", default: 200)
        .end_table
      end
      

      dilute_operations = operations.select {|op| responses.get_table_response(:concentration, op: op).to_f >= 120} 
      notify_operations = operations.select {|op| responses.get_table_response(:concentration, op: op).to_f <= 80}
      normal_operations = operations.select {|op| responses.get_table_response(:concentration, op: op).to_f > 80 and responses.get_table_response(:concentration, op: op).to_f < 120}
      
     
     # operations.each do |op|
      #    if responses.get_table_response(:concentration, op: op).to_f >= 120
       #       dilute_operations.push op
        #  elsif responses.get_table_response(:concentration, op: op).to_f <= 80
         #       notify_operations.push op
          #  else
           #     normal_operations.push op
          #end
          
    #    end
    
    #((((op.output("Purified Plasmid").item.get_association("volume").value.to_f.round(1))*responses.get_table_response(:concentration, op: op).to_f)/110 - (op.output("Purified Plasmid").item.get_association("volume").value.to_f.round(1))).round(1))
      
     if dilute_operations != nil
          show do
              title "Dilute Outputs"
              check "add molecular grade water to the following tubes according to the table below:"
              table dilute_operations.start_table
                .output_item("Purified Plasmid")
                .custom_column(heading: "molecular grade water (uL)", checkable: true) {|op| ((((op.output("Purified Plasmid").item.get_association("volume").value.to_f.round(1))*responses.get_table_response(:concentration, op: op).to_f)/110 - (op.output("Purified Plasmid").item.get_association("volume").value.to_f.round(1))).round(1))}
              .end_table
          end
      
         dilute_operations.each do |op|
            op.output("Purified Plasmid").item.associate(:concentration, "110")
            op.output("Purified Plasmid").item.associate(:volume, (((op.output("Purified Plasmid").item.get_association("volume").value.to_f.round(1))*responses.get_table_response(:concentration, op: op).to_f)/110))
        end
     end
     
     if notify_operations != nil
         show do
             title "Notify managers about low concentrations"
             note "notify the managers that these outputs have too low concentrations"
             notify_operations.each do |op|
                 check "#{op.output("Purified Plasmid").item.id}"
             end
         end
        notify_operations.each do |op|
            op.output("Purified Plasmid").item.associate(:concentration, responses.get_table_response(:concentration, op: op))
        end
     end
     
     if normal_operations != nil
        normal_operations.each do |op|
            op.output("Purified Plasmid").item.associate(:concentration, responses.get_table_response(:concentration, op: op))
        end
         
     end

      
        
      operations.each do |op|
        op.input("DNA").item.mark_as_deleted
      end
      operations.store
    end


end

