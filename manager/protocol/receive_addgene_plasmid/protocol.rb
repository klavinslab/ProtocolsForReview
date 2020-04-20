class Protocol
    
    INPUT = "Plasmid Addgene Order"
    OUTPUT = "Plasmid Agar Stab"
    PLATE = "Plasmid Plate"
    
    def name_initials str
        full_name = str.split
        begin
          cap_initials = full_name[0][0].upcase + full_name[1][0].upcase
        rescue
          cap_initials = ""
        end
        return cap_initials || ""
    end
    
     def main

        operations.retrieve interactive: false
        
        create_table = Proc.new { |ops|
            ops.start_table
                .input_sample(INPUT)
                .custom_column(heading: "Sample name") { |op| op.input(INPUT).sample.name }
                .custom_column(heading: "Addgene Number") { |op| op.input(INPUT).item.get(:addgene_number) || "?" }
                .custom_input(:ready, heading: "Received? (y/n)", type: "string") { |op| 
                    x = "y"
                    # x = ["y", "n"].sample if debug
                    x
                }
                .validate(:ready) { |op, v| ["y","n"].include?(v.downcase[0]) }
                .end_table.all
        }
        
        show_with_input_table(operations, create_table) do
            title "Received?"
            check "For each Addgene id, check to see if it has been receieved."
        end
        
        waiting_operations = operations.select { |op| op.temporary[:ready].downcase[0] != "y" }
        ready_operations =  operations.select { |op| op.temporary[:ready].downcase[0] == "y" }
        
        waiting_operations.each do |op|
            unless op.temporary[:ready] == "y"
                op.plan.error :not_receieved, "Some orders have not been receieved. Please have the manager reschedule this operation."
                op.error :not_receieved, "This order has not yet been receieved. Please have the manager reschedule this errored operation."
                op.save
            end
        end
        
        ready_operations.make
        
        
        if ready_operations.any?
        
            show do
                title "Label agar stabs with the following item ids"
                
                ready_operations.running.each do |op|
                    op.input(INPUT).item.mark_as_deleted
                    n =  op.input(INPUT).item.get(:addgene_number) || "?"
                    op.output(OUTPUT).item.associate :addgene_number, n
                end
                
                table ready_operations.start_table
                    .custom_column(heading: "Sample name") { |op| op.input(INPUT).sample.name }
                    .custom_column(heading: "Addgene Number") { |op| op.input(INPUT).item.get(:addgene_number) || "?" }
                    .output_item(OUTPUT, checkable: true)
                    .end_table
            end
        else
            show do
                title "There are no plates ready"
                
                note "Resetting all operations to \"pending\""
            end
            return {}
        end
        
        keep_stabs = show do
            title "Will you be plating these agar stabs?"
            
            select ["No", "Yes"], var: "keep", label: "Will you be plating these agar stabs soon?", default: 0
        end
        
        if keep_stabs[:keep] == "Yes"
            ready_operations.each do |op|
                op.output(OUTPUT).item.move "bench"
            end
        end
        
        ready_operations.each { |op| op.output(OUTPUT).item.move  "DFAS.0.0" }
        
        ready_operations.store io: "output", interactive: true
        
        return {}
        
    end
    
end
