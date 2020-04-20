needs "Tissue Culture Libs/TissueCulture"

class Protocol
    include TissueCulture

    # io
    INPUT = "Cell Request"
    OUTPUT = "Well"
    SEED = "Seed Density (%)"
    EXPERIMENT = "Experiment Name"
    
    # debug
    TEST_PROTOCOL_BRANCHING = true
    TEST_EXPERIMENT_GROUPING = true
    
    # Determines the required number of cells to plate the output plate
    def required_cells op
        out_plate = op.output(OUTPUT).extend(CellCulture)
        mx = out_plate.max_cell_number
        mx * op.input(SEED).val / MAX_CONFLUENCY
    end

    # Creates a nicely formated top label table for the technician
    def create_top_labels ops
        now = Time.now
        ops.each do |op|
            item = op.output(OUTPUT).item
            temporary_label = op.temporary[:output_label]
            item_label = ""
            if item
                temporary_label = temporary_label.strike.add_tag("font", color: "red")
                item_label = " " + op.output(OUTPUT).item.id.to_s.bold.add_tag("font", color: "green")
            end

            op.temporary[:top_label] = \
                "<table style=\"width:100%\">
                    <tr><td>#{temporary_label}#{item_label}</td></tr>
                    <tr><td>#{op.output(OUTPUT).sample.name}</td></tr>
                    <tr><td>#{now.strftime("%a %m/%d/%y") }</td></tr>
                    <tr><td>P: #{ op.temporary[:passage] }</td></tr>
                    <tr><td>Seed: #{ op.input(SEED).val }%</td></tr>
                </table>"
        end
    end

    # Calculates volumes required for plating cells
    def volume_calculations ops
        ops.each do |op|
            p = op.input(INPUT).item.get :passage
            op.temporary[:passage] = p + 1 if p
            op.temporary[:passage] ||= "unknown"
            op.temporary[:req_cells] = required_cells(op)
            op.temporary[:cell_vol] = (op.temporary[:req_cells] / op.input(INPUT).item.get(:cell_density))
            op.temporary[:media_vol] = working_volume_of(op.output(OUTPUT).object_type) - op.temporary[:cell_vol]
            op.temporary[:media_vol] = 0 if op.temporary[:media_vol] < 0
            op.temporary[:volume] = op.temporary[:cell_vol] + op.temporary[:media_vol]
        end
    end

    # Associate passage number, confluency, from
    def output_associations ops
        ops.each do |op|
            m = op.output(OUTPUT).collection.get :from
            m ||= op.output(OUTPUT).collection.matrix
            
            m[op.output(OUTPUT).row][op.output(OUTPUT).column] = op.input(INPUT).item.id
            op.output(OUTPUT).item.associate :from, m
            
            # op.output(OUTPUT).item.associate :passage, op.temporary[:passage]
            # op.output(OUTPUT).item.extend(CellCulture).confluency = op.input(SEED).val
            # op.output(OUTPUT).item.associate :from, op.input(INPUT).item.id
        end
    end
    
    def error_out_operations ops
        # Error out operations that have too much volume
        ops.each do |op|
            if op.temporary[:volume] > 1.5 * op.output(OUTPUT).extend(CellCulture).working_volume
                op.error :over_volume, "There was too much volume in well to proceed."
            end
        end
        
        ops.each do |op|
            if op.temporary[:cell_vol] > op.input(INPUT).item.get(:volume)
                op.error :not_enough_cells, "There is not enough cells"
            end
        end
    end

    def main

        operations.retrieve
        
        ###############################
        ## Calculations
        ###############################

        # Error if plate request was never changed
        operations.running.each do |op|
            if op.input(INPUT).item.object_type.name == "Trypsinized Plate Request"
                op.error :rewiring_error, "Something went wrong with the rewiring of Request > Trypsinized Plate. \
                    Input to this operation does not physically exist."
            end
        end

        # Test protocol branching
        if debug and TEST_PROTOCOL_BRANCHING and operations.running.size >= 2
            operations.running[1].input(INPUT).set item: operations.first.input(INPUT).item
        end

        # Assign experiment name
        if debug
            operations.each do |op|
                op.set_input EXPERIMENT, "Control"
            end
        end
        
        operations.each do |op|
            experiment_specs = [op.input(EXPERIMENT).val, op.output(OUTPUT).object_type.name]
            # experiment_specs += [op.user.login]
            op.temporary[:experiment] = experiment_specs.join("_")
        end
        
        if debug and TEST_EXPERIMENT_GROUPING
            operations.first.temporary[:experiment] = "Replicate"
        end
    
        # Assign fake confluency, cell density and volume data
        if debug
            operations.running.each do |op|
                plate = op.input(INPUT).item.extend(CellCulture)
                plate.associate :volume, rand(5..40)
                cd = rand(1e6 * rand(1..10))
                plate.associate(:cell_density, cd)
                plate.associate :from, rand(1000..5000)
            end
        end

        operations.running.each do |op|
            op.error :no_volume_data, "The volume of this item was not properly set." unless op.input(INPUT).item.get(:volume)
            op.error :no_cell_density_data, "The cell density of this item was not properly set." unless op.input(INPUT).item.get(:cell_density)
        end

        volume_calculations operations.running

        error_out_operations operations.running
        
        # Create temporary labels
        # TODO: Fix temporary labels
        grouped_by_input = operations.running.group_by {|op| op.input(INPUT).item}
        
        # Assign fake temporary labels if debug
        grouped_by_input.keys.zip(('A'..'Z').to_a).each { |input_plate, label|
            input_plate.associate :temporary_label, label if not input_plate.get :temporary_label
        } if debug
        
        # TODO: Change output label to be A1, A2, A3,...D1, D2, D3, D4 etc. for multi-well dishes
        grouped_by_input.each do |i, ops|
            input_label = i.get(:temporary_label)
            input_label ||= i.get(:from)
            ops.each.with_index do |op, index|
                op.temporary[:input_label] = "#{input_label}"
                op.temporary[:output_label] = "#{input_label}-#{index}"
            end
        end

        # Make a collection per experiment
        group_by_experiment = operations.running.group_by { |op| op.temporary[:experiment] }
        group_by_experiment.each do |experiment, ops|
            collections = Collection.spread ops.map { |op| op.input(INPUT).sample }, ops.first.output(OUTPUT).object_type.name
            col_r_c = collections.map { |collection| collection.get_non_empty.map { |r, c| [collection, r, c] } }.flatten(1)
            raise "Collection make error, wrong size" unless col_r_c.size == ops.size
            ops.zip(col_r_c) do |op, x|
                op.output(OUTPUT).make_part x[0], x[1], x[2]
            end
        end

        show do
            title "Calculations"

            table operations.running.start_table
                      .input_item(INPUT)
                      .custom_column(heading: "Input Label") { |op| op.temporary[:input_label]}
                      .custom_column(heading: "Input Type") { |op| op.input(INPUT).item.object_type.name }
                      .custom_column(heading: "Output Label") { |op| op.temporary[:output_label]}
                      .custom_column(heading: "Output Type") { |op| op.output(OUTPUT).item.object_type.name }
                      .custom_column(heading: SEED) { |op| op.input(SEED).val}
                      .custom_column(heading: "Cell density") { |op| op.input(INPUT).item.get :cell_density}
                      .custom_column(heading: "From") { |op| op.input(INPUT).item.get :from}
                      .custom_column(heading: "Req Cells") { |op| to_scinote(required_cells(op))}
                      .custom_column(heading: "Cell Vol (ul)") { |op| (op.temporary[:cell_vol]*1000).round(1) }
                      .custom_column(heading: "Available Vol") { |op| op.input(INPUT).item.get(:volume) }
                      .custom_column(heading: "Experiment") { |op| op.temporary[:experiment] }
                      .end_table
        end if debug

        
        grouped_by_collection = operations.running.group_by { |op| op.output(OUTPUT).collection }
        collections = grouped_by_collection.keys
        
        grouped_by_object_type = operations.running.group_by {|op| op.output(OUTPUT).object_type}


        ###############################
        ## End Calculations
        ###############################





        ###############################
        ## Technician instructions
        ###############################

        operations.running.each do |op|
            # op.input(INPUT).item.mark_as_deleted
            op.input(INPUT).item.move HOOD
        end
        
        # Retrieve plates
        
        show do
            title "Retrieve the following plates and place them in the #{HOOD}"
            t = Table.new
            t.add_column("Plate Type", grouped_by_object_type.keys.map {|o| o.name})
            t.add_column("Quantity", grouped_by_object_type.map {|o, ops| ops.map { |op| op.output(OUTPUT).collection }.uniq.size })
            table t
        end
        
        # Label plates
        show do
            title "Label multiwell plates"
            
            note "Label the following:"
            bullet "Item id"
            bullet "Experiment"
            bullet "Date"
            
            t = Table.new
            t.add_column("Type", collections.map { |c| c.object_type.name })
            t.add_column("Item Id", collections.map { |c| c.id } )
            t.add_column("Experiment", grouped_by_collection.map { |c, ops| ops.first.temporary[:experiment] } )
            t.add_column("Date", collections.map { |c| today_string })
            table t
        end

        grouped_by_collection.each do |collection, ops|
            show do
                title "Transfer media to plate #{collection.id}"
                
                id_block = Proc.new { |op| "#{(op.temporary[:media_vol].round(2)*1000).to_i} uL" }
                tables = highlight_collection(ops, id_block) { |op| op.output(OUTPUT) }
                tables.each do |c, t|
                    note "#{c.object_type.name} #{c.id}"
                    table t
                end
            end
        end

        # Transfer cells
        grouped_by_input.each do |input_plate, ops|
            col_group = ops.group_by { |op| op.output(OUTPUT).collection }
            
            show do
                title "Move #{input_plate} to central position"
            end
            
            col_group.each do |collection, ops2|
                show do
                    title "Transfer cells from #{input_plate.object_type.name} #{input_plate.id} <span>&#8594;</span> #{collection.object_type.name} #{collection.id}" 
                    
                    id_block = Proc.new { |op| "#{(op.temporary[:cell_vol].round(2)*1000).to_i} uL" }
                    tables = highlight_collection(ops2, id_block) { |op| op.output(OUTPUT) }
                    tables.each do |c, t|
                        note "#{c.object_type.name} #{c.id}"
                        table t
                    end
                end
            end
        end

        ###############################
        ## End Technician instructions
        ###############################

        if debug
            tin = operations.io_table "input"
            tout = operations.io_table "output"
    
            show do
                title "Input Table"
                table tin.all.render
            end
    
            show do
                title "Output Table"
                table tout.all.render
            end
        end
        
        output_associations operations.running

           operations.running.make
    
          operations.running.each do |op|
            fv = op.input(INPUT)
            cell_suspension = fv.collection
            cell_suspension.set fv.row, fv.column, -1
            cell_suspension.mark_as_deleted if cell_suspension.empty?
        end

        operations.store



        show do
            title "Move trypsinized plates aside in #{HOOD}"
        end
        # release_tc_plates operations.running.map {|op| op.input(INPUT).item}
        
        return {}

    end

end
