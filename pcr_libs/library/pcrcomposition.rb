needs "Standard Libs/Units"
needs "Standard Libs/CommonInputOutputNames"

# Models the composition of a polymerase chain reaction
# @author Devin Strickland <strcklnd@uw.edu>
# @note As much as possible, Protocols using this class should drawn input names from `CommonInputOutputNames`
class PCRComposition

    include CommonInputOutputNames, Units

    POLYMERASE = "Polymerase"
    POLYMERASE_SAMPLE = "Kapa HF Master Mix"
    POLYMERASE_OBJECT = "Enzyme Stock"
    DYE = "Dye"
    DYE_SAMPLE = "Eva Green"
    DYE_OBJECT = "Screw Cap Tube"
    WATER = "Molecular Grade Water"

    COMPONENTS = {
        "qPCR1" => {
            polymerase:     {input_name: POLYMERASE,        qty: 16,    units: MICROLITERS},
            forward_primer: {input_name: FORWARD_PRIMER,    qty: 0.16,  units: MICROLITERS},
            reverse_primer: {input_name: REVERSE_PRIMER,    qty: 0.16,  units: MICROLITERS},
            dye:            {input_name: DYE,               qty: 1.6,   units: MICROLITERS},
            water:          {input_name: WATER,             qty: 6.58,  units: MICROLITERS},
            template:       {input_name: TEMPLATE,          qty: 7.5,   units: MICROLITERS}
        },

        # qPCR2: 2nd qPCR in NGS prep. reverse primer is indexed primer.
        "qPCR2" => {
            polymerase:     {input_name: POLYMERASE,        qty: 25,    units: MICROLITERS},
            forward_primer: {input_name: FORWARD_PRIMER,    qty: 2.5,   units: MICROLITERS},
            reverse_primer: {input_name: REVERSE_PRIMER,    qty: 2.5,   units: MICROLITERS},
            dye:            {input_name: DYE,               qty: 2.5,   units: MICROLITERS},
            water:          {input_name: WATER,             qty: 15.5,  units: MICROLITERS},
            template:       {input_name: TEMPLATE,          qty: 2,     units: MICROLITERS}
        },

        # LIBqPCR1: 1st qPCR in Libray prep. if sublibrary primers exist they are used here.
        "lib_qPCR1" => {
            polymerase:     {input_name: POLYMERASE,        qty: 12.5,  units: MICROLITERS},
            forward_primer: {input_name: FORWARD_PRIMER,    qty: 0.75,  units: MICROLITERS},
            reverse_primer: {input_name: REVERSE_PRIMER,    qty: 0.75,  units: MICROLITERS},
            dye:            {input_name: DYE,               qty: 1.25,  units: MICROLITERS},
            water:          {input_name: WATER,             qty: 8.75,  units: MICROLITERS},
            template:       {input_name: TEMPLATE,          qty: 1,     units: MICROLITERS}
        },

        # LIBqPCR2: 2nd qPCR in Libray prep. overhangs compatible with cloning vector are added here.
        "lib_qPCR2" => {
            polymerase:     {input_name: POLYMERASE,        qty: 25,    units: MICROLITERS},
            forward_primer: {input_name: FORWARD_PRIMER,    qty: 1.5,   units: MICROLITERS},
            reverse_primer: {input_name: REVERSE_PRIMER,    qty: 1.5,   units: MICROLITERS},
            dye:            {input_name: DYE,               qty: 2.5,   units: MICROLITERS},
            water:          {input_name: WATER,             qty: 17.5,  units: MICROLITERS},
            template:       {input_name: TEMPLATE,          qty: 2,     units: MICROLITERS}
        },
    }

    attr_accessor :components

    # Instantiates the class
    # Either `component_data` or `program_name` must be passed
    #
    # @param components [Hash] a hash enumerating the components
    # @param program_name [String] a key specifying one of the default component hashes
    def initialize(component_data: nil, program_name: nil)
        if component_data.blank? && program_name.blank?
            raise "Unable to initialize PCRComposition. Either `component_data` or `program_name` is required."
        elsif program_name.present?
            component_data = PCRComposition::COMPONENTS[program_name]
        end

        component_data[:dye] = default_dye.merge(component_data[:dye])
        component_data[:polymerase] = default_polymerase.merge(component_data[:polymerase])

        @components = []
        component_data.each { |k,c| components.append(ReactionComponent.new(c)) }
    end

    # Provides default Sample and ObjectType for polymerase
    # @private
    # @return [Hash]
    def default_polymerase
        {
            sample_name: POLYMERASE_SAMPLE,
            object_name: POLYMERASE_OBJECT
        }
    end

    # Provides default Sample and ObjectType for dye
    # @private
    # @return [Hash]
    def default_dye
        {
            sample_name: DYE_SAMPLE,
            object_name: DYE_OBJECT
        }
    end

    # Specifications for the dye component
    # @return (see #input)
    def dye
        input(DYE)
    end

    # Specifications for the polymerase component
    # @return (see #input)
    def polymerase
        input(POLYMERASE)
    end

    # Specifications for the forward primer component
    # @return (see #input)
    def forward_primer
        input(FORWARD_PRIMER)
    end

    # Specifications for the reverse primer component
    # @return (see #input)
    def reverse_primer
        input(REVERSE_PRIMER)
    end

    # Specifications for the template component
    # @return [ReactionComponent]
    def template
        input(TEMPLATE)
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
        sum_components
    end

    # The total reaction volume
    # @param round [Fixnum] the number of decimal places to round to
    # @return [Float]
    def sum_components(round=1)
        components.map{ |c| c.qty }.reduce(:+).round(round)
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

# Models a component of a biochemical reaction
# @author Devin Strickland <strcklnd@uw.edu>
class ReactionComponent

    include Units

    attr_reader :input_name, :qty, :units, :sample, :item
    attr_accessor :added

    # Instantiates the class
    #
    # @param input_name [String] the name of the component
    # @param qty [Numeric] the quantity of this component to be added to a single reaction
    # @param units [String] the units of `qty`
    # @param sample_name [String] the name of the Aquarium Sample to be used for this component
    # @param object_name [String] the ObjectType (Container) that this component should be found in
    def initialize(input_name:, qty:, units:, sample_name: nil, object_name: nil)
        @input_name = input_name
        @qty = qty
        @units = units
        @sample = sample_name ? Sample.find_by_name(sample_name) : nil

        if sample && object_name
            @item = sample.in(object_name).first
        else
            @item = nil
        end

        @added = false
    end

    # The input name, formatted for display in protocols
    # @return [String]
    def display_name
        input_name
    end

    # Displays the volume (`qty`) with units
    #
    # @return [String]
    def qty_display(round=1)
        Units.qty_display({ qty: qty.round(round), units: units })
    end

    # Adjusts the qty by a given factor and, if needed, makes it checkable in a table
    #
    # @param mult [Float] the factor to multiply `qty` by
    # @param round [FixNum] the number of places to round the result to
    # @param checkable [Boolean] whether to make the result checkable in a table
    # @return [Numeric, Hash]
    def adjusted_qty(mult=1.0, round=1, checkable=true)
        adj_qty = (qty * mult).round(round)
        adj_qty = {content: adj_qty, check: true} if checkable
        adj_qty
    end

    # provides the `qty` for display in a table, and markes it as `added`
    #
    # @param (see #adjusted_qty)
    # @return (see #adjusted_qty)
    def add_in_table(mult=1.0, round=1, checkable=true)
        @added = true
        adjusted_qty(mult, round, checkable)
    end

    # Checks if `self` has been added
    # @return [Boolean]
    def added?
        added
    end
end