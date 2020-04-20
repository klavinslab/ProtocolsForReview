needs "Standard Libs/Units"
needs "Standard Libs/CommonInputOutputNames"

# Contains methods for assembling and dispensing master mixes
# @author Devin Strickland <strcklnd@uw.edu>
module MasterMixHelper

    include CommonInputOutputNames
    include Units

    # TODO: Get this out of here.
    TEST = "TEST"

    # Group operations by multiple inputs
    # @todo Make the grouped Operations be OperationLists
    #
    # @param input_names [Array<String>] names of inputs to be included in grouping
    # @param ops [OperationList, Array<Operation>] operations to be grouped
    # @return [Array(Array<String>, Hash{Array<FixNum> => Array<Operation>})] the input IDs
    #   with singletons eliminated, followed by the grouped operations
    def group_ops_by_inputs(input_names:, ops:)
        input_names = eliminate_singletons(input_names: input_names, ops: ops)
        grouped_ops = ops.group_by { |op| input_item_id_array(input_names: input_names, op: op) }
        [input_names, grouped_ops]
    end

    # Remove input names from the list where each operation is a different input item
    #
    # @param input_names [Array<String>] input names to be tested and, if appropriate, eliminated
    # @param ops [OperationList, Array<Operation>] operations
    # @return [Array<String>] the input names with singletons eliminated
    def eliminate_singletons(input_names:, ops:)
        input_names.reject { |n| singletons?(input_name: n, ops: ops) }
    end

    # Tests whether each operation has a different item for a given input name and
    #   returns true if each is different
    #
    # @param input_name [String] input name to be tested
    # @param ops [OperationList, Array<Operation>] operations
    # @return [Boolean]
    def singletons?(input_name:, ops:)
        ops.map { |op| item_id(input_name: input_name, op: op) }.uniq.length == ops.length
    end

    # Gets the ID for the Item or Part specified by a given input name
    #
    # @param input_name [String] input name to be tested
    # @param op [Operation]
    # @return [FixNum] the Item or Part ID
    def item_id(input_name:, op:)
        fv = op.input(input_name)
        fv.part.try(:id) || fv.item.id
    end

    # Maps Item IDs for a given list of input names and a given operation
    #
    # @param input_names [Array<String>] input names to be mapped
    # @param op [Operation]
    # @return [Array<FixNum>]
    def input_item_id_array(input_names:, op:)
        input_names.map { |n| op.input(n).child_item_id }
    end

    # Makes master mix(es) for a set of operations
    # Assumes that all operations have the same PCR program
    #
    # @param grouped_ops [Hash{Array<FixNum> => Array<Operation>}] hash of operations
    #   grouped by input IDs
    # @param input_names [Array<String>] input names corresponding to grouped_ops keys
    # @param composition [PCRComposition]
    # @param mult [Float] Amount to multiply each component volume by to account for
    #   pipetting error
    # @return [Hash{String => Array<Operation>}] hash of operations grouped by tube labels
    def make_master_mixes(grouped_ops:, input_names:, composition:, mult: 1.0)
        ops_by_master_mix = {}

        grouped_ops.each_with_index do |(inputs, ops), i|
            mm_tube_label = "MM#{i+1}"
            this_mult = mult * ops.length

            master_mix_table = master_mix_table(
                inputs: inputs,
                input_names: input_names,
                composition: composition,
                mult: this_mult
            )

            show do
                title "Make Master Mix #{mm_tube_label}"

                check "Get a 1.5mL tube and label it <b>#{mm_tube_label}</b>."
                note "Add reaction components as indicated:"
                table master_mix_table
            end

            ops_by_master_mix[mm_tube_label] = ops
        end

        show do
            title "Vortex and Spin Down"

            check "Vortex the master mix tubes briefly and spin down"
        end

        ops_by_master_mix
    end

    # Build table for volumes of master mix components
    #
    # @param inputs [Array<FixNum>] input item IDs
    # @param input_names [Array<String>] input names
    # @param composition [PCRComposition]
    # @param mult [Float] Amount to multiply each component volume by to account for
    #   pipetting error
    # @return [Array<Array>] a 2D array formatted for the `table` method in Krill
    def master_mix_table(inputs:, input_names:, composition:, mult:)
        header = [
            "#{composition.polymerase.display_name} #{composition.polymerase.item}",
            "#{composition.dye.display_name} #{composition.dye.item}",
            composition.water.display_name
        ]

        row = [
            composition.polymerase.add_in_table(mult),
            composition.dye.add_in_table(mult),
            composition.water.add_in_table(mult)
        ]

        input_names.each_with_index do |input_name, i|
            header << "#{input_name} #{inputs[i]}"
            row << composition.input(input_name).add_in_table(mult)
        end

        [header, row].transpose
    end

    # Dispenses master mixes for PCR
    # Assumes all operations in ops_by_master_mix hash are from the same program
    #
    # @param output_name [String] output name
    # @param ops_by_master_mix [Hash{String => Array<Operation>}] hash of operations
    #   grouped by tube labels
    # @param composition [PCRComposition]
    def dispense_master_mix(output_name:, ops_by_master_mix:, composition:, mult: 1.0)
        coll = ops_by_master_mix.values.first.first.output(output_name).collection
        coll_display = "#{coll}-#{TEST}"

        mm_vol = composition.sum_added_components * mult
        divide = composition.volume * mult > 100

        if divide
            ops = ops_by_master_mix.values.flatten
            labels = ops.map { |op| coll_id_display(op, output_name, role="output", hide_id=true) }
            show do
                title "Divide Master Mix"

                note "Get #{ops.length} 1.5 ml microfuge tubes and label them"\
                     " #{labels.to_sentence}"
            end
        end

        destination = divide ? "microfuge tube" : "#{coll_display} position"

        master_mix_table = []
        master_mix_table[0] = [
            "MM tube",
            destination
        ]

        ops_by_master_mix.each do |master_mix, ops|
            ops.each do |op|
                pos = coll_id_display(op, output_name, role="output", hide_id=true)
                row = [
                    master_mix,
                    { content: pos, check: true }
                ]
                master_mix_table.append(row)
            end
        end

        show do
            title "Dispense Master Mix"
            note "Dispense #{mm_vol} #{MICROLITERS} of each master mix"\
                 " into the indicated <b>#{destination}</b>"
            table master_mix_table
        end
    end

    # Dispenses a component
    #
    # @param input_name [String] input name of component
    # @param output_name [String] output name
    # @param ops [OperationList, Array<Operation>] operations
    # @param composition [PCRComposition]
    # @param mult [Float] Amount to multiply each component volume by to account for
    #   pipetting error
    def dispense_component(input_name:, output_name:, ops:, composition:, mult: 1.0)
        coll = ops.first.output(output_name).collection
        coll_display = "#{coll}-#{TEST}"

        component = composition.input(input_name)
        comp_vol = component.adjusted_qty(mult=mult, round=1, checkable=false)

        divide = composition.volume * mult > 100
        destination = divide ? "microfuge tube" : "#{coll_display} position"

        uniq_inputs = ops.map { |op| op.input(input_name).item }.uniq
        if uniq_inputs.length == 1
            from_header = "#{uniq_inputs.first} position"
            hide_input_id = true
        else
            from_header = "#{input_name} ID"
            hide_input_id = false
        end

        dispense_table = []
        dispense_table[0] = [
            from_header,
            destination
        ]

        ops.each do |op|
            from_pos = coll_id_display(op, input_name, role="input", hide_id=hide_input_id)
            to_pos = coll_id_display(op, output_name, role="output", hide_id=true)
            row = [from_pos, { content: to_pos, check: true }]
            dispense_table.append(row)
        end

        show do
            title "Dispense #{input_name.pluralize}"
            
            if input_name.pluralize == "Templates" 
                
                check "Dispense #{comp_vol} #{MICROLITERS} of each template in the indicated <b>#{destination}</b> and close cap for each well after template is added"
                table dispense_table
                note "Vortex and spin down test stripwells"
                
            else 
                
                check "Dispense #{comp_vol} #{MICROLITERS} of each #{input_name}"\
                      " into the indicated <b>#{destination}</b>"
                table dispense_table
                
            end
        end
    end

end