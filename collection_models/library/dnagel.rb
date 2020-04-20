needs "Tissue Culture Libs/CollectionDisplay"

class DNAGel

    include CollectionDisplay

    GENERIC_GEL = "50 mL Agarose Gel in Gel Box"
    AGAROSE = "Agarose Gel" # Sample type in unused lanes
    AGAROSE_ID = Sample.find_by_name(AGAROSE).id

    attr_reader :gel, :percentage, :agarose_type, :rows, :columns
    attr_accessor :operation_matrix, :ladders

    # Initializes a {DNAGel} for the given gel {Collection}.
    #
    # @requires gel is a {Collection}
    # @requires gel {Collection} has associations `:percentage` and `:type`
    # @param gel [Collection]
    def initialize(gel:)
        @gel = gel
        @percentage = gel.get("percentage")
        @agarose_type = gel.get("type")
        @columns = gel.object_type.columns
        @rows = gel.object_type.rows
        @operation_matrix = Array.new(rows) { Array.new(columns) }
        @ladders = []
    end

    # Adds ladder {Sample}s to the gel layout as represented by the {Collection}'s
    #   {Sample} matrix. Adds one of each {Sample} to each gel `row`.
    #
    # @todo Make it so that you can pass a parameter to also add ladders on the other
    #   side of the gel.
    # @param samples [Array<Sample>] the ladder Samples to be added
    def add_ladders(samples:)
        rows.times do |r|
            samples.each_with_index do |sample, c|
                gel.set(r, c, sample.id)
                ladders << sample
            end
        end
    end

    # Adds {Operation}s to the gel layout until it is filled and returns the remainder.
    #
    # @note Makes a new {Part} for each {Operation} that is added.
    # @note Adds the {Operation} to `operation_matrix` in the same `r, c` as the {Part}.
    # @param operations [Array<Operation>] {Operation}s to be added
    # @param output_handle [String] the name of the output {FieldValue}
    # @return [Array<Operation>] {Operation}s that didn't get added because there
    #   wasn't sufficient room in the collection
    def add_operations(operations:, output_handle:)
        empties = get_empty
        empties.each do |r, c|
            if operations.any?
                op = operations.shift
                op.output(output_handle).make_part(gel, r, c)
                operation_matrix[r][c] = op
            else
                gel.set(r, c, Collection::EMPTY)
            end
        end
        operations
    end

    # Uses {Collection#select} to find empty lanes that haven't already been assigned a
    #   sample or ladder.
    #
    # @return [Array<Array<Fixnum>>] empty lane indices in the form [[r1, c1], [r2, c2]]
    def get_empty
        gel.select { |x| x == Collection::EMPTY || x == AGAROSE_ID }
    end

    # The total number of lanes.
    #
    # @return [FixNum] `gel.rows` * `gel.columns`
    def size
        rows * columns
    end

    # The number of ladders being added to each row of the gel.
    #
    # @return [FixNum]
    def ladders_per_row
        ladders.length
    end

    # The number of lanes in each row of the gel that don't have ladders.
    #
    # @return [FixNum]
    def free_lanes_per_row
        columns - ladders_per_row
    end

    # Mark 'gel` {Collection} as deleted in the inventory
    #
    def mark_as_deleted
        gel.mark_as_deleted
    end

    # Tests whether 'gel` {Collection} is deleted in the inventory
    #
    def deleted?
        gel.deleted?
    end

    # Finds all the available {DNAGel::GENERIC_GEL} {Item}s in inventory.
    #
    # @return [ActiveRecord::Relation<Collection>]
    def self.gels_in_inventory
        ot = ObjectType.find_by_name(GENERIC_GEL)
        Collection.where(object_type_id: ot.id).reject { |gel| gel.deleted? }
    end

    # Finds all the available {DNAGel::GENERIC_GEL} {Item}s in inventory of the desired
    #   `:type` and `:percentage`.
    #
    # @param agarose_type [String]
    # @param percentage [String]
    # @return [ActiveRecord::Relation<Collection>]
    def self.matching_gels(agarose_type:, percentage:)
        DNAGel.gels_in_inventory.select do |gel|
            gel.get("type") == agarose_type &&
            gel.get("percentage") == percentage
        end
    end

    # Creates a display table mapping the input {Item}s to the {DNAGel}'s
    #   lanes.
    #
    # @param input_handle [String] the name of the input {FieldValue}
    # @return [Array<Array<String>>] the mapping formatted as a {Table}
    def sample_display(input_handle:)
        rcx_list = []
        operation_matrix.each_with_index do |row, outrow|
            row.each_with_index do |op, outcol|
                next unless op
                fv = op.input(input_handle)
                x = "#{fv.child_item_id}<br>#{alphanumeric(fv.row, fv.column)}"
                rcx_list << [outrow, outcol, x]
            end
        end
        highlight_alpha_rcx(gel, rcx_list)
    end

    # Creates a display table mapping the `ladders` to the {DNAGel}'s
    #   lanes.
    #
    # @return [Array<Array<String>>] the mapping formatted as a {Table}
    def ladder_display
        rcx_list = []
        ladders.each do |sample|
            gel.find(sample).each { |r, c| rcx_list << [r, c, sample.name] }
        end
        highlight_alpha_rcx(gel, rcx_list)
    end

    # Converts zero-indexed `row` and `column` to alphanumeric plate indices.
    #
    # @param row [FixNum]
    # @peram column [FixNum]
    def alphanumeric(row, column)
        alpha_r = ('A'..'H').to_a
        "#{alpha_r[row]}#{column + 1}"
    end

end