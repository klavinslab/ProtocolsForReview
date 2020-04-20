needs "Tissue Culture Libs/TissueCulture"

# TODO: Add specific media
# TODO: Don't let number of wells be greater than container size
class Protocol
    include TissueCulture
    
    # io
    INPUT = "Cell Request"
    OUTPUT = "Plate"
    SEED = "Seed Density (%)"
    WELLS = "Number of Wells"
    
    # debug
    TEST_PROTOCOL_BRANCHING = true

    def volume_calculations ops
        ops.each do |op|
            ot = op.output(OUTPUT).object_type
            op.temporary[:capacity] = ot.rows * ot.columns
            # Calculate how many cells to use
        end
    end

    def main

        operations.retrieve
        
        # custom make
        operations.running.each do |op|
            number_of_wells = op.input(WELLS).val.to_i
            ot = op.output(OUTPUT).object_type
            if number_of_wells > ot.rows * ot.columns
                op.error :too_many_wells, "There were too many wells (max #{op.output(OUTPUT)})."
            else 
                c = op.output(OUTPUT).collection
                number_of_wells.times { c.add_one op.output(OUTPUT).sample }
            end
        end
        
        ###############################
        ## Calculations
        ###############################
        
        volume_calculations operations.running
        
        if debug
            operations.each do |op|
                op.set_input WELLS, 5
            end
        end
        
        
        # DEBUG Tables
        tin = operations.io_table "input"
        tout = operations.io_table "output"

        show do
            title "IO Tables"
            table operations.io_table("input").all.render
            table operations.io_table("output").all.render
        end
        
        # operations.running.make
        
        show do
            title "Collections"
            
            operations.each do |op|
                note "#{op.output(OUTPUT).collection.matrix}"
            end
        end
        
        return {}

    end

end