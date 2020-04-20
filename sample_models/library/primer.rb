needs "Sample Models/AbstractSample"

# frozen_string_literal: true

# Defines the Primer class with methods to manage the properties of primers,
#   such as sequence, length, priming site, etc.
class Primer < AbstractSample

    THIS_SAMPLE_TYPE = "Primer"
    OVERHANG_SEQUENCE = "Overhang Sequence"
    ANNEAL_SEQUENCE = "Anneal Sequence"
    T_ANNEAL = "T Anneal"
    private_constant(
      :THIS_SAMPLE_TYPE, :OVERHANG_SEQUENCE, :ANNEAL_SEQUENCE, :T_ANNEAL
    )

    # Instantiates a new Primer
    #
    # @param sample [Sample] Sample of SampleType "Primer"
    # @return [Primer]
    def initialize(sample:)
        super(sample: sample, expected_sample_type: THIS_SAMPLE_TYPE)
    end

    # Instantiates a new Primer from an Item
    #
    # @param item [Item] Item of a Sample of SampleType "Primer"
    # @return [Primer]
    def self.from_item(item)
        Primer.new(sample: item.sample)
    end

    # The overhang sequence
    #
    # @return [String]
    def overhang_sequence
        fetch(OVERHANG_SEQUENCE).strip
    end

    # The anneal sequence
    #
    # @return [String]
    def anneal_sequence
        fetch(ANNEAL_SEQUENCE).strip
    end

    # The full sequence of the primer
    #
    # @return [String]
    def sequence
        overhang_sequence + anneal_sequence
    end

    # The length of the primer in nt
    #
    # @return [FixNum]
    def length
        sequence.length
    end

    # The annealing temperature of the primer
    #
    # @note This is the temperature as it is entered into the database. It is not
    #   calculated and may be inacurate depending on the template.
    # @return [FixNum]
    def t_anneal
        fetch(T_ANNEAL)
    end

    # Finds binding sites for a set of primers on a set of templates
    #
    # @param primers [Array<Primer>] the primers
    # @param sites [Array<String>] the templates to be scanned
    # @return [Array<Hash>]
    def self.get_bindings(primers:, sites:)
        bindings = []
        primers.each do |primer|
            sites.each do |site|
                offset = primer.detect_priming_site(template: site)
                if offset
                    added_length = primer.sequence.length - offset[1]

                    if added_length < 0
                        raise "Primer model detected binding site longer than the primer sequence."
                    end

                    b = {
                        primer: primer,
                        site: site,
                        offset: offset,
                        added_length: added_length
                    }
                    bindings.append(b)
                    sites.delete(site)
                    break
                end
            end
        end
        bindings
    end

    # Finds the first binding site for a Primer on a template
    #
    # @todo make this work with multiple matches and internal matches
    # @param template [String] the template sequence
    # @param min_length [FixNum] the minimum length of the binding site
    # @param require_perfect [FixNum] the number of nt from the 3' end that must match perfectly
    # @param allow_mismatch [FixNum] the number of mismatches allowed (doesn't do anything currently)
    # @return [Array<FixNum>]
    def detect_priming_site(template:, min_length: 16, require_perfect: 3, allow_mismatch: 1)
        query = last(require_perfect)
        matches = scan(template, query)
        matches.delete_if { |m| m.offset(0)[1] < min_length }
        return if matches.blank?

        i = 0
        loop do
            break if matches.length <= 1
            i += 1
            query = last(require_perfect + i)
            matches.keep_if { |m| expand_match(template, m, i) =~ /#{query}/i }
        end

        start, stop = matches[0].offset(0)
        return unless template[0..stop] =~ /#{last(stop)}/i
        [0, stop]
    end

    # The last n nucleotides of the sequence
    #
    # @param n [FixNum]
    # @return [String]
    def last(n)
        sequence[-n..-1]
    end

    # Scans the template with a pattern and returns an array of MatchData objects
    #
    # @param template [String] the sequence to be scanned
    # @param pat [String] the sequence to scan for
    # @return [Array<MatchData>]
    def scan(template, pat)
        template.to_enum(:scan, /#{pat}/i).map { Regexp.last_match }
    end

    def expand_match(template, match, i)
        start, stop = match.offset(0)
        template[start - i..stop]
    end

end

class IncompatiblePrimingSitesError < StandardError

end