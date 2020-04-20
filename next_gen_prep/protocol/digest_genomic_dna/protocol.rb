# frozen_string_literal: true

# Sarah Goldberg
# Refactored by Devin Strickland

needs 'Next Gen Prep/NextGenPrepHelper'
needs 'Yeast Display/YeastDisplayHelper'
needs 'Standard Libs/AssociationManagement'
needs 'Standard Libs/Units'
needs 'Standard Libs/Debug'

class Protocol
  include AssociationManagement
  include Debug
  include NextGenPrepHelper
  include PartProvenance
  include Units
  include YeastDisplayHelper

  INPUT = 'Zymoprepped sample'
  OUTPUT = 'Exonucleased sample'

  BUFFER = 'Lambda Exonuclease Buffer'
  BUFFER_VOL = { qty: 4, units: MICROLITERS }.freeze

  EXO = 'Exonuclease I'
  EXO_VOL = { qty: 4, units: MICROLITERS }.freeze

  LAMBDA = 'Lambda Exonuclease'
  LAMBDA_VOL = { qty: 2, units: MICROLITERS }.freeze

  MAKE_EXTRA_REAGENT = 1.1

  INCUBATION_LOCATION = 'incubator'
  INCUBATION_TEMP = { qty: 30, units: DEGREES_C }.freeze
  INCUBATION_TIME = { qty: 90, units: MINUTES }.freeze

  INACTIVATION_LOCATION = 'dry block'
  INACTIVATION_TEMP = { qty: 80, units: DEGREES_C }.freeze
  INACTIVATION_TIME = { qty: 20, units: MINUTES }.freeze

  def main
    operations.sort_by! { |op| op.input(INPUT).item.id }

    operations.retrieve.make

    assign_tube_numbers(INPUT, OUTPUT)
    gather_enzymes_and_buffer
    set_up_reactions_and_run(operations)
    number_tubes_and_columns
    transfer_to_columns
    wash_samples(pb_washes = 0)
    elute_samples(OUTPUT)

    operations.each do |op|
      add_sample_provenance(
        input: op.input(INPUT).item,
        output: op.output(OUTPUT).item
      )
      unless op.input(INPUT).item.get(:bin).nil? # sorted sample
        op.output(OUTPUT).item.associate(:bin, op.input(INPUT).item.get(:bin))
      end
      op.input(INPUT).item.mark_as_deleted
    end

    operations.store

    {}
  end

  def gather_enzymes_and_buffer
    materials = [
      Sample.find_by_name(BUFFER).in('Enzyme Buffer Stock').first,
      Sample.find_by_name(LAMBDA).in('Enzyme Stock').first,
      Sample.find_by_name(EXO).in('Enzyme Stock').first
    ]

    show do
      title 'Grab an ice block'
      warning 'In the following step you will need to take enzymes out of ' \
              'the freezer. Make sure the enzymes are kept on ice for the ' \
              'duration of the protocol.'
    end

    take(materials, interactive: true, method: 'boxes')
  end

  def show_prepare_master_mix(volume_factor)
    show do
      title 'Prepare master mix'

      warning 'Keep exonucleases and Master Mix on cold block!'

      check "Label a #{MICROFUGE_TUBE} 'Master Mix'"
      check "Add <b>#{expanded_volume_display(BUFFER_VOL, volume_factor, 1)}</b> of #{BUFFER} to Master Mix"
      check "Add <b>#{expanded_volume_display(EXO_VOL, volume_factor, 1)}</b> of #{EXO} to Master Mix"
      check "Add <b>#{expanded_volume_display(LAMBDA_VOL, volume_factor, 1)}</b> of #{LAMBDA} to Master Mix"

      check 'Flick the tube gently to mix'
    end
  end

  def show_prepare_reactions(operations)
    mm_vol = BUFFER_VOL[:qty] + EXO_VOL[:qty] + LAMBDA_VOL[:qty]
    show do
      title 'Prepare exonuclease reactions'

      check 'Re-label tubes according to the table and then add ' \
            '10uL Master Mix according to the table.'

      table operations.start_table
                      .input_item(INPUT)
                      .custom_column(
                        heading: 'Tube number',
                        checkable: true
                      ) { |op| op.input(INPUT).item.associations[:tube_number] }
                      .custom_column(
                        heading: "Master Mix (#{BUFFER_VOL[:units]})",
                        checkable: true
                      ) { |_op| mm_vol }
                      .end_table

      check 'Briefly vortex and spin.'
    end
  end

  def set_up_reactions_and_run(operations)
    show_prepare_master_mix(operations.length * MAKE_EXTRA_REAGENT)
    show_prepare_reactions(operations)

    show do
      title "Incubate at #{qty_display(INCUBATION_TEMP)}"

      check "Place the tube in the #{qty_display(INCUBATION_TEMP)} " \
            "#{INCUBATION_LOCATION} for #{qty_display(INCUBATION_TIME)}"
      check "Bump a heat block up to #{qty_display(INACTIVATION_TEMP)} for the next step"
      note "Check with a manager about which heat block to set up"
    end

    show do
      title "Inactivate at #{qty_display(INACTIVATION_TEMP)}"

      check "Place the tube in the #{qty_display(INACTIVATION_TEMP)} " \
            "#{INACTIVATION_LOCATION} for #{qty_display(INACTIVATION_TIME)}"
    end
  end

  def transfer_to_columns
    show do
      title "Transfer to #{COLUMN}s"

      check 'When the inactivation is finished, retrieve the samples'
      note '<b>For each sample:</b>'
      check "Add #{qty_display(PB_VOL)} #{PB}"
      check 'Vortex and spin samples'
      check "Transfer the mixture to the #{COLUMN} with the same number"
    end
  end

  def add_sample_provenance(input:, output:)
    input_associations = AssociationMap.new(input)
    output_associations = AssociationMap.new(output)
    add_provenance(from: input, from_map: input_associations,
                   to: output, to_map: output_associations)
    input_associations.save
    output_associations.save
  end
end
