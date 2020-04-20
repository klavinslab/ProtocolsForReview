needs "Sample Models/AbstractSample"

class DNALibrary < AbstractSample

    THIS_SAMPLE_TYPE = "DNALibrary"
    OLIGO_POOL = "Oligo Pool"

    # Instantiates a new DNALibrary
    #
    # @param sample [Sample] Sample of SampleType "DNALibrary"
    # @return DNALibrary
    def initialize(sample:)
        super(sample: sample, expected_sample_type: THIS_SAMPLE_TYPE)
    end

    def self.from_item(item)
        DNALibrary.new(sample: item.sample)
    end

    def oligo_pool
        fetch(OLIGO_POOL)
    end
    
end