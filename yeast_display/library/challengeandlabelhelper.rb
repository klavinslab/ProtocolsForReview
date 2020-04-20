needs "Yeast Display/YeastDisplayHelper"
needs "Yeast Display/ChallengeAndLabelDebug"

module ChallengeAndLabelHelper

    include YeastDisplayHelper, ChallengeAndLabelDebug

    OUTPUT_YEAST = 'Labeled Yeast Library'

    PROTEASE_CONCENTRATION = 'Protease Concentration'
    PROTEASE = 'Protease'
    ANTIBODY = 'Antibody'
    PRETREATMENT = 'Pretreatment'

    ASSAY_BUFFER = 'Assay Buffer'
    INCUBATION_BUFFER = 'Incubation buffer'
    QUENCH_BUFFER = 'Quench buffer'
    BINDING_BUFFER = 'Binding buffer'
    PRETREATMENT_BUFFER = 'Pretreatment buffer'

    ALL_BUFFERS = [ASSAY_BUFFER, INCUBATION_BUFFER, QUENCH_BUFFER, BINDING_BUFFER]

    BUFFER_CONTAINERS = {
        INCUBATION_BUFFER => '250 ml bottle',
        QUENCH_BUFFER => '100 ml bottle',
        BINDING_BUFFER => '100 ml bottle'
    }

    DEFAULT_CONCENTRATIONS = {
        'Chymotrypsin' => { stock: 36191 },
        'Trypsin' => { stock: 32881 },
        'IL-23R' => { stock: 17.2 }
    }

    # Tells the tech to get some equipment that is needed.
    #
    def prepare_equipment
        show do
            title 'Gather materials'
            check 'Fill 2 buckets with ice.'
            check "Get the 24-well aluminum block out of the 4 #{DEGREES_C}" \
                'refrigerator and place it in one of the ice buckets.'
            check "Set the refigerated centrifuge to 4 #{DEGREES_C}."
        end
    end

    # Decide whether/which proteases are needed; retrieve them and the associated buffers.
    #
    def gather_buffers_and_proteases
        # Decide if the technician needs to retrieve any protease stocks.
        retrieve_protease = @plan_params[:incubate_with_protease] && protease_needed

        operations.retrieve(only: ALL_BUFFERS)
        operations.retrieve(only: PROTEASE) if retrieve_protease

        show do
            title 'Prepare materials'
            note 'Place the PBSF and TBSF (if gathered) on ice.'
            note 'Leave the PBS and TBS (if gathered) at room temperature.'
            note "Let the stocks thaw at room temperature." if retrieve_protease
        end
    end

    # Put all the materials away.
    #
    def clean_up
        show do
           title 'Store pellets on ice'
           note temp_instructions(ON_ICE)

           note 'Keep the labeled cell pellets, in the 24-well aluminum block, on ice until you are ready for FACS.'
        end

        buffers = operations.map { |op| op.inputs.select { |i| ALL_BUFFERS.include?(i.name) } }.flatten
        buffers.map! { |b| b.child_item }.uniq!

        release(buffers, interactive: true)

        show do
           title 'Clean up'

           check 'Any items that remain on the bench (other than the labeled cell pellets) can be discarded.'
           check "Set the refigerated centrifuge back to 25 #{DEGREES_C}."
        end
    end

    ########## LABELS, GETTERS, AND SIMPLE CALCULATIONS ##########

    def binding_buffer(op)
        # @buffer_lookup[op.input(ANTIBODY).sample][BINDING_BUFFER]
        op.input(BINDING_BUFFER).item
    end

    def incubation_buffer(op)
        # @buffer_lookup[op.input(PROTEASE).sample][INCUBATION_BUFFER]
        op.input(INCUBATION_BUFFER).item
    end

    def quench_buffer(op)
        # @buffer_lookup[op.input(PROTEASE).sample][QUENCH_BUFFER]
        op.input(QUENCH_BUFFER).item
    end

    def protease_samples
        # @buffer_lookup.keys.select { |s| s.sample_type.name == PROTEASE }
        operations.map { |op| op.input(PROTEASE).sample }.uniq
    end

    def protease_needed
        operations.select { |op| op.temporary[:treatment_qty] > 0 }.present?
    end

    # Sort operations based on protease and concentration.
    #
    def sort_operations
        operations.sort! { |a, b| sort_list(b, a) <=> sort_list(a, b) }
    end

    # Provide an array of protease name and concentration to sort on.
    #
    def sort_list(x, y)
        [protease_name(x), protease_conc(y)]
    end

    def protease_name(op)
        op.input(PROTEASE).sample.name
    end

    def protease_conc(op)
        conc = op.input(PROTEASE_CONCENTRATION).val

        if conc.negative?
            conc = op.input(PROTEASE).item.get(:expected_treatment_concentration)
            conc ||= 10000
            op.input(PROTEASE_CONCENTRATION).update_attributes(val: conc)
            inspect "Op #{op.id} has been reassigned concentration #{conc}"
        end

        conc
    end

    def abbreviated_concentration(op)
        "#{protease_name(op)[0]}#{protease_conc(op).round}"
    end

    def ops_by_inc_bfr
        operations.group_by { |op| incubation_buffer(op)[:label] }
    end

    def ops_by_binding_bfr
        operations.group_by { |op| binding_buffer(op)[:label] }
    end

    def buffer_container(buffer:, handle:)
        if buffer.name == "PBSF" || buffer.name == "TBSF"
            container_name = BUFFER_CONTAINERS[BINDING_BUFFER]
        else
            container_name = BUFFER_CONTAINERS[handle]
        end

        attributes = { name: container_name, sample_type_id: buffer.sample_type.id }
        container = ObjectType.where(attributes).first
        raise "Container not found" unless container
        container
    end

end