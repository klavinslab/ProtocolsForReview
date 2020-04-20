# Author: Justin Vrana, 2017-07-20

class Protocol
    
    # io
    INPUT = "Glycerol Stock"
    OUTPUT = "Plasmid Plate"
    BATCH = "Agar Plate Batch"
    
    # Creates initials from a name
    def name_initials str
        full_name = str.split
        begin
          cap_initials = full_name[0][0].upcase + full_name[1][0].upcase
        rescue
          cap_initials = ""
        end
        return cap_initials
    end
    
    # Matches the marker of the operation input to plate collections
    # and assigns plate batches to the operation's temporary[:batch] key
    # Assigns a plate_type of the media sample name contained in the batch.
    def assign_plates_from_batch ops
        # Find all non-empty media collections
        batches = Collection.where(object_type_id: ObjectType.find_by_name(BATCH)).select { |b| !b.empty? }
        
        # Group operations based on plasmid Bacterial Marker
        grouped_by_marker = ops.group_by { |op|
            op.input(INPUT).sample.properties["Bacterial Marker"].upcase
        }
        
        grouped_by_marker.each do |marker, ops|
            matching_batches = batches.select { |b| 
                # Select only batches with a single media type
                all_samples = b.matrix.flatten.uniq.reject { |x| x == -1 }
                is_uniform = all_samples.size == 1
                
                # Media sample contained in the batch
                first_sample = Sample.find_by_id(all_samples.first)
                
                # Split apart the name of the Media (currently uses '+' as a separator)
                media_info = first_sample.name.split(/\s+/).reject { |x| x == "+" }
                
                # Base media. E.g. LB or SOC
                base = media_info[0].upcase
                
                # List of antibiotics in upcase
                antibiotics = media_info.slice(1,media_info.size).map { |x| x.upcase }
                
                # Defines how to match a plasmid marker to the markers designated in the Media sample name
                # def match_markers plasmid_marker, media_marker
                    # not implemented
                # end
                
                # Select plates with only one sample type and those that match the input plasmid marker
                all_samples.size == 1 and antibiotics == [marker.upcase]
            }
            
            # Flatten out the array of all plates by [batch, row, col]
            batch_arr = matching_batches.map { |b| b.get_non_empty.map { |r, c| [b, r, c] } }.flatten(1)
            
            # Match each available plate to an operation
            ops.zip(batch_arr).each do |op, b|
                if b.nil?
                    op.error :no_plates_found, "Could not find plates for marker #{marker}."
                else
                    batch, row, col = b
                    plate_type = Sample.find_by_id batch.matrix[row][col]
                    op.temporary[:plate_type] = plate_type.name
                    op.temporary[:batch] = batch
                end
            end
        end
    end
    
    def main
        # Retrieve input items, but hold off on asking technician to go to -80C
        operations.retrieve interactive: false
        
        # Assign batches based on current operation list
        assign_plates_from_batch operations
        
        # Group by :plate_type (plate_type is the name of the sample the plate collection contains)
        g_by_plate_type = operations.running.group_by { |op| op.temporary[:plate_type] }
        
        # Exit if there are no plates found
        if g_by_plate_type.empty?
            show do
                title "No plates found"
                
                note "There were no plates found."
                note "Have the manager schedule plates to be produced."
            end
            
            operations.store interactive: true
            
            return {} 
        end
        
        # Create output items
        operations.running.make
        
        # Remove plates from fridge
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
        
        # Assign initials
        operations.each do |op|
            op.temporary[:initials] = name_initials op.input(INPUT).sample.user.name
        end
        
        # Label plates
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
        
        # Plate from glycerol stock
        show do
            title "Plate Glycerol Stock"
            
            check "Using a sterile 100 uL pipette, gently streak a small amount of cells from glyceorl stock onto the corresponding plate."
            warning "Minimize thawing of glycerol stocks."
            table operations.running.start_table
                  .input_item(INPUT, heading: operations.first.input(INPUT).item.object_type.name)
                  .custom_column(heading: "#{operations.first.input(INPUT).item.object_type.name} Location") { |op| op.input(INPUT).item.location }
                  .output_item(OUTPUT, checkable: true)
                  .end_table      
        end
        
        # Move plates
        operations.running.each do |op|
            op.output(OUTPUT).item.associate :from, op.input(INPUT).item.id 
            op.output(OUTPUT).item.move "37C Incubator"
        end
        
        # Store inventory
        operations.store
        
        return {}
        
    end
    
end