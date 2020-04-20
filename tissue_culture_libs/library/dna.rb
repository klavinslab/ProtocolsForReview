# Volume checking show blocks
category = "Tissue Culture Libs"
needs "#{category}/ManagerHelper"
needs "#{category}/TemporaryExtensions"

module VolumeChecker
  include ManagerHelper
  include TemporaryExtensions

  # Add concentration column to table
  def add_concentration_column ops
    ops.custom_input(:concentration, type: "number", heading: "Concentration (ng/ul)") { |op|
      c = op.temporary[:concentration] || op.temporary[:item].get(:concentration).to_f
      c = rand(10..600) if debug and c == 0.0
      c ||= rand(10..600) if debug
      c ||= 10
      c
    }
        .validate(:concentration) { |op, v| v > 0 }
        .validation_message(:concentration) { |op, k, v| "Concentration #{v} is invalid. Concentration \
                for #{op.temporary[:item]} must be greater than 0!" }
  end

  # Add contamination (y/n) column to table
  def add_contamination_column ops
    ops.custom_boolean(:contamination, heading: "Contamination?") { |op|
      c = op.temporary[:contamination] || op.temporary[:item].get(:contamination)
      c ||= "n"
      c
    }
  end

  # Add volume column to table
  def add_volume_column ops, unit, min=0, max=2000
        ops.custom_input(:volume, type: "number", heading: "Volume (#{unit})") { |op|
          v = op.temporary[:volume] || op.temporary[:item].get(:volume).to_f
          v = rand(0..100) if debug and v == 0
          v ||= rand(0..100) if debug
          v ||= 10
          v
        }
        .validate(:volume) { |op, v| v.between?(min, max) }
        .validation_message(:volume) { |op, k, v| "Volume #{v} is invalid. \
            Volume for #{op.temporary[:item]} must be between #{min} and #{max}!" }
  end

  # Base table with basic sample and item info
  def base_table ops
    ops.start_table
        .custom_column(heading: "Sample") { |op| op.temporary[:item].sample.name }
        .custom_column(heading: "Item") { |op| op.temporary[:item].id }
  end

  # Instructs technician to check the concentrations of each item
  def check_volumes items, options={with_contamination: true, unit: "uL", min: 0, max: 2000}
    opts = {with_contamination: true, unit: "uL", min: 0, max: 2000}
    opts.merge!(options)
    return if items.empty?
    with_contamination = opts[:with_contamination]
    items = items.uniq
    items.each { |i| i.associate :volume, i.get(:volume).to_f }
    return nil if items.empty?
    vops = items_to_vops items

    concentration_table = Proc.new { |ops|
      base_table(ops)
      add_volume_column(ops, opts[:unit], opts[:min], opts[:max])
      add_contamination_column(ops) if with_contamination
      ops.end_table.all
    }

    show_with_input_table(vops, concentration_table) do
      title "Estimate volumes"
      check "Roughly estimate the volumes for each item"
      check "Note any contamination" if with_contamination
    end

    vops.each do |op|
      op.temporary[:item].associate :volume, op.temporary[:volume]
      if with_contamination 
        op.temporary[:item].associate :contamination, op.temporary[:contamination] if not op.temporary[:contamination] == ""
      end
    end

    destory_virtual_operations

  end

  # Instructs technician to check the concentrations of each item
  def check_concentrations items, all_items=false
    items.each { |i| i.associate :concentration, i.get(:concentration).to_f }
    items = items.uniq
    items.select! { |i| !i.get(:concentration) or i.get(:concentration) == 0.0 } if not all_items
    return nil if items.empty?
    vops = items_to_vops items

    concentration_table = Proc.new { |ops|
      base_table(ops)
      add_concentration_column(ops)
      ops.end_table.all
    }

    show_with_input_table(vops, concentration_table) do
      title "Measure concentrations"

      check "Go to the nanodrop and measure the concentration of each item"
    end

    vops.each do |op|
      op.temporary[:item].associate :concentration, op.temporary[:concentration]
    end

    destory_virtual_operations
  end
end

module DNA
  include VolumeChecker

  def validate_lengths ops, min_length=nil, max_length=nil, &dna_block
    mn = min_length || 0
    mx = max_length || 1e6
    ops.each do |op|
      dnas = yield(op)
      dnas = [dnas].flatten
      #   dnas ||= op.input_array(fv_name).each { |fv| fv.item }
      dnas.each do |dna|
        l = dna.sample.properties["Length"].to_f
        if not (mn < l and l <= mx)
          error_key = "length_not_defined_for_#{dna.sample.id}".to_sym
          identifier = "#{dna.sample.name} (#{dna.sample.id})"
          error_message = "DNA length for #{identifier} was either not defined or is 0."
          error_message += " Length must be between #{mn} and #{mx}." if min_length or max_length
          # identifier = "#{dna.sample.name} (#{dna.sample.id})"
          op.error error_key, error_message
        end
      end
    end
  end

  def fmol_per_ul dna_item
    l = dna_item.sample.properties["Length"].to_i
    if l == 0.0
      return nil
    end
    return nil if not dna_item.get(:concentration)
    ug = dna_item.get(:concentration) / 1000.0
    ug_to_pmol(ug, l) * 1000.0
  end

  def ug_to_pmol(ug, length)
    ug.to_f / (length.to_f * 660 * 10**-6)
  end

  def pmol_to_ug(pmol, length)
    pmol.to_f * length.to_f * 660 * 10**-6
  end
end #module