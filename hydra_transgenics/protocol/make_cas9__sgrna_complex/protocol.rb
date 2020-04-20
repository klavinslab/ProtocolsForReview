CAS9_CONCENTRATION = 3.0 # ug / uL
CAS9_2_RNA_RATIO = 5.0 # by mass

class Protocol
  
  def main
    
    operations.retrieve.make #lists all of the plans of the same type and make holds a stub for a new item number creates a new output
    
    default_concentrations() if debug # DEBUGGING used for test tab not production
    
    show do
      title "Gather the following"
      
      num_tubes = operations.size # how many different operations are batched 
      note num_tubes == 1 ? "One PCR tube" : "#{num_tubes} PCR tubes" 
      note "10ul pipette tips"
    end
    
    operations.each.with_index do |op, i|
      
      calculations(op)
      
      prepare_reaction(op, i)
      
      op.output("Cas9::sgRNA Complex").item.associate(:concentration, op.temporary[:concentration])
      op.output("Cas9::sgRNA Complex").item.location = "H4 Refrigerator"
    end
    
    show do
      title "Thermocycle"
      
      note "Set the thermocycler to 5 mins at 37C"
      note "Place the PCR #{"tube".pluralize(operations.size)} into the termocycler, close lid and press start"
      note "When the thermocycle finishes put the PCR #{"tube".pluralize(operations.size)} in 4C"
    end
    
    operations.store()
    
    return {}

  end
  
  
  def default_concentrations()
    # set dummy concentrations for plasmids when debugging
    operations.each do |op|
      op.input_array("sgRNA").items.each do |i|
        i.associate(:concentration, 1000)
      end
    end if debug
  end
  
  def calculations(op)
    vol_total = op.input("Volume (uL)").val
    guides = op.input_array("sgRNA").items
    conversion = guides.size * CAS9_2_RNA_RATIO / CAS9_CONCENTRATION
    sum_of_inverse_conc = guides.sum{|i| 1000 / i.associations[:concentration].to_f} # ug / ul
    mass_per_sgrna = vol_total / (sum_of_inverse_conc + conversion)
    mass_sgrna = mass_per_sgrna * guides.size
    mass_cas9 = CAS9_2_RNA_RATIO * mass_sgrna
    
    vol_cas9 = (mass_cas9 / CAS9_CONCENTRATION).round(3)
    guide_vols = {}
    guides.each do |guide|
      guide_concentration = guide.associations[:concentration].to_f / 1000 # ug / uL
      guide_vol = (mass_per_sgrna / guide_concentration).round(3) # uL
      guide_vols[guide] = guide_vol
    end
    
    concentration = (mass_cas9 + mass_sgrna) / vol_total
    
    show do
      title "DEBUGGING INFORMATION"
      
      note "guides = #{guides}"
      note "guides.size = #{guides.size}"
      note "guides.associations = #{guides.map{|i| i.associations}}"
      note "guides.map{|i| i.associations['concentration'].to_f} = #{guides.map{|i| i.associations['concentration'].to_f}}"
      note "op.input('Volume (uL)').val = #{op.input("Volume (uL)").val}"
      note "conversion = #{conversion}"
      note "sum_of_inverse_conc = #{sum_of_inverse_conc}"
      note "vol_total = #{vol_total}"
      note "vol_cas9 = #{vol_cas9}"
      note "guide_vols = #{guide_vols}"
      note "mass of CAS9 = #{mass_cas9}"
      note "mass of sgRNA = #{mass_sgrna}"
      note "concentration = #{concentration}"
    end if debug
    
    op.temporary[:vol_total] = vol_total
    op.temporary[:vol_cas9] = vol_cas9
    op.temporary[:guide_vols] = guide_vols
    op.temporary[:concentration] = concentration
  end
  
  def prepare_reaction(op, i)
    show do
      title "Prepare Reaction (#{(i+1).to_s + " of " + operations.size.to_s})"
      
      note "Label an empty PCR Tube as #{op.output("Cas9::sgRNA Complex").item.id}:"
      note "Pippette the following reagents into the PCR tube:"
      check "#{op.temporary[:vol_cas9]} uL of Cas9"
      op.temporary[:guide_vols].each{ |sgrna, vol| check "#{vol} uL of sgRNA #{sgrna.id}" }
      note "Pipette the solution up and down 10 times to ensure proper mixing"
    end
  end


end

