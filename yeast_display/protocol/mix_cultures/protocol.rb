# frozen_string_literal: true

# @author Devin Strickland
# @email dvn.strcklnd@gmail.com

needs 'Yeast Display/YeastDisplayHelper'
needs 'Standard Libs/AssociationManagement'
needs 'Standard Libs/Debug'

class Protocol
  include AssociationManagement
  include Debug
  include PartProvenance
  include YeastDisplayHelper

  INPUT_YEAST = 'Component Yeast Culture'
  PROPORTIONS = 'Proportions'

  def main
    operations.retrieve.make
    discard_items = []

    operations.each do |op|
      discard_items += operation_mix(op)
    end

    discard_items.uniq!
    mark_cultures_for_discard(discard_items)
    release(discard_items, interactive: true)
  end

  def operation_mix(operation)
    input_cultures = operation.input_array(INPUT_YEAST).items
    proportions = operation.input(PROPORTIONS).value.scan(/[\d\.]+/)

    mix_table = create_mix_table(cultures: input_cultures,
                                 proportions: proportions)
    show_mix(mix_table)
    add_culture_provenance(cultures: input_cultures,
                           culture_mix: operation.output('Yeast Culture').item,
                           proportions: proportions)

    input_cultures
  end

  def create_mix_table(cultures:, proportions:)
    mix_table = [["#{INPUT_YEAST} Item ID", PROPORTIONS]]
    culture_ids = cultures.map(&:id)

    mix_table + [culture_ids, proportions].transpose
  end

  def show_mix(mix_table)
    # TODO: make "not very different" more exact
    # TODO: be more detailed about how to do proportional mixing
    show do
      title 'Mix cultures'

      note 'Inspect the cultures to make sure the ODs are not very different'
      note 'If they are very different, then dilute the higher density ' \
           'culture to the same OD as the lower density one'
      note 'Once the ODs are close, mix the cultures according to the ' \
           'following proportions'
      table mix_table
    end
  end

  # Adds provenance to the input and output cultures for this Mix Cultures.
  # Includes the proportion of each input in the mix as an attribute.
  #
  # @param cultures [Array<Item>]  the array of input cultures
  # @param culture_mix [Item]  the output culture
  # @param proportions [Array<Float>]  the proportion array
  def add_culture_provenance(cultures:, culture_mix:, proportions:)
    mix_associations = AssociationMap.new(culture_mix)
    cultures.each_with_index do |culture, index|
      culture_associations = AssociationMap.new(culture)
      proportion = { proportion: proportions[index] }
      add_provenance(from: culture, from_map: culture_associations,
                     to: culture_mix, to_map: mix_associations,
                     additional_relation_data: proportion)
      culture_associations.save
    end
    mix_associations.save
  end
end
