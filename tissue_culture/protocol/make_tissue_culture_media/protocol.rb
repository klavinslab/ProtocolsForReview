# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol
  OUTPUT = "New Media"
  BASE = "Base media"
  ADDITIVES = "Additives"
  ADD_VOLS = "Additive Volumes"
  INPUT = "Base media"

  def main

    operations.retrieve


    operations.running.each do |op|
      basemedia = op.input(INPUT).item
      basemedia_container = ObjectType.find_by_id(basemedia.object_type_id)
      additive_samples = op.output(OUTPUT).sample.properties[ADDITIVES]

      additive_percentage = op.output(OUTPUT).sample.properties[ADD_VOLS]
      basemedia_vol = basemedia.get(:volume) || JSON.parse(op.input(INPUT).object_type.data)["volume"]
      if not basemedia.get(:volume)
        basemedia.associate :volume, basemedia_vol
      end

      additive_vol = additive_percentage.map { |p| p * basemedia_vol }
      # if additive_samples != additive_percentage
      #     op.error :sample_definition_error, "Tissue Culture Media #{op.output(OUTPUT).sample} was defined incorrectly. Additive volumes and Additives must have same lengths."
      # end

      op.temporary[:additives] = additive_samples
      op.temporary[:additive_vol] = additive_vol
      op.temporary[:additive_hash] = additive_samples.zip(additive_vol).to_h
      op.temporary[:basemedia_vol] = basemedia_vol
    end

    arr = operations.running.map { |op| op.temporary[:additive_hash] }
    tot_add_hash = arr.inject { |a, b| a.merge(b) { |_, x, y| x + y } }
    tot_add_hash.delete("")

    show do
      title "Gather items"

      check "Gather each of the following items"
      check "Sterilize items with 70% ethanol and place in hood"

      note "<b>Media</b>"
      table operations.running.start_table
                .input_item(INPUT)
                .custom_column(heading: "Media Name") { |op| op.input(INPUT).sample.name }
                .custom_column(heading: "Location") { |op| op.input(INPUT).item.location }
                .end_table
      separator
      note "<b>Additives</b>"
      t = Table.new
      samples = tot_add_hash.keys
      vols = samples.map { |n| tot_add_hash[n] }
      t.add_column("Additive", samples.map { |n| n })
      t.add_column("Req Volume", vols.map { |v| "#{v} mLs" })
      table t
    end

    operations.running.make

    if debug
      show do
        operations.each do |op|
          note "#{op.temporary}"
        end
      end
    end

    operations.running.each do |op|
      show do
        title "Make #{op.output(OUTPUT).sample.name}"

        check "Base Media: #{op.input(INPUT).sample.name} #{op.input(INPUT).item}"
        separator
        check "Label Media bottle: #{op.output(OUTPUT).sample.name} #{op.output(OUTPUT).item.id} #{Time.now.strftime("%m/%d/%y")}"
        separator
        note "Sterilly pipette the following into the base media:"

        samples, vols = op.temporary[:additive_hash].to_a.transpose
        if samples
          t = Table.new
          t.add_column("Additive", samples.map { |s| s })
          t.add_column("Vol (mL)", vols)
          table t
        end
      end
    end

    # operations.running.each do |op|
    #     show do
    #         title "Make #{op.output(OUTPUT).sample.name}"

    #         note "Spray each of the following items with ethanol and place in the hood."
    #         check "Base Media: #{op.input(INPUT).sample.name} #{op.input(INPUT).item.id}"

    #         separator

    #         note "Sterilly pipette the following into the media bottle."
    #         op.temporary(:add_samples).zip(op.temporary(:add_vol)).each do |s, v|
    #             check "#{s.name} #{v*basemedia.get(:volume)}mL"
    #         end
    #     end
    # end

    operations.running.each do |op|
      op.output(OUTPUT).item.associate :from, op.input(INPUT).item.id
      op.input(INPUT).item.mark_as_deleted
    end

    operations.running.store

    return {}

  end

end
