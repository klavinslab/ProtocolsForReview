# This protocol just mixes two DNAs in a certain ratio. Super simple.

needs "Cloning Libs/Calculations"
needs "Cloning Libs/Cloning"

class Protocol
    include Calculations
    include Cloning
    
    BB = "Backbone"
    INSERTS = "Inserts"
    RATIO = "Insert to backbone molar ratio"
    BB_MASS = "Amount of backbone (ng)"
    OUTPUT = "Plasmid"
    TOTAL_VOLUME = "Total Volume"
    
    def main
        operations.running.retrieve.make
        
        # needs_concentration = []
        
        # operations.running.each do |op|
        #     bb = op.input(BB).item
        #     inserts = op.input_array(INSERTS).map { |fv| fv.item }
        #     needs_concentration.append(bb) if bb.get(:concentration).to_f.nil?
        #     inserts.each do |insert|
        #         needs_concentration.append(insert) if insert.get(:concentration).to_f.nil?
        #     end
        # end
        
        check_concentration(operations, BB)
        check_concentration(operations, INSERTS)
        
        operations.each do |op|
            if op.input(BB).sample.properties["Length"].nil?
                op.error("Backbone #{op.input(BB).sample.id} #{op.input(BB).sample.name} needs a length!") 
            end
            op.input_array(INSERTS).each do |insert|
                if insert.sample.properties["Length"].nil?
                    op.error("Insert #{insert.sample.id} #{insert.sample.name} needs a length!")
                end
            end
        end
        
        if operations.empty?
            show do
                title "All operations have errored"
            end
            return {}
        end
        
        if debug
            operations.running.each do |op|
                bb_conc = op.input(BB).item.get(:concentration).to_f
                op.input(BB).item.associate(:concentration, 100) if bb_conc.nil?
                
                op.input_array(INSERTS).each do |input|
                    insert_conc = input.item.get(:concentration).to_f
                    input.item.associate(:concentration, rand(5)*10.0+5) if insert_conc.nil?
                end
            end
        end
        
        # calculations
        operations.running.each do |op|
            inserts = op.input_array(INSERTS)
            ratio = op.input(RATIO).val
            
            bb_mass = op.input(BB_MASS).val
            bb_conc =  op.input(BB).item.get(:concentration).to_f
            bb_vol = bb_mass / bb_conc
            bb_length = op.input(BB).sample.properties["Length"]
            
            insert_lengths = inserts.map { |fv| fv.sample.properties["Length"] }
            
            bb_moles = dsDNA_mass_to_moles(bb_mass*10.0**-9, bb_length)
            
            insert_masses = inserts.map.with_index { |fv, i| dsDNA_moles_to_mass(bb_moles * ratio, insert_lengths[i] ) * 10.0**9}
            insert_concentrations = inserts.map { |fv| fv.item.get(:concentration).to_f }
            insert_vols = inserts.map.with_index { |fv, i| insert_masses[i] / insert_concentrations[i] }
            
            show do
                title "Calculation debug"
                
                note "Ratio: #{ratio}"
                note "BB mass (ng): #{bb_mass}"
                note "BB length (bp): #{bb_length}"
                note "BB concentration (ng/uL) #{bb_conc}"
                note "Insert lengths (bp): #{insert_lengths}"
                note "Insert masses (ng): #{insert_masses}"
                note "Insert concentrations (ng/uL) #{insert_concentrations}"
                note ""
                note "BB vol (uL) #{bb_vol}"
                note "Insert vols (uL) #{insert_vols}"
            end
            
            op.temporary[:bb_vol] = bb_vol
            op.temporary[:insert_vols] = insert_vols
            bb = op.input(BB).item
            inserts = op.input_array(INSERTS).map { |fv| fv.item }
            op.temporary[:dna] = inserts + [bb]
            op.temporary[:vols] = op.temporary[:insert_vols] + [op.temporary[:bb_vol]]
            
        end
        
        
        
        show do
            title "Label tubes" 
            
            note "Retrieve #{operations.running.length} tube(s) and label with the following ids:"
            
            table operations.running.start_table
                .output_item(OUTPUT, heading: "Id")
                .custom_column(heading: "H20 (uL)", checkable: true) { |op| (op.input(TOTAL_VOLUME).val - op.temporary[:vols].inject(0) { |sum, x| sum + x }).round(1) }
            .end_table
        end
        
        
        operations.running.each do |op|
            show do
                title "Pipette DNA for #{op.output(OUTPUT).item.id}"
                
                vols = op.temporary[:vols].map { |v| [0.1, v.round(1)].max }
                
                op.temporary[:dna].each.with_index do |d, i|
                    check "<b>#{vols[i]}uL</b> of #{d.object_type.name} #{d}    \"#{d.sample.name}\""
                end
                
                # t = Table.new
                # t.add_column("DNA", op.temporary[:dna].map { |d| d.id })
                # t.add_column("Vol (uL)", op.temporary[:vols].map! { |v| v.round(1) })
                # table t
            end
        end
        
        operations.running.store
    
        return {}
    end
end