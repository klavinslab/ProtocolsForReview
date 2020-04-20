needs "Standard Libs/Debug"

module ChallengeAndLabelDebug

    require 'json'

    include Debug

    INPUT_YEAST = "Yeast Culture"
    PROTEASE = "Protease"

    OPTIONS = {

    }

    DEBUG_CONCENTRATIONS = {
        'Chymotrypsin' => { stock: 20894 },
        'Trypsin' => { stock: 32881 }
    }
    # Helps create a realistic set of inputs for tests
    #
    # @note Overrides inputs for randomly-generated items
    def override_input_operations

        consolidate_yeast_inputs
        consolidate_protease_inputs

        associate_plan_options(OPTIONS)
    end

    def associate_plan_options(opts)
        plan = operations.first.plan
        plan.associate(:options, opts.to_json)
    end

    def consolidate_yeast_inputs
        grp = operations.group_by { |op| [op.input(INPUT_YEAST).sample, op.input(PROTEASE).sample] }
        consolidate_inputs(grp, INPUT_YEAST)
    end

    def consolidate_protease_inputs
        grp = operations.group_by { |op| op.input(PROTEASE).sample }
        consolidate_inputs(grp, PROTEASE)
        items = operations.map { |op| op.input(PROTEASE).item }.uniq
        items.each { |i| i.associate(:units_per_milliliter, DEBUG_CONCENTRATIONS[i.sample.name][:stock]) }
    end

    def consolidate_inputs(grouped_ops, input_name)
        grouped_ops.values.each do |ops|
            child_item_id = ops.shift.input(input_name).child_item_id
            ops.each do |op|
                op.input(input_name).update_attributes(child_item_id: child_item_id)
            end
        end
    end

end