needs "Yeast Display/YeastDisplayHelper"

module FastMixAndQuench

    include YeastDisplayHelper
    # Mix the treatment aliquots with the cell suspensions and incubate for the specified time.
    #
    def arrange_tubes(args)
        args = arrange_defaults.merge(args)

        show do
            title "Set up #{args[:treatment_name]} and #{args[:sample_name]} aliquots"
            note temp_instructions(args[:temp])

            note 'Arrange the tubes in a tube holder as shown'

            if args[:grouped_ops].keys.length > 1
                note "Leave space between the groups of tubes"
            end

            h1 = args[:treatment_name].titlecase
            h2 = args[:sample_name].titlecase

            args[:grouped_ops].each do |bfr, ops|
                note "<br>"
                table ops.start_table
                    .custom_column(heading: h1) { |op| treatment_tube_label(op, args[:output_handle]) }
                    .custom_column(heading: h2, checkable: true) { |op| sample_tube_label(op, args[:output_handle]) }
                    .end_table
            end
        end
    end

    def mix_samples(args)
        args = mix_defaults.merge(args)
        show do
            title "Mix #{args[:treatment_name]} and #{args[:sample_name]} aliquots"
            warning 'Before you perform the following steps, set the timer to countdown for 5 minutes.'
            warning "Start the timer as you add the first set of #{args[:treatment_name]} aliquots to the #{args[:sample_name]} aliquots."

            note "Use a multichannel pipettor to transfer #{qty_display(args[:treatment_vol])} of the #{args[:treatment_name]} aliquots into the #{args[:sample_name]} aliquots."
            note "You will only be able to pipet one of the buffers at a time."
            note "Add the buffers in this order: #{args[:grouped_ops].keys.join(', ')}."

            note "After you make the transfer, pipet up and down three times with the multichannel pipettor to mix the samples."
        end
    end

    def incubate(args)
        args = incubate_defaults.merge(args)

        time_left = args[:incubation_time].dup

        show do
            title "Incubate with #{args[:treatment_name]} for #{qty_display(args[:incubation_time])}"

            note "<b>STEP 1:</b> Incubate"
            note "Incubate #{qty_display(args[:incubation_time])} at room temperature."

            while time_left[:qty] > args[:vortex_interval][:qty]
                time_left[:qty] -= args[:vortex_interval][:qty]
                check "Vortex tubes for 5 seconds when #{qty_display(time_left)} remains."
            end

            if args[:quench_protease]
                check 'After the last vortex, open the tubes and get ready to add the quench buffer into the multichannel pipettor.'

                note "<b>STEP 2:</b> Quench and remove buffer"
                note "When the timer is complete, add #{qty_display(args[:quench_vol])} chilled quench buffer to each tube according to the table."

                args[:grouped_ops].each do |bfr, ops|
                    note ""
                    table wash_buffer_table(ops, output_handle: args[:output_handle], buffer_handle: args[:buffer_handle])
                end

                note VORTEX_CELLS
            end

            check SPIN_CELLS
            check REMOVE_BUFFER
        end
    end

    def common_defaults
        {
            treatment_name: 'protease',
            sample_name: 'yeast culture'
        }
    end

    def arrange_defaults
        common_defaults #.merge({})
    end

    def mix_defaults
        common_defaults #.merge({})
    end

    def incubate_defaults
        common_defaults #.merge({})
    end
end