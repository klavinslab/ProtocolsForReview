MIN_PULSE_LENGTH = 3.0 # (ms) minimum allowed electroporation pulse length
MAX_PULSE_LENGTH = 1000 # (ms) maximum allowed electroporation pulse length

EM_VOL_RATIO = 2.2 # ratio of DI water to Hydra Medium by volume in electroporation medium
EM_VOL_PER_CM = 2000 # (uL/cm) volume of electroporation medium to add to cuvette by size

needs "Hydra Husbandry/UnverifiedHydra"

class Protocol
    
  include UnverifiedHydra
  
  def main
    
    operations.retrieve(interactive: false)
    
    default_concentrations() if debug # DEBUGGING
    
    calculate_volumes()
    
    debug_info() if debug # DEBUGGING
    
    chill_hydra() # retrieve the hydra and place them in the incubator for an hour
    prep_hydra() # bathe hydra in 1xPBS solution
    get_ice() # while the hydra chills, get a bucket of ice
    
    prep_em_reagents() # prepare electroporation medium reagents
    operations.each{|op| make_em(op)} # make electroporation medium
    
    # run the electroporations
    operations.each.with_index do |op|
      
      article = op.temporary[:num_cuvettes] > 1 ? "each" : "the"
      
      pulse = electroporation_test(op) # perform an initial test pulse
      # if the test pulse length is out of range, remake the electroporation medium and try again
      # if the test pulse length is still out of range, then error the operation
      if (pulse < MIN_PULSE_LENGTH || pulse > MAX_PULSE_LENGTH)
        remake_em(op, pulse)
        pulse = electroporation_test(op)
        abort_op(op, pulse) if (pulse < MIN_PULSE_LENGTH || pulse > MAX_PULSE_LENGTH)
      end
      
      # if the test passes, then perform the electroporation and record the pulse length
      if op.status != "error"
        electro_prep(op, article)
        electroporate(op, article)
      end
    end
    
    cleanup()
    
    return {}
    
  end
  
  def default_concentrations()
    # set dummy concentrations for plasmids when debugging
    operations.each do |op|
      op.input("Plasmid").item.associate(:concentration, 800 + rand(400))
      complexes = op.input_array("Cas9::sgRNA").items.select{|i| i.sample.name != '[NONE]'}
      complexes.each{|c| c.associate(:concentration, 1.0 + rand(3.0))}
    end if debug
  end
  
  def calculate_volumes()
    # electro_medium_ratio = 2.2 # ratio of DI water to Hydra Medium by volume in electroporation medium
    # em_vol_per_cm = 2000 # (uL/cm) volume of electroporation medium to add to cuvette by size
    
    # calculate volumes of electroporation medium reagents for each operation
    operations.each.with_index do |op, i|
      num_hydra = op.input("Number of Hydra").val.round
      num_cuvettes = num_hydra <= 5 ? 1 : ((num_hydra + 2) / 5).ceil
      op.temporary[:num_cuvettes] = num_cuvettes
      op.temporary[:num] = i + 1
      op.temporary[:label] = "EM" + (operations.length > 1 ? " " + op.temporary[:num].to_s : "")
      
      # calculate total volume of electroporation medium per pulse
      em_vol_per_cuvette = op.input("Electroporation Media per Cuvette (ul)").val # (uL)
      op.temporary[:em_vol] = (em_vol_per_cuvette * (num_cuvettes)).round # (uL)
      op.temporary[:em_vol_per_cuvette] = em_vol_per_cuvette
      
      # calculate volume of plasmid per pulse
      plas_mass = op.input("Mass of Plasmid (ug)").val # (ug)
      plas_concentration = op.input_data("Plasmid", :concentration).to_f # (ng / uL)
      plas_vol_per_cuvette = (plas_mass * 1000 / plas_concentration).round(3) # (uL)
      op.temporary[:plas_vol] = (plas_vol_per_cuvette * (num_cuvettes)).round # (uL)
      
      # calculate volume of cas9 per pulse
      # TODO: support array input
      complexes = op.input_array("Cas9::sgRNA").items.select{|i| i.sample.name != '[NONE]'}
      cas9_mass = op.input("Mass of Cas9::sgRNA Complex (ug)").val # (ug)
      mass_per_cas9 = cas9_mass / complexes.size
      cas9_vols_per_cuvette = {} # map from each cas9 item to its corresponding volume per pulse
      complexes.each do |cas9|
        cas9_conc = cas9.associations[:concentration].to_f # ug / uL
        cas9_vol = mass_per_cas9 / cas9_conc # uL
        cas9_vols_per_cuvette[cas9] = cas9_vol.round(3)
      end
      
      cas9_vol_per_cuvette = cas9_vols_per_cuvette.values.sum # (uL) total volume of cas9 per pulse
      cas9_vols = {}
      cas9_vols_per_cuvette.each do |cas9, vol|
        cas9_vols[cas9] = (vol * (num_cuvettes)).round(3)
      end
      op.temporary[:cas9_vols] = cas9_vols # (uL)
      
      # calculate volume of hydra medium per pulse (this depends on whether salmon sperm is used)
      if op.input("Salmon Sperm (ul)").val == 0 
        hm_vol_per_cuvette = (em_vol_per_cuvette / (EM_VOL_RATIO + 1) - cas9_vol_per_cuvette).round(3) # (uL)
        op.temporary[:hm_vol] = (hm_vol_per_cuvette * (num_cuvettes)).round # (uL)
        ss_vol_per_cuvette = 0
        op.temporary[:ss_vol] = (ss_vol_per_cuvette * (num_cuvettes)).round
      else
        hm_vol_per_cuvette = 0
        op.temporary[:hm_vol] = (hm_vol_per_cuvette * (num_cuvettes)).round # (uL)
        ss_vol_per_cuvette = op.input("Salmon Sperm (ul)").val
        op.temporary[:ss_vol] = (ss_vol_per_cuvette * (num_cuvettes)).round
      end
      
      # calculate volume of DI water per pulse
      h2o_vol_per_cuvette = (em_vol_per_cuvette / (1 / EM_VOL_RATIO + 1) - plas_vol_per_cuvette).round(3) # (uL)
      op.temporary[:h2o_vol] = (h2o_vol_per_cuvette * (num_cuvettes)).round # (uL)
      
    end
  end
  
  def debug_info()
    # show calculated volumes when debugging
    show do
      title "DEBUGGING" # DEBUG
      
      note "Number of Hydra: " + operations.map{|op| op.input("Number of Hydra").val}.to_s
      note "Cuvette Size (cm): " + operations.map{|op| op.input("Cuvette Size (cm)").val}.to_s
      note "Mass of Plasmid (ug): " + operations.map{|op| op.input("Mass of Plasmid (ug)").val}.to_s
      note "Voltage (V): " + operations.map{|op| op.input("Voltage (V)").val}.to_s
      note "Number of Pulses: " + operations.map{|op| op.input("Number of Pulses").val}.to_s
      operations.each{|op| note "op#{op.id}.temporary = #{op.temporary.to_s}"}
    end
  end
  
  def chill_hydra()
    operations.each do |op|
      show do
        title "Chill Hydra (#{op.temporary[:num].to_s + " of " + operations.length.to_s})"
        
        check "Fill a 25 mL dish halfway with 20% dissociation medium"
        check "Get #{op.input("Hydra").object_type.name} #{op.input("Hydra").item.id} from #{op.input("Hydra").item.location}"
        check "Transfer #{op.input("Number of Hydra").val.round} hydra into the 25 mL dish"
        check "Return #{op.input("Hydra").object_type.name} #{op.input("Hydra").item.id} to #{op.input("Hydra").item.location}"
        check "Cover the dish and label it as \"#{op.id}\""
        check "Place the dish in the 4C incubator"
      end
    end
    
    show do
      title "Chill Out"
      
      note "Wait for 1 hour before proceeding"
      timer initial: { hours: 1, minutes: 0, seconds: 0}
      note "While you wait..."
      check "Get a bucket of ice"
      check "Get #{operations.map{|op| op.temporary[:num_cuvettes]}.sum} chilled cuvettes from B1165 and place them in the ice"
    end
  end
  
  def prep_hydra()
    # prepare the hydra for electroporation
    operations.each do |op|
      show do
        title "Prep Hydra (#{op.temporary[:num].to_s + " of " + operations.length.to_s})"
        
        note "Get the 300 µm hydra filter, collection beaker, and 1xPBS solution" if op.temporary[:num] == 1
        note "Remove the dish labeled #{op.id} from the 4C incubator"
        note "Pour the dish's contents through the filter into the collection beaker"
        note "Repeat the following 6 times:"
        table [(1..6).map{|i| {content: i, check: true}}]
        bullet "Add enough Hydra Medium to cover the hydra"
        bullet "Carefully swirl the liquid in the dish 10 times"
        bullet "Pour the dish's contents through the filter into the beaker"
        bullet "Retrieve any hydra stuck in the filter"
        note "Pour 15 mL of chilled 1xPBS into the dish"
        note "Write the current time on the dish (#{Time.now.strftime("%I:%M %p")})"
        note "Place the dish in the 4C incubator"
      end
    end
  end
  
  def get_ice()
    show do
      title "Get some ice"
      
      note "Let the Hydra chill out for 15 minutes"
      timer initial: { hours: 0, minutes: 15, seconds: 0}
      note "Get all three sizes of pipette and electroporator E1"
    end
  end
  
  def prep_em_reagents()
    show do
      title "Prepare Electroporation Medium Reagents"
      
      oversized = operations.select{|op| op.temporary[:em_vol] >= 1500}.length
      oversized += 1 if operations.map{|op| op.temporary[:hm_vol]}.sum > 1500
      oversized += 1 if operations.map{|op| op.temporary[:h2o_vol]}.sum > 1500
      note "Get #{operations.length + 2 - oversized} 1.5 mL Eppendorf tubes"
      note "Get #{oversized} large Eppendorf tubes" if oversized > 0
      complexes = operations.map{|op| op.input("Cas9::sgRNA").item}.uniq
    #   note "Get Cas9 #{'item'.pluralize(complexes.size)} #{complexes.map{|c| c.id}.join(', ')}"
      note "Get the following cas9 #{'complex'.pluralize(complexes.length)}:" if complexes.size > 0
      complexes.each {|complex| bullet complex.id.to_s + " from " + complex.location.to_s}
      plasmids = operations.map{|op| op.input("Plasmid").item}
      note "Get the following #{'plasmid'.pluralize(plasmids.length)}:"
      plasmids.each {|plas| bullet plas.id.to_s + " from " + plas.location.to_s}
      total_h2o_vol = (operations.sum{|op| op.temporary[:h2o_vol]} * 1.1).round
      check "Add #{total_h2o_vol} uL of DI water to a #{total_h2o_vol > 1500 ? 'large' : '1.5 ml'} Epp tube and label it \"DI\""
      total_hm_vol = (operations.sum{|op| op.temporary[:hm_vol]} * 1.1).round
      check "Add #{total_hm_vol} uL of Hydra Medium to a #{total_hm_vol > 1500 ? 'large' : '1.5 ml'} Epp tube and label it \"HM\""
      total_ss_vol = (operations.sum{|op| op.temporary[:ss_vol]} * 1.1).round
      check "Add #{total_ss_vol} ul of Salmon Sperm DNA to a #{total_ss_vol > 1500 ? 'large' : '1.5 ml'} Epp tube and label it \"SS\""
    end
  end
  
  def make_em(op)
    # make electroporation medium stocks for each operation
    show do
      title "Make Electroporation Medium (#{op.temporary[:num].to_s + " of " + operations.length.to_s})"
      
      note "Label a #{op.temporary[:em_vol] >= 1500 ? 'large' : '1.5 ml'} Epp tube as #{op.temporary[:label]}"
      check "Add #{op.temporary[:plas_vol]} uL of Plasmid #{op.input("Plasmid").item.id}"
      op.temporary[:cas9_vols].each do |cas9, vol|
        check "Add #{vol} uL of Cas9::sgRNA Complex #{cas9.id}"
      end
      check "Add #{op.temporary[:h2o_vol]} uL from the DI tube"
      check "Add #{op.temporary[:hm_vol]} uL from the HM tube"
      check "Add #{op.temporary[:ss_vol]} uL from the SS tube"
      
    end
  end
  
  def electroporation_test(op)
      data = show do
        title "Electroporation Test (#{op.temporary[:num].to_s + " of " + operations.length.to_s})"
        
        note "Pipette #{op.temporary[:em_vol_per_cuvette]} uL of electroporation medium from #{op.temporary[:label]} into an empty cuvette"
        note "Set the electroporation voltage to #{op.input("Voltage (V)").val} V"
        note "Place the cuvette in the electroporator"
        note "Press the pulse button twice (you should hear a beep)"
        note "Press the 'time constant' button"
        get "number", var: "pulse", label: "Record the pulse length in ms", default: debug ? (op.temporary[:num] == 2 ? 1 : 5) : nil
        note "Pipette the electroporation medium from the cuvette back into the #{op.temporary[:label]} stock"
      end
      return data[:pulse]
  end
  
  def remake_em(op, pulse)
    show do
      title "Remake Electroporation Medium #{op.temporary[:num]}"
      
      warning "The pulse length of #{pulse} ms is not between #{MIN_PULSE_LENGTH} ms and #{MAX_PULSE_LENGTH} ms"
      note "Toss the test cuvette into the biohazard rubbish and get a new one"
      note "Toss the stock #{op.temporary[:label]} into the biohazard rubbish"
      note "Label a clean #{op.temporary[:em_vol] >= 1500 ? 'large' : '1.5 ml'} Epp tube as #{op.temporary[:label]}"
      check "Add #{op.temporary[:plas_vol]} uL of Plasmid #{op.input("Plasmid").item.id}"
      op.temporary[:cas9_vols].each do |cas9, vol|
        check "Add #{vol} uL of Cas9::sgRNA Complex #{cas9.id}"
      end
      check "Add #{op.temporary[:h2o_vol]} uL from the DI tube"
      check "Add #{op.temporary[:hm_vol]} uL from the HM tube"
    end
  end
  
  def abort_op(op, pulse)
    op.error :bad_pulse_length, "Pulse length of #{pulse} ms not between #{MIN_PULSE_LENGTH} ms and #{MAX_PULSE_LENGTH} ms" 
    show do
      title "Uh oh..."
      
      warning "The pulse length of #{pulse} ms is still not between #{MIN_PULSE_LENGTH} ms and #{MAX_PULSE_LENGTH} ms"
      note "This operation is canceled"
      note "Get #{op.input("Hydra").object_type.name} #{op.input("Hydra").item.id} from #{op.input("Hydra").item.location}"
      note "Remove the dish labeled #{op.id} from the 4C incubator"
      note "Carefully pipette all of the hydra back to where they came from"
      note "Return #{op.input("Hydra").object_type.name} #{op.input("Hydra").item.id} to #{op.input("Hydra").item.location}"
    end
  end
  
  def electro_prep(op, article)
    # run the electroporation and record the results
    show do
      title "Electroporation Prep (#{op.temporary[:num].to_s + " of " + operations.length.to_s})"
      
      num_cuvettes = op.temporary[:num_cuvettes]
      check "Get #{num_cuvettes} 1.5 mL Epp #{'tube'.pluralize(num_cuvettes)} and place them in the ice"
      check "Remove the dish labeled #{op.id} from the incubator"
      check "Repeat the following two times:"
      bullet "Pour the contents of the dish through the filter into the collection beaker"
      bullet "Use DI to rins e the Hydra stuck in the filter back into the dish"
      check "Pipette about 5 hydra into #{article} Epp tube"
      warning "Make sure the hydra are at the bottom of the tube"
      check "Pipette the DI H2O from #{article} tube into the collection beaker, leaving just Hydra in the tube"
      check "Pipette #{op.temporary[:em_vol_per_cuvette]} ul of electroporation medium from #{op.temporary[:label]} into #{article} tube with hydra"
      check "Pipette the hydra and electroporation medium from #{article} tube into an empty cuvette"
      warning "Make sure the hydra are between the electrodes"
    end
  end
  
  def electroporate(op, article)
    num_cuvettes = op.temporary[:num_cuvettes]
    # associate electroporation parameters with each item
    items = (1..num_cuvettes).map do |i|
    #   item = op.output("Hydra").sample.make_item "Unverified Hydra Well"   
      item = new_uvhw(op.output("Hydra").sample)
      plate = store_uvhw(item)
      gap_size = op.input("Cuvette Size (cm)").val # (cm)
      field_strength = op.input("Voltage (V)").val / 1000 / gap_size # (kV/cm)
      item.associate(:gap_size, gap_size)
          .associate(:last_electroporated, Time.now.to_f) # TODO don't delete 3 days
          .associate(:field_strength, field_strength)
          .associate(:voltage, op.input("Voltage (V)").val)
          .associate(:mass_dna, op.input("Mass of Plasmid (ug)").val)
          .associate(:parent_sample, op.input("Hydra").sample) # TODO associate with sample rather than item?
          .associate(:plasmid, op.input("Plasmid").sample) # TODO associate with sample rather than item?
      item.save
      item.store
      [item, plate]
    end
    
    show do
      title "Electroporation (#{op.temporary[:num].to_s + " of " + operations.length.to_s})"
      
      note "For each cuvette with hydra, do the following:"
      bullet "Place #{article} cuvette in the electroporator"
      bullet "Set the electroporation voltage to #{op.input("Voltage (V)").val} V"
      bullet "Press the pulse button twice, wait for a beep, then press the time constant button"
      bullet "Record the time constant in the table below"
      bullet "Fill the well shown in the table with Hydra Medium"
      bullet "Pipette the hydra from the cuvette to the well and label as shown"
      bullet "Toss the cuvette into the biohazard rubbish"
      warning "If 5 pulse lengths in a row are below #{MIN_PULSE_LENGTH} ms or above #{MAX_PULSE_LENGTH} ms, remake the electroporation medium" if num_cuvettes >= 5
      io_table = Table.new
      io_table.add_column("Cuvette", (1..num_cuvettes).map{|i| {content: i, check: true}})
      io_table.add_column("Pulse Length (ms)", (1..num_cuvettes).map{|i| {type: 'number', key: "pulse#{i}", operation_id: op.id, default: debug ? 5 : nil}})
      io_table.add_column("Plate", items.map{|item, plate| plate.id})
      io_table.add_column("Well", items.map{|item, plate| name_of_uvhw(item)})
      io_table.add_column("Label", items.map{|item, plate| item.id})
      table io_table
    end
    
    # associate pulse length with each item
    items.each.with_index do |item, i|
      item[0].associate(:pulse_length, op.temporary["pulse#{i + 1}".to_sym]).save
    end
  end
  
  def cleanup()
    show do
      title "Clean Up"
      
      note "Empty the collection beaker into the liquid waste container, rinse it with water, and place it in the drying rack"
      note "Put away the electroporator and micropipettes"
      note "Put the plasmids back at their original locations:"
      plasmids = operations.map{|op| op.input("Plasmid")}.uniq
      plas_table = Table.new
      plas_table.add_column("Plasmid", plasmids.map{|p| p.sample.id})
      plas_table.add_column("Location", plasmids.map{|p| p.item.location})
      table plas_table
      note "Check with lab manager to see if anyone else needs ice"
    end
  end
end