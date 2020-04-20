# SG
# 
# Resuspend Agilent library and enter DNA Library samples into inventory. 
# Assumes Oligo Pool Sample is defined and Oligo Pool Item has been created. 
# See Sample 17325: Parent Lib TEST for an example. Note Sample description.
#
# Notes: 
# 1) Resuspension - following Baker protocol - to 30ng/uL
# 2) Sample is created in Aquarium. 
class Protocol
    
    # I/O
    POOL="Oligo Pool"
    OUT_HIGH="Oligo Pool"
    OUT_LOW="Dilute Oligo Pool"
    
    # other - resuspension
    SPIN={qty: 2.4, units: "xg"}
    SPIN_TIME={qty: 1, units: "min"}
    WATER={units: "µL", name: "MG Water"}
    WAIT={qty: 30 , units: "min"}
    DNA_NG_PER_NT_PER_PICOMOLE=0.325 # libraries are ssDNA, ng/pmole
    TARGET_CONC_NG_PER_UL=30.0 # ng/uL
    DEFAULT_PMOLE=10.0
    # dilution
    LOW_CONC_NG_PER_UL=2.5 # ng/uL
    TUBE="1.5mL microcentrifuge tube"
    DILUTION_VOL={qty: 44, units: "µL"} 
    
    # other - DNA Library stuff
    MIN_LENGTH="min length (nt) (array)"
    MAX_LENGTH="max length (nt) (array)"
    VARIANTS="variants (array)"
    NAMES="sublibrary name (array)"
    PROJECT="Library Cloning"
    OLIGO_POOL="Oligo Pool"
    DNA_LIB="DNA Library" # Sample name
    OLIGO_POOL="Oligo Pool" # what the lyopholized pools are called in show blocks

    def main
        
        # make Resuspended Library items
        operations.make
        
        # get quantities before resuspending
        operations.each { |op| op.temporary[:pmole] = op.input(POOL).item.get(:pmole) }
        no_pmole=operations.select { |op| op.temporary[:pmole].nil? }
        if(no_pmole.any?)
            data = show {
                title "Verify Lyopholized #{OLIGO_POOL} Quantities"
                note "The following libraries have no parameters specified. Please enter manually:"
                table no_pmole.start_table
                    .input_item(POOL)
                    .get(:pmole, type: 'number', heading: "Quantity (pmole)", default: DEFAULT_PMOLE) 
                    .end_table
            }
        end
        operations.each { |op| 
            op.input(POOL).item.associate :pmole, op.temporary[:pmole].to_f 
            op.output(OUT_HIGH).item.associate :concentration, TARGET_CONC_NG_PER_UL
            op.output(OUT_LOW).item.associate :concentration, LOW_CONC_NG_PER_UL
        }
        
        # get sublib parameters
        operations.each { |op|
            min_tot=op.input(POOL).item.sample.properties.fetch(MIN_LENGTH).map {|x| x.to_f}.sum
            max_tot=op.input(POOL).item.sample.properties.fetch(MAX_LENGTH).map {|x| x.to_f}.sum
            variants_tot=op.input(POOL).item.sample.properties.fetch(VARIANTS).map {|x| x.to_f}.sum
            num_sublibs=op.input(POOL).item.sample.properties.fetch(MIN_LENGTH).length
            op.temporary[:variants]=variants_tot
            op.temporary[:length]=(0.5*(max_tot+min_tot)/num_sublibs).round
            op.temporary[:sublibs]=num_sublibs
        }
        
        # show user the info for the library BEFORE resuspending
        show {
            title "Check #{OLIGO_POOL} Parameters before resuspension"
            table operations.start_table
                .input_item(POOL)
                .custom_column(heading: "Oligo Pool name") { |op| op.input(POOL).item.sample.name }
                .custom_column(heading: "Oligo Library ID") { |op| op.input(POOL).item.sample.properties.fetch("Oligo Library ID") }
                .custom_column(heading: "mean length (nt)") { |op| op.temporary[:length] }
                .custom_column(heading: "variants") { |op| op.temporary[:variants] }
                .custom_column(heading: "number of sublibraries") { |op| op.temporary[:sublibs] }
                .custom_column(heading: "quantity (pmole)") { |op| {content: op.temporary[:pmole], check: true} }
                .end_table
            warning "Quantity (pmole) determines the resuspension volume!"
        }
    
        # resuspend
        show {
            title "Resuspend Lyopholized #{OLIGO_POOL}s"
            check "Spin down all lyopholized oligo pools at #{SPIN[:qty]} #{SPIN[:units]} for #{SPIN_TIME[:qty]} #{SPIN_TIME[:units]}"
            note "Add #{WATER[:name]} from a <b>NEW</b> aliquot directly to the lyopholized oligo pool, according to the following:"
            table operations.start_table
                .input_item(POOL)
                .custom_column(heading: "Oligo Pool name") { |op| op.input(POOL).item.sample.name }
                .custom_column(heading: "Oligo Library ID") { |op| op.input(POOL).item.sample.properties.fetch("Oligo Library ID") }
                .custom_column(heading: "#{WATER[:name]} (#{WATER[:units]})") { |op| 
                    (op.input(POOL).item.get(:pmole).to_f*op.temporary[:length]*DNA_NG_PER_NT_PER_PICOMOLE/TARGET_CONC_NG_PER_UL).round(2) }
                .output_item(OUT_HIGH) 
                .end_table
            check "Vortex well and spin down"
            check "Leave on bench for #{WAIT[:qty]} #{WAIT[:units]}"
            check "Vortex well and spin down"
            check "Relabel original tubes, without covering any manufacturer information, according to the final column of the table (above)."
        }
        
        # dilute
        fac=(TARGET_CONC_NG_PER_UL.to_f/LOW_CONC_NG_PER_UL)-1
        lib_volume=(DILUTION_VOL[:qty].to_f/fac).round(2)
        show {
            title "Dilute Resuspended #{OLIGO_POOL}s"
            check "Label #{operations.length} #{TUBE}s: #{operations.map{ |op| op.output(OUT_LOW).item}.to_sentence}"
            note "Add #{WATER[:name]} and resuspended library volumes according to the following:"
            table operations.start_table
                .output_item(OUT_LOW)
                .custom_column(heading: "#{WATER[:name]} (#{WATER[:units]})") { |op| {content: DILUTION_VOL[:qty], check: true} }
                .custom_column(heading: "Resuspended Oligo Pool") { |op| "#{op.output(OUT_HIGH).item}" }
                .custom_column(heading: "Oligo Pool volume (#{DILUTION_VOL[:units]})") { |op| {content: lib_volume, check: true} }
                .end_table
            check "Vortex #{TUBE}s  #{operations.map{ |op| op.output(OUT_LOW).item}.to_sentence} and spin down"
        }
        
        # create sublibraries (DNA Library **Samples**)
        tab=[]
        tab[0]=["#{OLIGO_POOL}","#{DNA_LIB}"]
        ind=1
        operations.each { |op| 
            props=op.input(POOL).item.sample.properties
            props.fetch(NAMES).each_with_index { |name, i|
                s=Sample.find_by_name(name) # check if already created
                if(s.nil?) # create if needed
                    create_DNA_Library(name, "created #{Time.zone.now.to_date}", PROJECT, op.plan.user.id)
                    check = Sample.find_by_name(name) # check if valid Sample 
                    if(check.nil?) # no valid Sample created
                        show { note "Problem creating Sample #{name}, please check!"} 
                    else
                        tab[ind]=[op.input(POOL).item.sample.name, name]
                        ind=ind+1
                    end
                else
                    show { note "Sample #{name} already exists, please check!"} 
                end
            }
        }
        if(ind > 1) # have new Samples to display 
            show {
                title "DNA Library Samples Created"
                note "The following #{DNA_LIB} Samples were created for the #{OLIGO_POOL}s:"
                table tab
                note "Please check that no DNA Library Samples are missing!"
            }
        end
            
        # delete lyopholized stuff
        operations.each { |op| 
            op.input(POOL).item.mark_as_deleted
        }
        
        # store resuspended stuff 
        operations.store
    
        return {}
        
    end
    
    #-----------------------------------------------------------------------------
    
    # returns id of new sample type, else nil
    def create_DNA_Library(nameStr, descriptionStr, projectStr, user_id)
        s = Sample.creator(
            {   sample_type_id: SampleType.find_by_name(DNA_LIB).id,
                description: descriptionStr,
                name: nameStr, 
                project: projectStr
            }, User.find(user_id)
        )
    end

end
