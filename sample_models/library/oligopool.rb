needs "Sample Models/AbstractSample"

class OligoPool < AbstractSample

    THIS_SAMPLE_TYPE = "Oligo Pool"
    MANUFACTURER = "Manufacturer"
    OLIGO_POOL_ID = "Oligo Library ID"
    MIN_LENGTH = "min length (nt) (array)"
    MAX_LENGTH = "max length (nt) (array)"
    VARIANTS = "variants (array)"
    NAMES = "sublibrary name (array)"
    FORWARD_PRIMING_SITE = "forward priming site (array)"
    REVERSE_PRIMING_SITE = "reverse priming site (array)"

    # Instantiates a new OligoPool
    #
    # @param sample [Sample] Sample of SampleType "Oligo Pool"
    # @return [OligoPool]
    def initialize(sample:)
        super(sample: sample, expected_sample_type: THIS_SAMPLE_TYPE)
    end

    def self.from_item(item)
        OligoPool.new(sample: item.sample)
    end

    def primers_valid?(forward_primer:, reverse_primer:, sublibrary_name:)
        primers = [forward_primer, reverse_primer]
        sites = [
            forward_priming_site(sublibrary_name),
            reverse_priming_site(sublibrary_name)
        ]

        bindings = Primer.get_bindings(primers: primers, sites: sites)
        bindings.length == 2
    end

    def manufacturer
        properties.fetch(MANUFACTURER)
    end

    def oligo_library_id
        oligo_pool_id
    end

    def oligo_pool_id
        properties.fetch(OLIGO_POOL_ID)
    end

    def min_length(sublibrary_name)
        fetch(MIN_LENGTH, sublibrary_name)
    end

    def max_length(sublibrary_name)
        fetch(MAX_LENGTH, sublibrary_name)
    end

    def lengths(sublibrary_name)
        [min_length(sublibrary_name), max_length(sublibrary_name)]
    end

    def forward_priming_site(sublibrary_name)
        fetch(FORWARD_PRIMING_SITE, sublibrary_name)
    end

    def reverse_priming_site(sublibrary_name)
        fetch(REVERSE_PRIMING_SITE, sublibrary_name)
    end

    def priming_sites(sublibrary_name)
        [
            forward_priming_site(sublibrary_name),
            reverse_priming_site(sublibrary_name)
        ]
    end

    def variants(sublibrary_name)
        fetch(VARIANTS, sublibrary_name)
    end

    def fetch(property, sublibrary_name)
        properties.fetch(property)[sublibrary_index(sublibrary_name)]
    end

    def sublibrary_index(sublibrary_name)
        index = names.find_index(sublibrary_name)
        unless index
            raise SublibraryIndexError.new("#{sublibrary_name} not found in #{names}.")
        end
        index
    end

    def names
        properties.fetch(NAMES)
    end

end

class SublibraryIndexError < StandardError

end