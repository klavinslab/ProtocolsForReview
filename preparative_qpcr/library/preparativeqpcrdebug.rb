needs "Standard Libs/CommonInputOutputNames"

module PreparativeqPCRDebug
    
    include CommonInputOutputNames

    def override_input_operations(use_collection:, sample_scheme:, program:)
        n_ops = 14
        case sample_scheme
        when "common"
            forward_primers, reverse_primers = common_primers(n_ops)
            ot_name = "Primer Mix Stock"
        when "two forward"
            forward_primers = two_forward_primers(n_ops)
            reverse_primers = indexing_reverse_primers
            ot_name = "Primer Aliquot"
        when "three samples"
            forward_primers = three_sample_forward_primers
            reverse_primers = three_sample_reverse_primers
            ot_name = "Primer Aliquot"
        when "reverse indexing"
            forward_primers = one_forward_primer(n_ops)
            reverse_primers = indexing_reverse_primers
            ot_name = "Primer Aliquot"
        else
            raise "Sample scheme #{sample_scheme} not recognized for debug."
        end
    
        unless operations.length == n_ops
            raise "This configuration must be tested with #{n_ops} operations."
        end
        
        operations.each do |op|
            fwd_primer_sample = Sample.find_by_name(forward_primers.shift)
            fwd_primer_item_id = fwd_primer_sample.in(ot_name).first.id
            
            op.input(FORWARD_PRIMER).update_attributes(
                child_sample_id: fwd_primer_sample.id,
                child_item_id: fwd_primer_item_id
            )
            
            rev_primer_sample = Sample.find_by_name(reverse_primers.shift)
            
            if use_collection
                rev_primer_item_id = 315619
                collection = Collection.find(rev_primer_item_id)
                row, column = collection.position(rev_primer_sample)
            else
                rev_primer_item_id = rev_primer_sample.in(ot_name).first.id
                row = nil
                column = nil
            end
            
            
            op.input(REVERSE_PRIMER).update_attributes(
                child_sample_id: rev_primer_sample.id,
                child_item_id: rev_primer_item_id,
                row: row, column: column
            )
            
            op.set_input(PROGRAM, program)
        end
        
        show do
            title ""
            table operations.start_table
                            .custom_column(heading: "Template") { |op| op.input("Template").sample.name }
                            .custom_column(heading: "Forward Primer") { |op| op.input("Forward Primer").sample.name }
                            .custom_column(heading: "Reverse Primer") { |op| op.input("Reverse Primer").sample.name }
                            .custom_column(heading: "Program") { |op| op.input("Program").val }
                            .custom_column(heading: "Fragment") { |op| op.output("Fragment").sample.name }
                            .end_table
        end
    end
    
    def indexing_reverse_primers
        [
            "P7-finish_TSBC14-r",
            "P7-finish_TSBC13-r",
            "P7-finish_TSBC12-r",
            "P7-finish_TSBC11-r",
            "P7-finish_TSBC10-r",
            "P7-finish_TSBC09-r",
            "P7-finish_TSBC08-r",
            "P7-finish_TSBC07-r",
            "P7-finish_TSBC06-r",
            "P7-finish_TSBC05-r",
            "P7-finish_TSBC04-r",
            "P7-finish_TSBC03-r",
            "P7-finish_TSBC02-r",
            "P7-finish_TSBC01-r"
        ].reverse
    end
    
    def one_forward_primer(n_ops)
        Array.new(n_ops, "forward primer")
    end
    
    def two_forward_primers(n_ops)
        Array.new(n_ops - 9, "forward primer") + Array.new(9, "Kozak_GFP_fwd")
    end
    
    def common_primers(n_ops)
        [Array.new(n_ops, "Petcon Forward"), Array.new(n_ops, "Petcon Reverse")]
    end
    
    def three_sample_templates
        Array.new(5, 'G.J.R DNA library') + Array.new(6, 'Ta-Yi Library') + Array.new(3, 'yeast promoter v2_14 (Genomic Prep)')
    end
    
    def three_sample_forward_primers
        Array.new(5, "forward primer") + Array.new(6, 'PS-TRP_fwd') + Array.new(3, "Kozak_GFP_fwd")
    end
    
    def three_sample_reverse_primers
        Array.new(5, "P7-finish_TSBC01-r") + Array.new(6, "P7-finish_TSBC02-r") + Array.new(3, "P7-finish_TSBC03-r")
    end
    
    def three_sample_fragments
        Array.new(5, 'G.J.R DNA library') + Array.new(6, 'Ta-Yi Library') + Array.new(3, 'yeast promoter v2_14 (Genomic Prep)')
    end
    
end