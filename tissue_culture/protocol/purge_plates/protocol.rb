needs "Tissue Culture Libs/TissueCulture"

class Protocol
    include TissueCulture
    
    # io
    OUTPUT = "Cells"
    YES = "Yes"
    NO = "No"
    CHOICES = [YES, NO]

    def main

        operations.retrieve

        # Warning
        show do
            title "Purge Samples Confirmation"
        
            warning "In this protocol you will be destroying all associated plates."
        end

        vops = get_plates_as_vop ALL_PLATES
        
        # vops.extend(OpListExt)
    
        
        t = Proc.new { |ops|
            ops.start_table
            .custom_column(heading: "Item Id") { |op| op.temporary[:plate].id }
            .custom_column(heading: "Sample Name") { |op| op.temporary[:plate].sample.name if op.temporary[:plate].sample }
            .custom_column(heading: "Plate Type") { |op| op.temporary[:plate].object_type.name if op.temporary[:plate].object_type }
            .custom_boolean(:delete, heading: "Destory?") { |op| "y" }
            .end_table.all
            # .validate(:delete) { |op, v| ["y", "n"].include? v.downcase[0] }
            # .end_table
        }
        
        show_with_input_table(vops, t) do
            title "Destroy plates?"
        end
        
        plates = vops.select { |op| op.temporary[:delete] == true }.map { |op| op.temporary[:plate] }
        plates.each { |p| p.mark_as_deleted }
        release_tc_plates plates
        
        
        # operations.each do |op|
        #     items = op.output(OUTPUT).sample.items.select { |i| !i.deleted? }
        #     items.each { |i| i.mark_as_deleted }
        # end
    
        operations.store io: "outout"
    
        return {}
    
    end

end
