needs 'Flow Cytometry/Cytometers'

class Protocol
  include Cytometers

  INPUT_NAME = '96 well plate'.freeze
  WELL_VOL = 'well volume (µL)'.freeze # not really used

  SAMPLE_TYPE = 'sample type'.freeze

  def main
    operations.retrieve # should be in loop!!!
    
    cytometer = Cytometers::BDAccuri.instance

    operations.each do |op|
      show do
        title 'Flow cytometery - info'
        warning "The following should be run on a browser window on the #{cytometer.cytometer_name} computer!"
      end

      cytometer.clean

      cytometer.run_sample_96(sample_string: op.input(SAMPLE_TYPE).val,
                              collection: op.input(INPUT_NAME).collection,
                              operation: op,
                              plan: op.plan)
    end
    cytometer.clean

    # dispose plates
    # operations.each { |op| op.input(INPUT_NAME).item.mark_as_deleted } # Why are we diposing the input collection?
    {}

#   rescue CytometerInputError => e
#     show { "Error: #{e.message}" }
  end
end
