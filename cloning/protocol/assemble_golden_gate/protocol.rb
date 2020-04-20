# Protocol: Golden Gate Assembly
# Author: Orlando de Lange
# Refactored by: Devin Strickland
# Description: Golden Gate with BsaI, 30WU ligase and ligase buffer

needs "Standard Libs/Debug"

needs "Standard Libs/Units"
needs "Standard Libs/CommonInputOutputNames"
needs "PCR Libs/PCRProgram"
needs "PCR Libs/PCRComposition"

class Protocol

    include Debug

    PARTS = "Parts"
    RESTRICTION_ENZYME = "Restriction Enzyme"
    METHOD = "Method"
    PLASMID = "Plasmid"

    def main
        exit_message = validate_inputs(ops: operations)

        if exit_message.present?
            show do
                title "Batching Error"
                note exit_message
            end
            return
        end

        method = get_method(input: operations.first.input(METHOD).val)
        ligase = get_ligase_name(input: method)
        restriction_enzyme = get_restriction_enzyme_name(
            input: operations.first.input(RESTRICTION_ENZYME).val
        )

        composition = GoldenGateComposition.new(
            program_name: method,
            ligase: ligase,
            restriction_enzyme: restriction_enzyme
        )

        program = GoldenGateProgram.new(
            program_name: get_program_name(method: method, restriction_enzyme: restriction_enzyme)
        )

        gather_enzymes(composition: composition)

        operations.running.retrieve.make

        stripwells = operations.running.map {|op| op.output(PLASMID).collection }.uniq
        gather_stripwells(stripwells: stripwells)

        set_up_reactions(operations: operations, composition: composition)

        thermocycler_name = set_up_thermocycler(program: program)

        thermocycler_name = "thermocycler" if thermocycler_name.blank?

        stripwells.each { |s| s.move_to(thermocycler_name) }

        clean_up(composition: composition)

        return {}
    end

    def gather_enzymes(composition:)
        show do
            title "Use -20 tube rack for enzymes"

            note "Take a -20 tube rack from the small minus 20 by the autoclave"
            warning "Keep the enzymes in the rack while you have them at the bench"
        end

        items_to_take = [
            composition.buffer.item,
            composition.ligase.item,
            composition.restriction_enzyme.item
        ]

        take(items_to_take, interactive: true)

        show do
            title "Thaw Ligase buffer"

            note "Leave #{composition.buffer.display_name} #{composition.buffer.item} at " \
                    "your workbench to thaw"
        end
    end

    def gather_stripwells(stripwells:)
        show do
            title "Gather and label #{stripwells.length} stripwell(s)"
            note "Gather #{stripwells.length} stripwell(s) and label them as follows:"
            stripwells.each do |s|
                check "#{s.id}"
            end
        end
    end

    def set_up_reactions(operations:, composition:)
        show do
            title "Add water"

            table operations.start_table
                .output_collection(PLASMID, heading: "Stripwell")
                .custom_column(heading: "Well") { |op| (well_number(op)) }
                .custom_column(heading: "Water (#{composition.water.units})", checkable: true) { |op| water_volume(op, composition) }
                .end_table
        end

        show do
            title "Vortex #{composition.buffer.display_name}"

            warning "Vortex #{composition.buffer.display_name} #{composition.buffer.item} to " \
                        "dissolve DTT"
            note "It is OK if some DTT precipitate remains"
        end

        add_fixed_volume(component: composition.buffer)

        add_parts(operations: operations, composition: composition)

        add_fixed_volume(component: composition.ligase)

        add_fixed_volume(component: composition.restriction_enzyme)

        show do
            title "Close stripwells and mix reactions"

            note "Put caps onto the stripwells"
            note "Flick the stripwells gently to mix the reactions"
            note "Spin down stripwells in the tabletop stripwell-centrifuge"
        end
    end

    def set_up_thermocycler(program:)
        response = show do
            title "Place reactions in thermocycler"

            note "Run program #{program.name}"
            check "Confirm program:"
            table program.table

            get "text", var: "thermocycler_name", label: "Enter the name of the thermocycler used"
        end

        response[:thermocycler_name]
    end

    def add_fixed_volume(component:)
        show do
            title "Add #{component.display_name}"

            note "Pipet #{component.qty_display} #{component.display_name} #{component.item} " \
                    "into each non-empty well"
        end
    end

    def add_parts(operations:, composition:)
        show do
            title "Add DNA"

            operations.each_with_index do |op, i|
                separator unless i.zero?
                note "Add to stripwell #{op.output(PLASMID).collection} / " \
                        "well #{well_number(op)}"
                table parts_table(operation: op, composition: composition)
            end
        end
    end

    def parts_table(operation:, composition:)
        parts = operation.input_array(PARTS)
        items = parts.map { |p| p.item.to_s }
        volumes = parts.map { |_| composition.part.adjusted_qty }

        parts_table = Table.new
        parts_table.add_column( "Item", items)
        parts_table.add_column( "Volume (#{composition.part.units})", volumes)
        parts_table
    end

    def clean_up(composition:)
        items_to_release = [
            composition.ligase.item,
            composition.restriction_enzyme.item
        ]
        release(items_to_release, interactive: true)

        composition.buffer.item.mark_as_deleted

        show do
            title "Discard ligase buffer aliquot"
            note "Discard the ligase buffer aliquot #{composition.buffer.item} into the waste bin"
        end
    end

    def well_number(operation)
        operation.output(PLASMID).column + 1
    end

    def water_volume(operation, composition, round=1)
        composition.water_volume(operation.input_array(PARTS).length, round)
    end

    def get_method(input:)
        case input
        when "Standard"
            "Standard"
        when "MoClo-YTK"
            "MoClo-YTK"
        end
    end

    def get_ligase_name(input:)
        case input
        when "Standard"
            "T4 DNA Ligase"
        when "MoClo-YTK"
            "T7 DNA Ligase"
        end
    end

    def get_restriction_enzyme_name(input:)
        case input
        when "BsaI"
            "BsaI-HFv2"
        when "BbsI"
            "BbsI"
        when "BsgI"
            "BsgI"
        when "Esp3I"
            "Esp3I"
        end
    end

    def get_program_name(method:, restriction_enzyme:)
        if method = "MoClo-YTK"
            if restriction_enzyme == "BsaI-HFv2"
                return method + "_37"
            elsif restriction_enzyme == "Esp3I"
                return method + "_42"
            end
        else
            return method
        end
    end

    def validate_inputs(ops:)
        restriction_enzymes = ops.map { |op| op.input(RESTRICTION_ENZYME).val }
        methods = ops.map { |op| op.input(METHOD).val }

        if restriction_enzymes.uniq.length > 1 || methods.uniq.length > 1
            exit_message = "This OperationType currently requires each Job to use a " \
                "single #{RESTRICTION_ENZYME} and a single #{METHOD}. This Job uses " \
                "#{restriction_enzymes.to_sentence} as #{RESTRICTION_ENZYME.pluralize} and " \
                "#{methods.to_sentence} as #{METHOD.pluralize}. Please replan"

            ops.each { |op| op.error :improper_batching, exit_message }
            return exit_message
        end

        nil
    end

end

class GoldenGateComposition

    include CommonInputOutputNames, Units

    LIGASE = nil
    ENZYME_STOCK = "Enzyme Stock"
    LIGASE_OBJECT = ENZYME_STOCK
    RESTRICTION_ENZYME = nil
    RESTRICTION_ENZYME_OBJECT = ENZYME_STOCK
    BACKBONE = "Backbone"
    PARTS = "Parts"
    WATER = "Molecular Grade Water"
    BUFFER = "T4 DNA Ligase Buffer"
    BUFFER_OBJECT = "Enzyme Buffer Stock"

    COMPONENTS = {
        "Standard" => {
            ligase:             {input_name: LIGASE,              qty: 1,       units: MICROLITERS},
            restriction_enzyme: {input_name: RESTRICTION_ENZYME,  qty: 1,       units: MICROLITERS},
            buffer:             {input_name: BUFFER,              qty: 2,       units: MICROLITERS},
            part:               {input_name: PARTS,               qty: 1,       units: MICROLITERS},
            water:              {input_name: WATER,               qty: nil,     units: MICROLITERS},
            total_volume:       {qty: 20, units: MICROLITERS}
        },
        "MoClo-YTK" => {
            ligase:             {input_name: LIGASE,              qty: 0.5,     units: MICROLITERS},
            restriction_enzyme: {input_name: RESTRICTION_ENZYME,  qty: 0.5,     units: MICROLITERS},
            buffer:             {input_name: BUFFER,              qty: 1,       units: MICROLITERS},
            part:               {input_name: PARTS,               qty: 1,       units: MICROLITERS},
            water:              {input_name: WATER,               qty: nil,     units: MICROLITERS},
            total_volume:       {qty: 10, units: MICROLITERS}
        }
    }

    attr_accessor :components

    # Instantiates the class
    # Either `component_data` or `program_name` must be passed
    # If `component_data` is not passed, then `ligase` and `restriction_enzyme` must be
    #
    # @param components [Hash] a hash enumerating the components
    # @param program_name [String] a key specifying one of the default component hashes
    # @param ligase [String] the Aquarium Sample name for the ligase
    # @param restriction_enzyme [String] the Aquarium Sample name for the restriction enzyme
    def initialize(component_data: nil, program_name: nil, ligase: nil, restriction_enzyme: nil)
        if component_data.blank? && program_name.blank?
            raise "Unable to initialize GoldenGateComposition. Either `component_data` " \
                    "or `program_name` is required"
        elsif program_name.present?
            if ligase.blank? || restriction_enzyme.blank?
                raise "Unable to initialize GoldenGateComposition. If `component_data` " \
                        "is not supplied then ligase and restriction_enzyme must be"
            end
            component_data = GoldenGateComposition::COMPONENTS[program_name]
        end

        if ligase.present?
            @ligase = ligase
            component_data[:ligase][:input_name] = ligase
            component_data[:ligase][:sample_name] = ligase
            component_data[:ligase][:object_name] = LIGASE_OBJECT
        else
            @ligase = component_data[:ligase][:input_name]
        end

        if restriction_enzyme.present?
            @restriction_enzyme = restriction_enzyme
            component_data[:restriction_enzyme][:input_name] = restriction_enzyme
            component_data[:restriction_enzyme][:sample_name] = restriction_enzyme
            component_data[:restriction_enzyme][:object_name] = RESTRICTION_ENZYME_OBJECT
        else
            @restriction_enzyme = component_data[:restriction_enzyme][:input_name]
        end

        component_data[:buffer][:sample_name] = BUFFER
        component_data[:buffer][:object_name] = BUFFER_OBJECT

        @total_volume = component_data.delete(:total_volume)

        @components = []
        component_data.each { |k,c| components.append(ReactionComponent.new(c)) }
    end

    # Specifications for the ligase component
    # @return (see #input)
    def ligase
        input(@ligase)
    end

    # Specifications for the restriction_enzyme component
    # @return (see #input)
    def restriction_enzyme
        input(@restriction_enzyme)
    end

    # Specifications for the buffer component
    # @return (see #input)
    def buffer
        input(BUFFER)
    end

    # Specifications for the part component
    # @return [ReactionComponent]
    def part
        input(PARTS)
    end

    # Specifications for the water component
    # @return (see #input)
    def water
        input(WATER)
    end

    # Retrieves components by input name
    # Generally the named methods should be used.
    # However, this method can be convenient in loops, especially when
    #   the Protocol draws input names from `CommonInputOutputNames`
    #
    # @param input_name [String] the name of the component to be retrieved
    # @return [ReactionComponent]
    def input(input_name)
        components.find { |c| c.input_name == input_name }
    end

    # Displays the total reaction volume with units
    #
    # @todo Make this work better with units other than microliters
    # @return [String]
    def qty_display
        Units.qty_display({ qty: volume, units: MICROLITERS })
    end

    # The total reaction volume
    # @note Rounds to one decimal place
    # @return [Float]
    def volume
        @total_volume[:qty]
    end

    # The total reaction volume
    # @note Rounds to one decimal place
    # @return [Float]
    def total_volume
        @total_volume[:qty]
    end

    def water_volume(part_ct, round=1)
        (total_volume - sum_components(part_ct, 5)).round(round)
    end

    # The total volume of all components except water
    # @param part_ct [Fixnum] the number of parts being added
    # @param round [Fixnum] the number of decimal places to round to
    # @return [Float]
    def sum_components(part_ct, round=1)
        partitioned = components.partition { |c| c.input_name == PARTS }
        qty = partitioned[0][0].qty * part_ct
        qty += partitioned[1].map{ |c| c.qty }.compact.reduce(:+)
        raise "Operation uses too many parts" if qty > total_volume
        qty.round(round)
    end

    # The total volume of all components that have been added
    # @param (see #sum_components)
    # @return (see #sum_components)
    def sum_added_components(round=1)
        added_components.map{ |c| c.qty }.reduce(:+).round(round)
    end

    # Gets the components that have been added
    # @return [Array<ReactionComponent>]
    def added_components
        components.select { |c| c.added? }
    end

end

class GoldenGateProgram

    include Units

    PROGRAMS = {
        "Standard" => {
            name: "CUTLIG", volume: 20,
            steps: {
                step1: {temp: {qty: 37, units: DEGREES_C}, time: {qty: 5, units: MINUTES}},
                step2: {temp: {qty: 20, units: DEGREES_C}, time: {qty: 2, units: MINUTES}},
                step3: {goto: 1, times: 39},
                step4: {temp: {qty: 37, units: DEGREES_C}, time: {qty:  10, units: MINUTES}},
                step5: {temp: {qty: 80, units: DEGREES_C}, time: {qty:  10, units: MINUTES}}
            }
        },
        "MoClo-YTK_37" => {
            name: "MoClo-YTK_37 TBD", volume: 10,
            steps: {
                step1: {temp: {qty: 37, units: DEGREES_C}, time: {qty: 2, units: MINUTES}},
                step2: {temp: {qty: 16, units: DEGREES_C}, time: {qty: 3, units: MINUTES}},
                step3: {goto: 1, times: 29},
                step4: {temp: {qty: 25, units: DEGREES_C}, time: {qty:  10, units: MINUTES}},
                step5: {temp: {qty: 37, units: DEGREES_C}, time: {qty:  10, units: MINUTES}},
                step6: {temp: {qty: 80, units: DEGREES_C}, time: {qty:  10, units: MINUTES}}
            }
        },
        "MoClo-YTK_42" => {
            name: "MoClo-YTK_42 TBD", volume: 10,
            steps: {
                step1: {temp: {qty: 42, units: DEGREES_C}, time: {qty: 2, units: MINUTES}},
                step2: {temp: {qty: 16, units: DEGREES_C}, time: {qty: 3, units: MINUTES}},
                step3: {goto: 1, times: 29},
                step4: {temp: {qty: 25, units: DEGREES_C}, time: {qty:  10, units: MINUTES}},
                step5: {temp: {qty: 42, units: DEGREES_C}, time: {qty:  10, units: MINUTES}},
                step6: {temp: {qty: 80, units: DEGREES_C}, time: {qty:  10, units: MINUTES}}
            }
        }
    }

    attr_reader :program_name, :name, :steps, :volume

    def initialize(args={})
        @program_name = args[:program_name]
        program = GoldenGateProgram::PROGRAMS[program_name]
        @steps = {}
        program[:steps].each { |k,v| @steps[k] = PCRStep.new(v) }
        @volume = args[:volume] || program[:volume]
        @name = program[:name]
    end

    def table
        table = []
        steps.each do |k,v|
            row = ["#{k}"]
            if v.incubation?
                row += [v.temperature_display, v.duration_display]
            elsif v.goto?
                row += [v.goto_display, v.times_display]
            else
                raise "Unable to interpret #{v} as a PCRStep"
            end
            table.append(row)
        end
        table
    end

end