needs "Tissue Culture Libs/TissueCulture"
# TODO: Cross out and add specific item number
# TODO: Add specific media
# TODO: Don't resuspend until next protocol. Create a library for resuspension that runs for requestor protocols
class Protocol
    include TissueCulture

    # io
    INPUT = "Cell Plate"
    OUTPUT = "Trypsinized Cells"
    MEDIA = "Growth Media"
    
    # debug
    TEST_PROTOCOL_BRANCHING = true
    TEST_NO_CONFLUENCY = false

    def main
        operations.retrieve

        # Plate request implementation
        operations.each do |op|
            if op.input(INPUT).item.object_type.name == "Plate Request"
                op.error :not_implemented, "Plate selection is not yet implemented."
            end
        end

        ########## CALCULATIONS ##########
        
        test_debug
        
        operations.running.each do |op|
            c = op.input(INPUT).item.confluency
            op.error :no_confluency, "Plate #{op.input(INPUT).item.id} does not have a confluency." if c.nil?
        end
        
        myops = operations.running

        input_ops = myops.uniq { |op| op.input(INPUT).item }.extend(OperationList) # accounts for branching when making tables
        
        volume_calculations myops

        # Make only one output per input plate (two output from a single plate is disallowed)
        grouped_by_input = myops.running.group_by { |op| op.input(INPUT).item }
        grouped_by_input.each do |input, ops|
            fv = ops.first.output(OUTPUT)
            cell_suspension = fv.make_collection
            cell_suspension.apportion 1, ops.size
            ops.each do |op|
                r, c, x = cell_suspension.add_one op.output(OUTPUT).sample
                op.output(OUTPUT).set row: r, column: c, collection: cell_suspension
            end
            # successors = ops.map { |op| op.output(OUTPUT).successors }.flatten.uniq
            # cell_suspension.apportion 1, successors.size
            # successors.
        end

        # Create temporary and legible labels
        labels = [*('A'..'Z')]
        grouped_by_input.zip(labels).each do |x, l|
            input_plate, ops = x
            ops.each { |op| op.temporary[:input_label] = l }
        end

        myops = myops.running
        input_ops = input_ops.running

        ############ DEBUG CALCULATIONS ############
        if debug
            show do
                title "DEBUG CALCULATIONS"
                table operations.start_table
                          .input_item(INPUT)
                          .custom_column(heading: "Confluency") { |op| op.input(INPUT).item.confluency }
                          .end_table
            end
        end

        ############ PREPARATION ############

        show do 
            title "Overview"
            
            note "You will be trypsinizing the following plates:" 
            table input_ops.start_table
                .input_item(INPUT)
                .custom_column(heading: "Sample Name") { |op| op.input(INPUT).item.sample.name }
                .custom_column(heading: "Plate Type") { |op| op.input(INPUT).item.object_type.name }
                .custom_column(heading: "Confluency") { |op| op.input(INPUT).item.confluency }
                .end_table
        end

        # PPE
        required_ppe(STANDARD_PPE)

        # Stock inventory
        show do
            title "Ensure you have plenty of:"

            note "Disposables".bold
            check "serological pipettes (1mL, 10mL, 25mL, 50mL)"
            check "gloves in your size"
            separator
            note "Decontaminants".bold
            check "70% ethanol for decontamination"
            check "10% bleach for decontamination and spills"
            check "envirocide for decontamination and spills"
        end

        # Preparation of hood etc.
        show do
            title "Preparation"

            note "Aspirator".bold
            check "Make sure there is room in the aspirator flasks (located to the right on the floor)"
            check "Turn on aspirator located to the right of the hood, by the incubators"

            separator
            note "Waste".bold
            check "If the biohazardous waste bin is more than 1/2 full, empty waste. Replace lining with fresh bag."

            separator
            note "Hood".bold
            check "Sterilize interior of hood with #{ETOH}"
            check "Ensure power pipette is charged"
            check "Ensure marker is in the hood"
            separator
            note "Projector".bold
            check "Turn on hood projector"
            check "Turn on blue-tooth footpedal"
            check "Adjust size of projector using computer"
        end

        show do
            title "Prepare for cell splitting"

            note "Remember:".bold
            warning "Always sterilize everything with #{ETOH} before placing in the #{HOOD}"
            check "Never cough/breath/sneeze into the hood"
            check "Never hover over open containers"
            check "Always use <b>fresh</b> pipettes for each step (unless otherwise stated)"
            check "Be weary of touching pipettes against objects"
        end

        ############ TRYPSINIZATION ############

        # Make sure you have enough stock

        # Prepare media and pbs
        show do
            title "Prepare reagents"
            
            check "<b>Sterilize</b> and move #{PBS} into #{HOOD}"
            check "Warm the following media bottles:"
            media_ops = operations.running.uniq { |op| op.input(MEDIA).item }.extend(OperationList)
            table media_ops.start_table
                .input_item(MEDIA)
                .custom_column(heading: "Media") { |op| op.input(MEDIA).item.sample.name }
                .custom_column(heading: "Location") { |op| op.input(MEDIA).item.location }
                .end_table
        end

        # Place plates into hood
        
        show do
            title "Replace your gloves before continuing to next steps"
        end
        
        show do
            title "Move cell plates into #{HOOD} and label"

            check "Move plates from C02 incubator to the #{HOOD}"
            check "Label each plate with a new <b>temporary label</b>"

            table input_ops.running.start_table
                      .input_item(INPUT)
                      .custom_column(heading: "Name") { |op| op.input(INPUT).sample.name }
                      .custom_column(heading: "Temporary label") { |op| op.temporary[:input_label] }
                      .custom_column(heading: "Plate Type") { |op| op.input(INPUT).object_type.name }
                      .end_table

            input_ops.each { |op| op.input(INPUT).item.move HOOD }
        end

        # Rinse with PBS
        show do
            title "Remove spend media"

            check "Use a <b>fresh</b> serological pipette for each plate to remove the media"
            warning "Be careful not to suck liquid into the pipette. Stop just before the cotton plug."

            table input_ops.start_table
                      .input_item(INPUT)
                      .custom_column(heading: "Label") { |op| op.temporary[:input_label] }
                      .custom_column(heading: "Container Type") { |op| op.input(INPUT).object_type.name }
                      .custom_column(heading: "Serological Pipette") { |op| "#{which_sero(op.temporary[:rinsing_vol])} mL" }
                      .end_table
        end

        # Rinse with PBS
        show do
            title "Rinse plates with #{PBS}"

            check "Add #{PBS} to each of the following plates."
            check "Gently mix #{PBS} on the plate."
            check "Remove #{PBS} from each plate."

            table input_ops.start_table
                      .input_item(INPUT)
                      .custom_column(heading: "Label") { |op| op.temporary[:input_label] }
                      .custom_column(heading: "Container Type") { |op| op.input(INPUT).object_type.name }
                      .custom_column(heading: "#{PBS} Vol (mL)", checkble: true) { |op| "#{op.temporary[:rinsing_vol]} mL" }
                      .custom_column(heading: "Serological Pipette") { |op| "#{which_sero(op.temporary[:rinsing_vol])} mL" }
                      .end_table
        end
    

        # Add trypsin
        show do
            title "Add #{TRYPSIN}"

            table input_ops.start_table
                      .input_item(INPUT)
                      .custom_column(heading: "Label") { |op| op.temporary[:input_label] }
                      .custom_column(heading: "#{TRYPSIN} Vol", checkble: true) { |op| "#{op.temporary[:trypsin_vol]} mL" }
                      .custom_column(heading: "Serological Pipette") { |op| "#{which_sero(op.temporary[:trypsin_vol])} mL" }
                      .end_table
        end

        show do
            title "Place plates in 37C incubator"

            table input_ops.start_table
                      .input_item(INPUT)
                      .custom_column(heading: "Label") { |op| op.temporary[:input_label] }
                      .end_table

            input_ops.each { |op| op.input(INPUT).item.move INCUBATOR }
        end
        
        show do
            title "Wipe down #{HOOD}"
            
            check "Clean up any spill in the #{HOOD} that may have happened"
            check "Wipe down the surface of the #{HOOD} with #{ETOH}"
        end
        
        show do
            title "Wait for cells to de-attach"
            
            check "Wait for the #{TRYPSIN} to de-attach the cells from the plates. This can take 2-10 minutes."
            note "Once de-attached, the cells should visibly 'sluff' off the plate"
            note "Cells will be fine for up to 30 minutes in #{TRYPSIN}."
            check "Click OK once cells have de-attached."
        end
        
        show do
            title "Return plates to #{HOOD}"
            
            check "Place the plates back into the #{HOOD}"
        end

        # TODO: Break up this part into steps
        # TODO: Add gif of mixing
        # Resuspend cells?
        group_by_media = input_ops.group_by { |op| op.input(GROWTH_MEDIA).item }
        group_by_media.each do |media, ops|
            show do
                title "Resuspend cells"
                
                check "Resuspend each plate with the indicated volume of media."
                check "Rinse plate bottom with added media 2-3 times."
                check "Break up cell clumps by pipetting up and down."
                table ops.start_table
                          .input_item(INPUT)
                          .custom_column(heading: "Label") { |op| op.temporary[:input_label] }
                          .custom_column(heading: "Media") { |op| "#{op.input(GROWTH_MEDIA).item.id} -- #{op.input(GROWTH_MEDIA).sample.name}" }
                          .custom_column(heading: "Media Vol", checkable: true) { |op| op.temporary[:resuspend_vol] }
                          .custom_column(heading: "Pipette") { |op| which_sero(op.temporary[:resuspend_vol]) }
                          .end_table
            end
        end

        # Save output data associations
        output_associations input_ops

        # Delete input plates
        operations.running.each { |op| 
            op.input(INPUT).item.mark_as_deleted 
            op.output(OUTPUT).item.move HOOD
        }

        operations.store interactive: false

        # TODO: Add successor names
        show do
            title "Proceed imediately to the next step"
            note "Kepp plates in #{HOOD} for the next protocols."
        end

        return {}

    end

    def test_debug
        # Debug with same plate as input
        if debug and TEST_PROTOCOL_BRANCHING
            if operations.running.size >= 2
                first_plate = operations.running.first.input(INPUT).item
                operations.running[1].input(INPUT).set item: first_plate, sample: first_plate.sample
            end
        end

        # Error out operations without confluencies
        if debug
            operations.running.each do |op|
                op.input(INPUT).item.confluency = rand(50..100)
            end
        end
        
        if debug and TEST_NO_CONFLUENCY
            operations.running.last.input(INPUT).item.clear_record
        end
    end
    
    # Associates the following with the output plate
    #    from: where the trypsinized plate came from
    #    cell_density: cell density of cell suspension
    #    volume: volume of cell suspension
    #    temporary_label: a clear legible label associated with plate
    def output_associations ops
        ops.each do |op|
            out_plate = op.output(OUTPUT).item
            out_plate.from = op.input(INPUT).item
            out_plate.volume = op.temporary[:total_resuspension_vol]
            out_plate.cell_density = op.temporary[:cell_density]
            out_plate.associate :temporary_label, op.temporary[:input_label]
            out_plate.associate :media, op.input(GROWTH_MEDIA).item.id
        end
    end

    # Calculate the volumes required for the rest of the protocol
    # Calculates:
    #   aspiration_vol: how much volume to remove from each plate
    #   working_vol: working volume of the plate container
    #   rinsing_vol: how much PBS to rinse with
    #   trypsin_vol: how much trypsin to use
    #   total_resuspension_vol: total volume of cell suspension
    #   resuspend_vol: how much media to resuspend trypsinized cells with
    #   cell_density: cell density (cells/mL) of final resuspension
    def volume_calculations(ops)
        ops.each do |op|
            input_plate = op.input(INPUT).item
            input_container = input_plate.object_type
            rinsing_vol = working_volume_of(input_container)
            trypsin_vol = input_plate.growth_area * TRYPSIN_PER_CM2
            
            op.temporary[:aspiration_vol] = op.input(INPUT).item.get(:volume) || rinsing_vol
            op.temporary[:working_vol] = input_plate.working_volume.round(1)
            op.temporary[:rinsing_vol] = input_plate.working_volume.round(1)
            op.temporary[:trypsin_vol] = trypsin_vol.round(1)
            op.temporary[:total_resuspension_vol] = op.temporary[:rinsing_vol]
            op.temporary[:resuspend_vol] = op.temporary[:total_resuspension_vol] - op.temporary[:trypsin_vol]
            if input_plate.confluency
                cell_num = input_plate.cell_number
                op.temporary[:cell_density] = cell_num / op.temporary[:total_resuspension_vol] if cell_num
            end
        end
        
        tot_vol ops
    end
    
    def tot_vol ops
        tot_vol_hash = Hash.new
        by_media = ops.group_by { |op| op.input(MEDIA).item }
        by_media.each do |media, grouped_ops|
            tot_vol_hash[media] = grouped_ops.inject(0) { |sum, op| sum + op.temporary[:resuspend_vol] }
        end
        tot_vol_hash[PBS] = ops.inject(0) { |sum, op| sum + op.temporary[:rinsing_vol] }
        tot_vol_hash[TRYPSIN] = ops.inject(0) { |sum, op| sum + op.temporary[:trypsin_vol] }
        tot_vol_hash
    end

end
