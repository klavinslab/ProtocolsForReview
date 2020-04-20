needs "Yeast Display/YeastDisplayHelper"

module PrepareTreatmentDilutions
    
    include YeastDisplayHelper
    
    # Dilute treatments to the appropriate concentrations for the assay.
    #
    def prepare_treatment_dilutions(args)
        ops_by_treatment_sample = operations.group_by { |op| op.input(args[:treatment_handle]).sample }
        
        ops_by_treatment_sample.each do |treatment_sample, ops|
            no_prot_ops, some_prot_ops = ops.partition { |op| op.temporary[:treatment_qty].zero? }
            
            if no_prot_ops.present?
                # TODO: this doesn't work if the no treatment controls have different buffers
                # But may not be a problem
                inc_bfr = no_prot_ops.first.input(args[:buffer_handle]).sample.name
             
                tube_labels = no_prot_ops.map { |op| treatment_tube_label(op, args[:output_handle]) }.join("\", \"")
                buffer_qty = qty_display(args[:treatment_working_qty])
                
                show do
                    title "Set up no treatment buffer aliquots"
                    note temp_instructions(args[:temp])
                    
                    note "You will need #{no_prot_ops.length} 1.5 ml microfuge tubes."
                    check "Label the tubes \"#{tube_labels}\"."
                    check "Add #{buffer_qty} #{inc_bfr} to each tube."
                end
            end
            
            if some_prot_ops.present?
                show do
                    title "Set up #{treatment_sample.name} treatment dilutions"
                    note temp_instructions(args[:temp])
                    
                    note "You will need #{some_prot_ops.length} 1.5 ml microfuge tubes."
                    
                    units = args[:treatment_working_qty][:units]
                    
                    note LABEL_TUBES_FROM_TABLE
                    table some_prot_ops.extend(OperationList).start_table
                        .custom_column(heading: "Tube label") { |op| treatment_tube_label(op, args[:output_handle]) }
                        .input_item(args[:treatment_handle])
                        .custom_column(heading: "Treatment (#{units})", checkable: true) { |op| op.temporary[:treatment_qty].round(1) }
                        .custom_column(heading: "Buffer") { |op| op.input(args[:buffer_handle]).sample.name }
                        .custom_column(heading: "Buffer (#{units})", checkable: true) { |op| op.temporary[:buffer_qty].round }
                        .end_table
                end
            end
        end
    end
    
end