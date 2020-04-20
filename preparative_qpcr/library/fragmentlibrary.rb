needs "Standard Libs/ProvenanceFinder"
needs "Standard Libs/CommonInputOutputNames"
needs "Standard Libs/Debug"
needs "Sample Models/Primer"
needs "Sample Models/OligoPool"
needs "Sample Models/DNALibrary"

class FragmentLibrary

    include ProvenanceFinder, CommonInputOutputNames, Debug

    OVERHANG = 'Overhang Sequence'
    ANNEAL = "Anneal Sequence"
    FWD_TEMPLATE = "FWD_%d"
    REV_TEMPLATE = "REV_%d"
    OLIGO_POOL = "Oligo Pool"

    attr_accessor :known_item, :sample
    attr_accessor :oligo_pools, :provenance, :errors
    attr_accessor :forward_primer, :reverse_primer
    attr_accessor :min_length, :max_length

    # Instantiates a new FragmentLibrary
    #
    # @param known_item [Item] an existing item, some type of DNA fragment library
    # @param sample [Sample] Sample used for addressing sublibraries in OligoPool
    # @return [FragmentLibrary]
    def initialize(known_item:, sample: nil)
        @known_item = known_item
        @sample = sample || known_item.sample
        @errors = {}
        @provenance = []
        @oligo_pools = []
        @forward_primer = nil
        @reverse_primer = nil
        @min_length = 0
        @max_length = 0
    end

    # Find Operation history of @known_item
    #
    # @return [Array]
    def detect_provenance
        self.provenance = walk_back("Don't Stop", known_item.id)
    end

    # Parses Operation history for last Item that is an Oligo Pool
    #
    # @return [OligoPool]
    def detect_oligo_pools
        if (oligo_pool = sample.properties.fetch(OLIGO_POOL))
            self.oligo_pools = [OligoPool.new(sample: oligo_pool)]
            return
        end

        detect_provenance unless provenance.present?
        prov_fvs = FieldValue.includes(:child_sample)
                             .where(parent_id: prov_op_ids, parent_class: "Operation")
        ogp_fvs = prov_fvs.select { |fv| OligoPool.is_oligo_pool?(fv.sample) }

        if ogp_fvs.present?
            self.oligo_pools = ogp_fvs.map { |fv| OligoPool.from_item(fv.item) }
            return
        end

        if known_item.get(:template_id)
            self.oligo_pools = [OligoPool.new(sample: Sample.find(known_item.get(:template_id)))]
            return
        end

        if known_item.get(:template)
            oligo_pool_id = known_item.get(:template).match(/(\d+) (\w+)/).captures[0]
            self.oligo_pools = [OligoPool.new(sample: Sample.find(oligo_pool_id))]
            return
        end

        unless oligo_pools.present?
            errors[:missing_oligo_pool] = "Could not find oligo pool(s) for Item #{known_item}."
        end
    end

    # Compares names of all sulibraries of all oligo pools with all sample names from
    #   the provenance,including self.sample. Returns the names of sublibraries that
    #   are found in the names of any of the samples. The entire sublibrary name
    #   must appear in the sample name, but the comparison is case-insensitive.
    def sublibrary_names
        prov_fvs = FieldValue.includes(:child_sample)
                             .where(parent_id: prov_op_ids, parent_class: "Operation")
        prov_sample_names = prov_fvs.map { |fv| fv.sample.try(:name) }
        prov_sample_names.append(sample.name)
        all_sublib_names = oligo_pools.map { |ogp| ogp.names }.flatten
        all_sublib_names.select { |s| prov_sample_names.select { |p| p =~ /#{s}/i }.any? }
    end

    # TODO: This is probably going to break if there are two sublibraries from
    # the same oligo pool
    def sublibrary_name(oligo_pool)
        names = oligo_pool.names & sublibrary_names
        unless names.length == 1
            msg = "Failed to find unique sublibrary: #{names}"
            raise SublibraryIndexError.new(msg)
        end
        names.first
    end

    def prov_op_ids
        provenance.flatten.map { |op| op.id }
    end

    def variants
        oligo_pools.map { |ogp| ogp.variants(sublibrary_name(ogp)).to_i }.reduce(:+)
    end

    def min_oligo_pool_length
        oligo_pools.map { |ogp| ogp.min_length(sublibrary_name(ogp)).to_i }.min
    end

    def max_oligo_pool_length
        oligo_pools.map { |ogp| ogp.max_length(sublibrary_name(ogp)).to_i }.max
    end

    # Sets primers to be used for amplifying library in calling Protocol
    # Will be used to calculate the size distribution of the OUTPUT FragmentLibrary
    #
    # @param forward_primer [Sample]
    # @param reverse_primer [Sample]
    def set_primers(forward_primer:, reverse_primer:)
        forward_primer = Primer.new(sample: forward_primer)
        reverse_primer = Primer.new(sample: reverse_primer)
        if primers_valid?(forward_primer: forward_primer, reverse_primer: reverse_primer)
            self.forward_primer = forward_primer
            self.reverse_primer = reverse_primer
        else
            input_primers = [forward_primer.name, reverse_primer.name].to_sentence
            msg = "Primer pair #{input_primers} invalid for Oligo Pool #{oligo_pool.sample.id}."
            errors[:mismatched_sublibrary_primers] = msg
        end
    end

    def primers_valid?(forward_primer:, reverse_primer:)
        oligo_pools.each do |oligo_pool|
            return false unless oligo_pool.primers_valid?(
                forward_primer: forward_primer,
                reverse_primer: reverse_primer,
                sublibrary_name: sublibrary_name(oligo_pool)
            )
        end
        true
    end

    # TODO: This doesn't deal with branched provenance correctly.
    # Different branches can have oligo pools with differrent priming sites.
    # PCRs need to be simulated in the correct order for each branch.
    def calculate_length
        next_sites = oligo_pools.map { |ogp| ogp.priming_sites(sublibrary_name(ogp)) }
                                .flatten.uniq

        unless next_sites.length == 2
            ogp_ids = oligo_pools.map { |ogp| ogp.sample.id }
            msg = "Incompatible priming sites #{next_sites} found for OligoPools #{ogp_ids}"
            raise IncompatiblePrimingSitesError.new(msg)
        end

        priming_length = next_sites[0].length + next_sites[1].length

        lengths = oligo_pools.map { |ogp| ogp.lengths(sublibrary_name(ogp)) }.flatten.sort
        min_internal_length = lengths[0] - priming_length
        max_internal_length = lengths[-1] - priming_length


        primer_sets.each do |primers|
            sites = next_sites
            next_sites = []

            bindings = Primer.get_bindings(primers: primers, sites: sites)

            bindings.each do |b|
                priming_length += b[:added_length]
                next_sites.append(b[:primer].sequence)
            end
        end

        self.min_length = min_internal_length + priming_length
        self.max_length = max_internal_length + priming_length
    end

    def primer_sets
        primer_sets = []

        pcr_ops.each do |op|
            # There are older operations that use different I/O names
            # fp = Primer.new(op.input(FORWARD_PRIMER).sample)
            # rp = Primer.new(op.input(REVERSE_PRIMER).sample)
            # primer_sets.append([fp, rp])
            primers = op.inputs.select { |fv| fv.sample && fv.sample.sample_type.name == "Primer" }
            primers = primers.map { |fv| Primer.from_item(fv.item) }
            primer_sets.append(primers)
        end

        if forward_primer && reverse_primer
            primer_sets.append([forward_primer, reverse_primer])
        end

        primer_sets
    end

    def pcr_ops
        provenance.flatten.select { |op| pcr_operation?(op) }.reverse
    end

    def pcr_operation?(op)
        pcr_op_names = [
            "Make qPCR Fragment",
            "Make qPCR Fragment WITH PLATES",
            "Library qPCR Black Box"
        ]

        pcr_op_names.include?(op.operation_type.name)
    end
end