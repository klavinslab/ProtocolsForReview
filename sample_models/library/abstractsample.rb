class AbstractSample

    attr_accessor :item, :sample, :properties

    # Instantiates a new AbstractSample
    #
    # @param sample [Sample] Sample
    # @return [AbstractSample]
    def initialize(sample:, expected_sample_type:)
        @sample = sample
        @properties = sample.properties

        is_expected_type?(expected_sample_type)
    end

    # Test whether a Sample is of the expected type
    #
    # @param test_sample [Sample]
    # @return [Boolean]
    def is_expected_type?(expected_sample_type)
        unless sample && sample.sample_type.name == expected_sample_type
            msg = "Sample #{sample.id}, #{sample.sample_type.name}, is not a #{expected_sample_type}."
            raise WrongSampleTypeError.new(msg)
        end
    end

    # The name of the sample
    #
    # @return [String]
    def name
        sample.name
    end

    # Fetches a property based on its name
    #
    # @param property [String] the name of the property
    # @return [Object] whatever the property points to
    def fetch(property)
        properties.fetch(property)
    end
end

class WrongSampleTypeError < StandardError

end