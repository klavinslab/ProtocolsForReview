# Abe/Garrett 8-12-2017
# Edited by Garrett 8-13-17
# edited by Sarah 10-31-17 for high-volume, overnight case
# 
# single reaction (Baker lab protocol) is:
# Per 50 uL reaction:
# 5 ug vector 
# 1 uL XhoI
# 1 uL NdeI
# 5 uL 10x cutsmart buffer
# Rest MG water
#
# 37C overnight
#
# SG comments/TODO list: 
# 0) stripwell is 8 reactions, so coded in 8x5=40 ug as maximum.
# 1) user should make sure the volume/concentration of the input is enough. ("Combine Purified Samples" may be usefull.)
# 2) use precondition in next protocol to check if restriction time has passed
needs "Cloning Libs/Cloning" # for check_concentrations

class Protocol

    include Cloning
    
    # I/O
    OUT_NAME="Digest collection"
    RESTRICTION_QUANTITY="Quantity (µg)" # ug
    RESTRICTION_TEMP="Restriction temperature (C)" # C
    RESTRICTION_TIME="Restriction time (hr)" # hr
    
    NG_PER_REACTION=5000 # 5ug
    CUTSMART_PER_REACTION=5 # uL 
    ENZYME_PER_REACTION=1 # uL
    TOT_VOL_PER_REACTION=50 # uL
    MAX_TOT_QUANTITY=40000 # maximum ng per operation - based on 8 reactions per stripwell x 5uG per reaction
    MAX_NUM_REACTIONS=8 # maximum number of lanes for next stage
    MIN_CONCENTRATION=125 # ng/ul, minimum concentration for 5 microgram in 50 microliter reaction (net volume is ~43 microliter)
    UNCUT_CONTROL_CONC=400 # ng

    def main
        
        # get Cutsmart buffer
        buffer = Sample.find_by_name("Cut Smart").in("Enzyme Buffer Stock").first
        take [buffer], interactive: true, method: "boxes" 
        
        # get plasmid concentrations
        operations.retrieve only: ["Plasmid"]
        check_concentration operations, "Plasmid" 
        
        # make output stripwell
        operations.make
        
        operations.each do |op|
            
            # do calculations: how much volume needed?
            stock = op.input("Plasmid").item
            stock_concentration = stock.get(:concentration).to_f
            if(debug)
                stock_concentration = 150
            end
            
            # check if stock is concentrated enough: if concentration is less than ~125ng/ul, 
            #will not be able to have 5 microgram in 50 microliter reaction
            if(stock_concentration < MIN_CONCENTRATION)
                show {note "plasmid stock is not concentrated enough for high-volume digest (less than #{MIN_CONCENTRATION} ng/µl), exiting."}
                return
            end
                
            # check if have vol (ul) we would like to use: min(input_in_microgram*1000, 40000)/concentration
            # floor to avoid going over 8 reactions
            stock_vol = ([op.input(RESTRICTION_QUANTITY).val*1000.to_f, MAX_TOT_QUANTITY].min.to_f/stock_concentration).floor 
            spare_vol = (2*UNCUT_CONTROL_CONC.to_f/stock_concentration).round(1)     # for running 2 lanes of uncut control on gel
            
            # check actual volume of plasmid, may not have the full volume. if do not, return.
            data = show {
                title "Check stock volume"
                note "You will need a total of #{stock_vol + spare_vol} µL of the plasmid stock for this protocol. Do you have enough?"
                select ["Yes","No"], var: "enough", label: "Please select answer", default: 0 # default is "Yes" for debug 
            }
            enough = data[:enough]
            if(enough=="No")
                show {note "Not enough plasmid stock for high-volume digest, exiting. Consider combining stocks."}
                return
            end
            
            # calculate all reaction volumes
            quantity=stock_vol*stock_concentration # ng
            n=(quantity.to_f/NG_PER_REACTION).ceil # number of reactions
            num_enzymes=op.input_array("Enzymes").length # number of different enzymes in reaction
            
            # only now get enzymes
            show do
                title "Retrieve enzymes"
                warning "Grab an ice block, and place the enzymes on it while performing the following step!"
            end
            operations.retrieve only: ["Enzymes"]
            
            # calculate water volume, make sure >=0
            water_vol=(n*TOT_VOL_PER_REACTION-n*CUTSMART_PER_REACTION-n*num_enzymes*ENZYME_PER_REACTION-stock_vol)
            if(water_vol<0)
                show {note "water volume not ok, exiting."}
                return
            end
            
            # make sure no math error
            if(n>MAX_NUM_REACTIONS)
                show {note "number of reactions=#{n} not ok, exiting."}
                return
            end
            
            # set up master mix for reaction
            show do
                if (n > 1)
                    title "Set up a master mix in a 1.5mL tube" 
                else
                    title "Add the following to a PCR tube"
                end
                warning "Set up the reaction on a cold block"
                enzyme_table_arr = [
                        [ "Plasmid #{op.input("Plasmid").item}",{ content: "<b>#{stock_vol} µL</b>", check: true} ],
                        [ "MG water", { content: "<b>#{water_vol} µL</b>", check: true} ],
                        [ "Cutsmart buffer (10x)", { content: "<b>#{n*CUTSMART_PER_REACTION} µL</b>", check: true} ]
                    ]
                op.input_array("Enzymes").items.each { |e|
                        temp =  ["Enzyme #{e}", { content: "<b>#{n*ENZYME_PER_REACTION} µL</b>", check: true} ]
                        enzyme_table_arr.push(temp)
                    }
                table enzyme_table_arr
            end
            
            # mix and split to 50uL aliquots if necessary
            if(n>1) # more than 1 reaction
                show do 
                    title "Split the master mix"
                    warning "Vortex master mix well and spin it down before splitting"
                    check "Grab stripwell for <b>#{n}</b> reactions, label it <b>#{op.output(OUT_NAME).collection}</b>"
                    check "Pipette <b>#{TOT_VOL_PER_REACTION} µL</b> of master mix into each well of the stripwell"
                end
            end
            
            # FUTURE: modify to have temperature block option
            if(op.input(RESTRICTION_TEMP).val.round==37)
                op.output(OUT_NAME).item.move("37 C standing incubator")
                op.output(OUT_NAME).item.save # needed?
                show do
                    title "Reaction conditions"
                    check "Place stripwell <b>#{op.output(OUT_NAME).collection}</b> in the <b>37C incubator</b>"
                    note "The restriction time is <b>#{op.input(RESTRICTION_TIME)} hrs</b>"
                end
            else # FUTURE: may need to set up temperature on block
                show do
                    note "no defined way to treat setting of #{op.input(RESTRICTION_TEMP).val}C"
                end
            end
            # associate incubation time to output collection - for precondition in next protocol
            Item.find(op.output(OUT_NAME).item.id).associate :time_hrs, op.input(RESTRICTION_TIME).val  
            # timer - not needed for overnight, can associate time as precondition for next protocol
        end # operations.each
        
        operations.store io: "input", interactive: true, method: "boxes"
        release [buffer], interactive: true, method: "boxes"
        #release operations.output_collections["Digest"], interactive: true # is this needed?
        
       return {}
    end # main

end # protocol
