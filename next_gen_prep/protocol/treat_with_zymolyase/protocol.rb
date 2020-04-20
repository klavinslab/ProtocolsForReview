# SG
# Refactored by Devin Strickland 2/12/18

needs "Yeast Display/YeastDisplayHelper"
needs "Standard Libs/Debug"
needs "Standard Libs/SortHelper"

class Protocol

    include YeastDisplayHelper, Debug, SortHelper

    INPUT_YEAST = 'Yeast Library'
    OUTPUT_YEAST = INPUT_YEAST

    MIXER = "orbital shaker in the 37 #{DEGREES_C} incubator"

    ZYMOLYASE_VOL = { qty: 5, units: MICROLITERS }
    ZYMOLYASE_TIME = { qty: 4, units: HOURS }
    SPEED = { qty: 900, units: 'RPM' }

    def main

        # sort ops by id - DO NOT DELETE
        ops_sorted=sortByMultipleIO(operations.running, ["in"], [INPUT_YEAST], ["id"], ["item"])
        operations=ops_sorted

        operations.retrieve

        operations.each do |op|
            op.pass(INPUT_YEAST)
            op.output(OUTPUT_YEAST).item.move_to(MIXER)
        end

        zymolyase = Item.where(sample_id: Sample.find_by_name("Zymolyase")).where(Item.arel_table[:location].not_eq('deleted')).order('id ASC').first

        # Get ice blocks
        get_zymolyase

        thaw_samples zymolyase

        treat_with_zymolyase

        show do
            title "Return the following item(s)"

            note "Return Zymolyase at #{zymolyase.location}"
        end

        operations.store

        return {}

    end

    def get_zymolyase
        show do
            title "Grab an ice block"

            warning "In the following step you will need to take Zymolyase enzyme out of freezer. Make sure the enzyme is kept on ice for the duration of the protocol."
        end
    end

    def thaw_samples zymolyase
        show do
            title "Thaw samples"

            check "Grab zymolyase from #{zymolyase.location}"
            check "Allow the samples to thaw on the 42C heatblock for 5 minutes"
        end
    end

    def treat_with_zymolyase
        show do
            title "Treat samples with zymolyase"

            note "Add zymolyase to each sample in the fume hood according to the table"
            table operations.start_table
              .input_item(INPUT_YEAST)
              .custom_column(heading: "zymolyase (#{ZYMOLYASE_VOL[:units]})", checkable: true) { |op| ZYMOLYASE_VOL[:qty] }
              .end_table
            note "Vortex samples after zymolyase is added."
            check "Place the samples on the #{MIXER} for <b>#{qty_display(ZYMOLYASE_TIME)}</b> at #{qty_display(SPEED)}"
        end
    end

end