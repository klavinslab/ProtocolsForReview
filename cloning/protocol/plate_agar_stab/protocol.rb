# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!
needs "Standard Libs/Feedback"
class Protocol
    include Feedback
    INPUT = "Agar Stab"
    OUTPUT = "Plasmid Plate"
    BATCH = "Agar Plate Batch"
    TEMP = "Growth Temperature"
    
    def name_initials str
        full_name = str.split
        begin
          cap_initials = full_name[0][0].upcase + full_name[1][0].upcase
        rescue
          cap_initials = ""
        end
        return cap_initials
    end
    
    def assign_plates_from_batch ops
        batches = Collection.where(object_type_id: ObjectType.find_by_name(BATCH)).select { |b| !b.empty? }
        
        grouped_by_marker = ops.group_by { |op|
            op.input(INPUT).sample.properties["Bacterial Marker"].upcase
        }
        
        grouped_by_marker.each do |marker, ops|
            matching_batches = batches.select { |b| 
                all_samples = b.matrix.flatten.uniq.reject { |x| x == -1 }
                is_uniform = all_samples.size == 1
                first_sample = Sample.find_by_id(all_samples.first)
            
                media_info = first_sample.name.split(/\s+/).reject { |x| x == "+" }
                base = media_info[0].upcase
                antibiotics = media_info.slice(1,media_info.size).map { |x| x.upcase }
            
                all_samples.size == 1 and antibiotics == [marker.upcase]
            }
            
            batch_arr = matching_batches.map { |b| b.get_non_empty.map { |r, c| [b, r, c] } }.flatten(1)

            ops.zip(batch_arr).each do |op, b|
                if b.nil?
                    op.error :no_plates_found, "Could not find plates for marker #{marker}."
                else
                    batch, r, c = b
                    plate_type = Sample.find_by_id batch.matrix[r][c]
                    op.temporary[:plate_type] = plate_type.name
                    op.temporary[:batch] = batch
                end
            end
        end
    end
    
    def main
    
        operations.each do |op|
            t = op.input(TEMP).val.to_f
            t = 37.0 if t == 0
            op.temporary[:temp] = t
        end
    
        operations.retrieve
        assign_plates_from_batch operations
        g_by_plate_type = operations.running.group_by { |op| op.temporary[:plate_type] }
        
        if g_by_plate_type.empty?
            show do
                title "No plates found"
                
                note "There were no plates found."
                note "Have the manager schedule plates to be produced."
            end
            
            operations.store interactive: true
            
            return {} 
        end
        
        operations.running.make
        
        
        show do
            title "Grab plates from fridge"
            
            check "Grab the following plates from the fridge"
        
            g_by_plate_type.each do |plate_type, gops|
                note "<b>#{plate_type}</b>"
                gops.group_by { |op| op.temporary[:batch] }.each do |batch, gops2|
                    check "Batch: #{plate_type} #{batch.id} | Num: #{gops2.size}"
                    # Detract from batch
                    gops2.each do |x|
                        batch.remove_one
                    end
                end
            end
        end
        
        operations.each do |op|
            op.temporary[:initials] = name_initials op.input(INPUT).sample.user.name
        end
        
        show do
            title "Label Plates according to following table"
            
            check "Label with item id, initials, and date"
            
            g_by_plate_type.each do |plate_type, ops|
                note "<b>#{plate_type}</b>"
                table ops.start_table
                    .output_item(OUTPUT, checkable: true)
                    .custom_column(heading: "Plate") { |op| op.temporary[:plate_type] }
                    .custom_column(heading: "Initials") { |op| op.temporary[:initials] }
                    .custom_column(heading: "Date") { |op| Time.now.strftime("%m/%d/%Y") }
                    .end_table
                separator
            end
        end
        
        show do
            title "Plate agar stab"
            
            check "Using a sterile 10 uL pipette tip, stab the agar stab"
            check "Gently rub the tip onto the corresponding plate"
            check "Using a new sterile 10 uL tip streak out the plasmid on the plate"
            
            table operations.running.start_table
                .input_item(INPUT, checkable: true)
                .output_item(OUTPUT, checkable: true)
                .end_table
        end
        
        operations.running.each do |op|
            op.output(OUTPUT).item.associate :from, op.input(INPUT).item.id 
        end
        
        operations.running.each do |op|
            op.output(OUTPUT).item.move "#{op.temporary[:temp].round(0)}C incubator" 
        end
        operations.store
        
        get_protocol_feedback()
        
        return {}
        
    end
    
end
