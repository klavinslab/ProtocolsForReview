# SG
# Refactored by Devin Strickland 2/12/18

needs "Next Gen Prep/NextGenPrepHelper"
needs "Standard Libs/Units"
needs "Yeast Display/YeastDisplayHelper"
needs "Standard Libs/Debug"
needs "Standard Libs/SortHelper"
needs "Standard Libs/Feedback"

class Protocol

    include NextGenPrepHelper, Units, YeastDisplayHelper, Debug, SortHelper, Feedback

    INPUT_YEAST = "Yeast Library"
    OUTPUT_PLASMID = "Plasmid Library"

    SOLN2 = "Lysis buffer (Solution 2)"
    SOLN2_VOL = { qty: 200, units: 'µl' }
    SOLN2_TIME = { qty: 5, units: 'min' }

    SOLN3 = "Neutralizing buffer (Solution 3)"
    SOLN3_VOL = { qty: 400, units: 'µl' }

    FREEZE_TIME = { qty: 30, units: 'min' }
    INVERT_TIMES = 10

    def main

        operations.retrieve

        # sort by input id before make
        ops = sortByMultipleIO(operations, ["in"], [INPUT_YEAST], ["id"], ["item"])
        operations = ops
        operations.make

        put_samples_in_freezer

        thaw_samples

        gather_materials

        assign_tube_numbers(INPUT_YEAST, OUTPUT_PLASMID)

        number_tubes

        lyse_and_neutralize

        pellet_cell_debris

        # number_tubes_and_columns

        wash_samples

        elute_samples(OUTPUT_PLASMID)

        operations.each { |op|
            if( !(op.input(INPUT_YEAST).item.get(:bin).nil?) ) # sorted sample
                op.output(OUTPUT_PLASMID).item.associate(:bin, op.input(INPUT_YEAST).item.get(:bin))
            end
            op.input(INPUT_YEAST).item.mark_as_deleted
        }

        operations.store

        get_protocol_feedback

        return {}

    end

    def gather_materials
        show do
            title "Gather the following materials"

            check "#{SOLN2} from Zympoprep kit (at least #{operations.length*SOLN2_VOL[:qty]} #{SOLN2_VOL[:units]}) BLUE color solution"
            check "#{SOLN3} from Zympoprep kit (at least #{operations.length*SOLN3_VOL[:qty]} #{SOLN3_VOL[:units]}) YELLOW color solution"
            # check "#{operations.length} Qiagen miniprep column(s)"
            check "PB, PE, EB buffers from Qiagen kit"
        end
    end

    def put_samples_in_freezer
        show do
            title "Freeze the samples"

            check "Place the rack containing the samples in the -80C"
            check "Set timer for <b>#{qty_display(FREEZE_TIME)}</b>"
        end
    end

    def thaw_samples
        show do
            title "Thaw the samples"

            check "When timer is finished, retrieve samples from -80C and thaw on 42 C heat block"
            check "Set timer for <b>5 minutes</b>"
            check "After setting the timer, proceed to the next step to gather items"
        end
    end

    def number_tubes
        show do
            title "Re-label tubes"

            note "Number the tubes according to the table"
            table operations.start_table
                .input_item(INPUT_YEAST)
                .custom_column(heading: "Number", checkable: true) { |op| op.input(INPUT_YEAST).item.associations[:tube_number] }
                .end_table
        end
    end

    def lyse_and_neutralize
        show do
            title "Lyse the samples"

            check "Add <b>#{qty_display(SOLN2_VOL)}</b> of #{SOLN2} BLUE color solution to each sample"
            check "Start 5 minute timer and invert samples <b>#{INVERT_TIMES} times</b> to mix"
            check "At 3 minute mark invert samples <b>5 more times</b>"

            # note "While you wait, get #{operations.length} #{MICROFUGE_TUBE}s and number them 1 - #{operations.length}"
        end

        show do
            title "Neutralize the samples"

            check "When the timer is finished, add <b>#{qty_display(SOLN3_VOL)}</b> of #{SOLN3} YELLOW color solution to all samples"
            check "Invert samples <b>#{INVERT_TIMES} times</b> to mix"
        end
    end

    def pellet_cell_debris
        show do
            title "Pellet cell debris"

            [MICROFUGE_TUBE, COLUMN].each do |receptacle|
                check CENTRIFUGE % qty_display(LONG_SPIN_EXTRACT_PLASMID)
                check "While waiting, get #{operations.length} #{receptacle}s and label them 1 - #{operations.length}"
                check "Transfer the supernatant of each sample to the new empty #{receptacle} with the same number"
            end

        end
    end

end