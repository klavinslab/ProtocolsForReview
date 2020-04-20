##TODO
#Error if no length

class Protocol
    
    def check_concentration ops
    
        missing = ops.collect { |op| op.input("Stock").item}.select { |b| b.get(:concentration).nil? } 
    
        if missing.empty? == false
            cc = show do 
                    title "Please nanodrop the following DNA stocks"
                    missing.each do |m|
                    note "#{m}"
                    get "number", var: "c#{m.id}", label: "#{m} item", default: 200
                    end
                end
        
            missing.each do |m|
                m.associate :concentration, cc["c#{m.id}".to_sym] #Convert string to symbol so it can be associated.
            end
        end

    end
    
    def check_volume op
        
            missing = op.collect { |op| op.input("Stock").item}.select { |b| b.get(:volume).nil? } 
    
        if missing.empty? == false
            nv = show do 
                    title "Please estimate the volume of the following"
                    missing.each do |m|
                    note "#{m}"
                    get "number", var: "c#{m.id}", label: "#{m} item", default: 20
                    end
                end
        
            missing.each do |m|
                m.associate :volume, nv["c#{m.id}".to_sym] #Convert string to symbol so it can be associated.
            end
            
        end
    
    end
    
    
  def main

    operations.retrieve.make
    
    check_concentration operations
    
    check_volume operations
    
    length_missing = operations.select {|op| op.input("Stock").sample.properties["Length"].nil?  or op.input("Stock").sample.properties["Length"] == "NaN" or op.input("Stock").sample.properties["Length"] == 0}
    
    if length_missing.empty? == false 
        length_missing.each do |op|
            op.error :length_missing, "You need to add a length for sample #{op.input("Stock").sample}"
        end
    end
    
    operations.running.each do |op|
       
        length = op.input("Stock").sample.properties["Length"].to_i
        ng = op.input("Stock").item.get(:concentration).to_i
        fmoles = (ng * 1520) / length
        op.input("Stock").item.associate :fmol, fmoles
    end
    
    ops_to_dilute = operations.running.select { |op| op.input("Stock").item.get(:fmol) > 41 }
    ops_to_pass = operations.running.select { |op| op.input("Stock").item.get(:fmol) < 41 }
    
    ops_to_pass.each do |op|
        vol_to_use = 40 / (op.input("Stock").item.get(:fmol))
        op.output("Dilution").item.associate :vol_for_40fm, vol_to_use
    end
    
    show do 
        title "Label tubes"
        note "Take #{operations.length} 1.5 mL tubes and lay them out in a rack. Label as follows:"
        operations.running.each do |op|
            check "<b>#{op.output("Dilution").item.id}</b>"
        end
    end
    
    ##This block is a calculation running in the background to work out how much DNA to take from each stock, and how much water to mix it with. 10 µl is taken as standard unless the stock has less than 10 µl, in which case the remaining volume is taken.
    ops_to_dilute.each do |op|
        vol_left = op.input("Stock").item.get(:volume)
        if vol_left.is_a?(Numeric) && vol_left < 10
            op.associate :dna_vol, vol_left
        else 
            op.associate :dna_vol, 10
        end
        fmol = op.input("Stock").item.get(:fmol).to_f
        dilution_factor = (40.0 / fmol)
        dna_vol = op.get(:dna_vol)
        water_vol =  ((dna_vol / dilution_factor ) - dna_vol).round(1)
        op.associate :water_vol, water_vol
        op.output("Dilution").item.associate :vol_for_40fm, 1
    end


    ##These blocks instruct the Aquarium technician to transfer DNA and then Water into the new tubes. The volumes are calculated to result in a 40 fm per µl final concentration. 
    if ops_to_dilute.empty? == false
        show do 
            title "Transfer  DNA for 40 fm µl-1 dilutions"
            ops_to_dilute.each do |op|
                check "Transfer <b>#{op.get(:dna_vol)} µL</b> from tube <b>#{op.input("Stock").item.id}</b> into <b>#{op.output("Dilution").item.id}</b>"
            end
        end
    
        
        show do 
            title "Transfer water"
                ops_to_dilute.each do |op|
                    check "Transfer <b>#{op.get(:water_vol)}</b> µL of MG H20 to tube <b>#{op.output("Dilution").item.id}</b>"
                    note "Vortex briefly to mix"
                end
        end
    end
    
    ## This definition and method will check which stocks were completely emptied out and have the technician discard them
    stocks_to_discard = ops_to_dilute.collect { |op| op.input("Stock").item }.select { |s| s.get(:volume).is_a?(Numeric) && s.get(:volume) < 10 } 
    
    if stocks_to_discard.empty? == false
        show do
            title "Discard empty DNA stocks"
            stocks_to_discard.each do |s|
                check "#{s.id}"
                s.mark_as_deleted
                s.save
            end
        end
    end
    

   
   ## Some DNA stocks may have a concentration too low to be diluted. They are simply transferred to a tube with a new label and Aquarium will track that they have a lower concentration than 40fm µl-1
    if ops_to_pass.empty? == false
        show do 
            title "Transfer from DNA stocks already at or below target concentration"
            ops_to_pass.each do |op|
                check "Transfer <b>#{op.input("Stock").item.get(:volume)} µL</b> from <b>#{op.input("Stock").item.id}</b> to <b>#{op.output("Dilution").item.id}</b>"
                check "Discard tube #{op.input("Stock").item.id}"
                op.input("Stock").item.mark_as_deleted
                op.input("Stock").item.save
            end
        end
    end
        
    show do 
        title "Spin down all tubes"
        note "Spin down tubes for 5 seconds in a tabletop centrifuge"
    end

    
    operations.store
    
    return {}
    
  end

end
