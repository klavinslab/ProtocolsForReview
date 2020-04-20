needs "Cloning Libs/Calculations"

class Protocol
  include Calculations
  
  FWD = "Forward Primer"
  REV = "Reverse Primer"
  OUTPUT = "Fragment"
  
  def main
      

    show do 
        title "Retrieve required items"
        check "#{(operations.length.to_f/12.0).ceil} stripwells and lids"
        check "#{operations.length} 1.5mL eppendorfs in a rack"
        check "p10 pipette"
        check "p10 pipette tips"
        check "2.5M NaCL, in a 50 mL falcon tube, top shelf, opposite the large shaking incubators. If precipated vortex till all salt redissolved"
    end
    
    operations.retrieve.make
    
    #Add a fixed, easily referenced index to each operation.
    i = 1
    operations.each do |op|
        op.associate :index, i
        i = i + 1
    end
    
    show do
        title "label stripwell(s) and add salt"
        check "Label stripwell tubes from 1 to #{operations.length}"
        operations.each do |op|
            check "Add 0.4µl of 2.5M NaCl into well #{op.get(:index)}"
        end
    end
    
    operations.each do |op|
        op_index = op.get(:index)
        show do
            title "Add Oligos into well #{op_index}"
            warning "Do not cross contaminate oligonucleotide stocks. Fresh tips each time"
            check "Add 10µl of Oligo #{op.input(FWD).item} into well #{op_index}"
            check "Add 10µl of Oligo #{op.input(REV).item} into well #{op_index}"
        end
    end
    
    program = show do
        title "Mix Well"
        check "Vortex stripwell(s) for 5 seconds"
        check "Spin down for 5 seconds in tabletop centrifuge"
        note "Place stripwell in a rack and bring to the Thermocycler"
        note "Does the chosen Thermocycler have the program 'SLOWDOWN' available?"
        select ["Yes", "No"], var: "answer", label: "SLOWDOWN available?", default: 1
    end
    
    if program[:answer] == "No"
        show do 
            title "Program thermocycler"
            note "First check if the program is saved in the machine, under the name 'SLOWDOWN'"
            note "If not program in the following protocol and save as MAIN>SLOWDOWN"
            check "1. 95°C, 2 minutes"
            check "2. 94°C, 25 seconds"
            check "3. GOTO step 2, 70x, -1°C per cycle, ramp 0.1°C/second"
            check "4°C, infinite"
        end
    end
    
    show do 
        title "Incubate oligos"
        check "Place stripwells in an available Thermocycler"
        check "Run program 'FastUpSlowDown'"
        timer initial: { hours: 0, minutes: 45, seconds: 00}
        warning "Proceed to next steps"
    end
    
#   operations.store(io: "input", interactive: true)
    
    show do
        title "Label 1.5 mL tubes"
        note "These tubes will receive the annealed oligos"
        operations.each do |op|
            check "#{op.output("Fragment").item.id}"
        end
    end
    
    show do
        title "Return the NaCl solution"
        check "Return salt solution to the top shelf, above the label maker"
    end
    
    show do
        title "Once Timer Beeps retrieve stripwells and transfer to 1.5 mL tubes"
        check "Retrive stripwell(s) from the thermocycler"
        operations.each do |op|
            check "Transfer 20µl from well #{op.get(:index)} into tube #{op.output(OUTPUT).item.id}"
        end
    end
    
    needs_nanodrop, autocalculate = operations.partition { |op| 
        length = op.output(OUTPUT).sample.properties["Length"]
        ot1 = op.input(FWD).object_type.id
        ot2 = op.input(REV).object_type.id
        length.nil? or length == 0 or ot1 != ot2
    }
    
    if needs_nanodrop.any?
        cc = show do 
            title "Please nanodrop the Fragment stocks"
            needs_nanodrop.each do |op|
                note "#{op.output(OUTPUT).item.id}"
                get "number", var: "c#{op.output(OUTPUT).item.id}", label: "#{op.output(OUTPUT).item.id} item", default: 42
            end
        end
    
        operations.each do |op|
            op.output(OUTPUT).item.associate :concentration, cc["c#{op.id}".to_sym] 
        end
    end
    
    autocalculate.each do |op|
        length = op.output(OUTPUT).sample.properties["Length"]
        if debug
            length = 80
        end
        uL = 20 
        
        molarity = nil
        case op.input(FWD).object_type.name
        when "Primer Aliquot"
            molarity = 100.0 * 10**-6 / 2.0
        when "Primer Stock"
            molarity = 10.0 * 10**-6 / 2.0
        end
            
        moles = molarity * uL * 10**-6 # 1mM * 20uL
        ng = 10.0**9 * dsDNA_moles_to_mass(moles, length)
        conc = ng / uL
        op.output(OUTPUT).item.associate :concentration, conc
    end
    
    if debug
        show do
            title "Autocalculated concentrations"
            
            operations.each do |op|
                item = op.output(OUTPUT).item
                note "\"#{item.sample.name}\" #{item.sample.properties["Length"]} #{item.get(:concentration)} ng/uL"
            end
        end
    end
    
    operations.each do |op|
        op.output(OUTPUT).item.associate :volume, 20 
    end
    
    operations.store
    
    return {}
    
  end

end
