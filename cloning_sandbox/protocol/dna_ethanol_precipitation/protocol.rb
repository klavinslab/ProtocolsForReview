
class Protocol 
    def main
        operations.retrieve.make
      
        record_volume_tab = operations.start_table
                                .input_item("DNA", heading:"Input Tube ID")
                                .get(:vol, type: "number", heading: "Estimate the volume of stock") { |op| 0 }
                                .end_table
                                
        responses = show do
            title "Estimate Stock Volume"
            table record_volume_tab
        end
        
        parrot_tab = operations.start_table
                        .input_item("DNA")
                        .custom_column(heading: "glyogen (20ug/uL)", checkable: true) { |op| "#{(responses.get_table_response(:vol, op: op).to_f / 50).ceil * 1} uL"}
                        .custom_column(heading: "sodium acetate (3 M, pH 5.2)", checkable: true) { |op| "#{(responses.get_table_response(:vol, op: op).to_f / 50).ceil * 4.9} uL"}
                        .custom_column(heading: "100% ethanol", checkable: true) { |op| "#{(responses.get_table_response(:vol, op: op).to_f / 50).ceil * 135} uL"}
                        .end_table
                        
        show do
            title "Add to Tubes"
            table parrot_tab
        end
        
        show do
            title "Relabel Tubes"
            table operations.start_table
              .input_item("DNA", heading: "Old Label")
              .output_item("Plasmid Stock in Ethanol", heading: "New label", checkable: true)
            .end_table
        end
        
        operations.each do |op|
            op.input("DNA").item.mark_as_deleted
        end
        
        operations.store
        show do
            title "Notify a Manager"
            check "Let a manager know you are done with the protocol and set a timer if needed."
        end
    end
end

