# MAD7 Multiplex Integration Project
# 10/23/18
# By: E. Lopez
# elopez3@uw.edu
needs "Standard Libs/Debug"
needs "Standard Libs/Units"
needs "Cloning Libs/Cloning"
needs "Tissue Culture Libs/CollectionDisplay"

class Protocol
  include Debug, Units
  include Cloning
  include CollectionDisplay

  # DEF
  INPUT = "Fragment Mix"
  OUTPUT = "Fragment"
  OUTPUT_SW = "Stripwell"

  # Parameters
  OVERLAP_Tm = "Overlap Annealing Temperature"

  # Constants
  FRAG_CONC = 100.0 #ng
  PRIMER_CONC = 10.0 #uM
  TOTAL_VOL = 50.0 #uL
  KAPA_VOL = 25.0 #uL
  TRANSFER_VOL = 40 #uL  amount to transfer to a new tube
  SOE_THERMO_TEMPLATE = "SOE" # Name of thermocycler conditions template
  DMSO_VOL = TOTAL_VOL * 0.03#uL - 3% in a 50ul rxn
  
  def intro()
    show do
      title "Stitching Fragments by Overlap Extention (SOE)"
      separator
      note "In this protocol you will be guided in preparing an SOE reaction."
      note "This method takes advantage of DNA fragments that have overlapping sequences."
      note "The overlapping fragments will act as primers themselves and polymerize to create the desired amplicon."
      note "<b>1.</b> Gather materials and fill with KAPA Master Mix"
      note "<b>2.</b> Add fragments in either equimolar ratios or similar mass - OPTIMIZE WHICH TO USE"
      note "<b>3.</b> Setup thermocycler conditions for SOE"
      note "<b>4.</b> Transfer samples from stripwells to labelled microfuge tubes for storage."
    end
  end

  def main

    operations.make

    # Intro
    intro()

    # Gather materials
    operations.retrieve

    check_frag_concentrations()

    groupby_out_collection = operations.group_by {|op| op.output(OUTPUT_SW).collection}

    kapa_stock_item = gather_materials(groupby_out_collection)

    prepare_soe_rxns(groupby_out_collection)

    prepare_thermo_soe(groupby_out_collection)

    clean_up_inputs([kapa_stock_item])

    wait()

    dna_mix_storage_transfer(groupby_out_collection)

    clean_up_outputs()

    {}

  end# main

  # Checks the concentration of operations that have fragment input arrays
  def check_frag_concentrations()
    frag_ops = operations.select {|op| op.input_array(INPUT).samples.map {|s| s.sample_type.name}.uniq.first == 'Fragment'}
    check_concentration frag_ops, input_name = INPUT # From Cloning Libs/Cloning
  end

  # Calculates the volume required for each input item
  #
  # @params ops [operations] the set of operations that has been grouped by out collection
  # @returns input_vol_arr [2-D Array] each array in array contains the input volumes for each item in the input_array of an operation
  def calc_input_vol(ops)
    input_vol_arr = ops.map {|op|
      op.input_array(INPUT).items.map {|i|
        if i.object_type.name == "Fragment Stock"
          conc = i.get('concentration').to_f
          if debug # In production fragments will be nanodropped and concentration will be associated before this calculation
            (conc.nil? || conc == 0) ? conc = 42 : conc
          end
          vol = (FRAG_CONC / conc).round(2)
        else
          conc = i.get('concentration_uM').to_f
          (conc.nil? || conc == 0) ? conc = 10 : conc # Primer Aliquots are always diluted to 10uM in Rehydrate Primer
          vol = (PRIMER_CONC / conc).round(2)
        end
      }
    }
    return input_vol_arr
  end


  # Gather materials needed for this experiment
  #
  # @params groupby_out_collection [hash] is a hash of operations grouped by the output collection
  # @returns kapa_stock_item [item obj] is the actual kapa master mix item
  def gather_materials(groupby_out_collection)
    # Find KAPA item and retrieve from inventory
    kapa_stock_item = find(:sample, name: "Kapa HF Master Mix")[0].in("Enzyme Stock")[0]
    take [kapa_stock_item], interactive: true
    collection_type = groupby_out_collection.map {|coll, ops| coll.object_type.name}.uniq.first
    show do
      title "Gather Materials"
      separator
      check "Get Ice in the <b>Seelig Lab</b>"
      check "Let the KAPA Master Mix #{kapa_stock_item} thaw on ice"
      check "Gather <b>#{groupby_out_collection.length}</b> new, clean <b>#{collection_type}</b>"
      check "Gather <b>MG H2O</b>"
    end
    return kapa_stock_item
  end

  # Guides tech to prepare the SOE reactions in a stripwell
  #
  # @params groupby_out_collection [hash] is a hash of operations grouped by the output collection
  def prepare_soe_rxns(groupby_out_collection)
    groupby_out_collection.each {|coll, ops|

      stripwell_mat = calc_input_vol(ops)
      h2o_arr = stripwell_mat.each_with_index.map {|well, w_idx| TOTAL_VOL - KAPA_VOL - DMSO_VOL - well.reduce(0, :+)}
      if debug
        show do
          title "Debuggin"
          note "stripwell_mat #{stripwell_mat}"
          note "h2o arr #{h2o_arr}"
        end
      end
      # Fill collection with water
      show do
        title "Filling #{coll.object_type.name} #{coll}"
        separator
        note "Gather a clean, new #{coll.object_type.name} and label it: <b>#{coll}</b>"
        note "Follow the table below to fill the new #{coll.object_type.name} with <b>MG H2O</b>"
        table highlight_non_empty(coll) {|r, c| "#{h2o_arr[c]}#{MICROLITERS}"}
      end
      # Fill collection with DMSO
      show do
        title "Adding DMSO to #{coll.object_type.name} #{coll}"
        separator
        note "Follow the table below to fill the  #{coll.object_type.name} with <b>100% DMSO</b>"
        table highlight_non_empty(coll) {|r, c| "#{DMSO_VOL}#{MICROLITERS}"}
      end

      # Build Display table
      tab = [['Stripwell', 'Well', 'Input Item', "Volume (#{MICROLITERS})"]]
      ops.each_with_index {|op, o_idx|
        well_vols = stripwell_mat[o_idx]
        op.input_array(INPUT).items.each_with_index {|i, i_idx|
          input_vol = well_vols[i_idx]
          tab.push([op.output(OUTPUT_SW).collection.id, "#{op.output(OUTPUT_SW).column+1}", i.id, {content: input_vol, check: true}])
        }
      }
      # Load Fragments
      show do
        title "Filling #{coll.object_type.name} #{coll}"
        separator
        note "Follow the table below to fill the appropriate well with the correct fragment stock:"
        table tab
      end
      
      # Fill collection with MM
      show do
        title "Filling #{coll.object_type.name} #{coll}"
        separator
        note "Follow the table below to fill #{coll} with <b>KAPA Master Mix</b>"
        bullet "Mix throughly by pipetting"
        table highlight_non_empty(coll) {|r, c| "#{KAPA_VOL}#{MICROLITERS}"}
      end
    }
  end

  # Guides tech to prepare thermocycler
  #
  # @params groupby_out_collection [hash] is a hash of operations grouped by the output collection
  def prepare_thermo_soe(groupby_out_collection)
    oa_temp = operations.map {|op| op.input(OVERLAP_Tm).val}.uniq.first
    f_amplicon_arr = operations.map {|op| op.output(OUTPUT).sample.properties.length}
    final_ave_amplicon_len = f_amplicon_arr.reduce(:+).to_f / f_amplicon_arr.size
    # Referance: https://www.ncbi.nlm.nih.gov/pubmed/28959292
    show do
      title "Setting Up Theromcycler"
      separator
      note "Go to an open thermocycler and select program: <b>#{SOE_THERMO_TEMPLATE}</b>"
      note "<b>Thermocycler Conditions</b>:"
      bullet "Pre-heat lid to 100#{DEGREES_C}"
      bullet "95#{DEGREES_C} for 1 minute"
      note "<b>10 Cycles of</b>:"
      bullet "95#{DEGREES_C} for 45 seconds"
      bullet "45#{DEGREES_C} for 1:30 min"
    #   bullet "#{oa_temp}#{DEGREES_C} for 15 seconds"
      bullet "68#{DEGREES_C} for 45 seconds"
      note "<b>25 Cycles of</b>:"
      bullet "95#{DEGREES_C} for 45 seconds"
      bullet "#{oa_temp}#{DEGREES_C} for 1 min"
      bullet "72#{DEGREES_C} for 1:30 minutes"
      note "<b>Final Extension</b>"
      bullet "72#{DEGREES_C} for #{((final_ave_amplicon_len * 45) / 60).ceil}:#{((final_ave_amplicon_len * 45) % 60).ceil} minutes"
      bullet "Hold at 4#{DEGREES_C}"
      check "Place prepped samples #{groupby_out_collection.map {|coll, ops| coll.id} } on the thermocycler"
    end
    groupby_out_collection.each {|coll, ops| coll.location = 'Thermocycler'}
  end

  # Guides tech to transfer samples from stripwell to microfuge tube for storage
  #
  # @params groupby_out_collection [hash] is a hash of operations grouped by the output collection
  def dna_mix_storage_transfer(groupby_out_collection)

    # Print out tube labels with the Brady labeler
    output_dna_mix_items = operations.map {|op| op.output(OUTPUT).item.id}.sort!
    show do
      title "Preparing Lables"
      separator
      check "Use the Brady Label machine to print out microfuge tube labels from: [#{output_dna_mix_items[0]} - #{output_dna_mix_items[-1]}]"
      output_dna_mix_items.each_slice(12).each {|items| note "#{items}"}
    end

    # Take samples from thermo and move to bench
    take operations.map {|op| op.output(OUTPUT_SW).item}, interactive: true
    operations.map {|op| op.output(OUTPUT_SW).item.location = "Bench"}

    # Transfer from sw well to output item id
    groupby_out_collection.each {|coll, ops|
      tab = [['Collection', 'Well', "Transfer #{TRANSFER_VOL}#{MICROLITERS} to", 'Output Item']]
      ops.each {|op|
        tab.push([op.output(OUTPUT_SW).collection.id, "#{op.output(OUTPUT_SW).column+1}", {content: "==>", check: true}, op.output(OUTPUT).item.id])
      }
      show do
        title "Transferring Amplified DNA Mix"
        separator
        check "Once the thermocycler has finished, gather previously labeled tubes."
        note "Next, follow the table below to transfer sample to the appropriate microfuge tube."
        table tab
      end
    }
  end
  
  def wait
    # Wait until thermocycler is finished
    show do
      title "Next Step..."
      separator
      check "Once thermocycler is finished, continue to the next step"
    end 
  end

  # Cleanup input items
  #
  # @params release_arr [array] is an array of items that are found in Aq
  def clean_up_inputs(release_arr)
    operations.store(opts = { interactive: true, method: 'boxes', errored: false, io: 'input' })
    release release_arr, interactive: true
    # operations.store
  end

  # Cleanup output items
  def clean_up_outputs()
    operations.store(interactive: true, method: 'boxes', errored: false, io: 'output')
    show do
      title "Cleaning Up"
      separator
      note "Return any remaining reagents used and clean bench"
    end
  end
end # class
