module StripwellMethods
    
    def prepare_stripwell sw, vol, media="DI Water"
        show do 
            title "Label Stripwells"
            sw.each do |sw|
                if sw.num_samples <= 6 
                   wells = 6
                else
                    wells = 12
                end
                note "Grab a new stripwell with #{wells} wells; label it with ID #{sw.id}, and pipette #{vol} of #{media} into well(s) #{sw.non_empty_string}."
            end
        end
    end
    
    def transfer_to_stripwell ops, input={}, output={}, collection=false, vol
        x = Table.new
        x.add_column("Volume", [vol] * ops.length )
        
        input.each do |h, i|
            x.add_column(i + " ID", ops.map { |op| op.input(i).item.id })
            x.add_column(h, ops.map { |op| op.input(i).column }) if collection
        end
        
        output.each do |h, o|
            x.add_column(o + " ID", ops.map { |op| op.output(o).item.id }) 
            x.add_column(h, ops.map { |op| op.output(o).column })
        end
        
        show do 
            title "Transfer to stripwell"
            note "Transfer the samples according to the following table: "
            table x 
        end
        
    end
    
    def pick_colony_from_plate_into_stripwell ops, input, output, num
        
        x = Table.new
           
        ops.each do |op| 
            num_col = num || op.input(col).val
            op.temporary[:col] = num_col.each_with_index.map { |c, i| "c#{i + 1}" }
        end
            
        x.add_column(input + "ID", ops.map { |op| [op.input(input).item.id] * op.input(col).val }.flatten! )
        x.add_column("Colony", ops.map { |op| op.temporary[:col] }.flatten!  )
        x.add_column("Location", sw.each_with_index.map { |s, i| i + 1 } )
        
        show do 
            title "Load stripwell"
            note "For each plate id.cx (x = 1,2,3,...), if a colony cx is not marked on the plate, mark it with a circle and write done cx (x = 1,2,3,...) nearby. If a colony cx is alread marked on the plate, scrape that colony."
            note "Use a sterile 10 µL tip to scrape about 1/3 of the marked colony. Swirl tip inside the well until mixed."
            
            sw = ops.first.output(output).collection
            title "Load Stripwell #{sw.id}"
            
            table x 
        end
    end
    
    def put_in_thermocycler ops
    end
    
    
end