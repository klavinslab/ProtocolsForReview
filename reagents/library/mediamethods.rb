# Library code here

module MediaMethods

    def measure quantity, unit, reagent
       show do
            title "Add #{reagent}"
            
            check "Measure out #{quantity} #{unit} of #{reagent} and add to bottle." 
        end
    end
    
    def steps quantity, reagent #steps 5-7
        show do
            title "Gather the following items:"
            check "#{quantity} mL bottle"
            check "bottle top filter sterilizer"
        end
        
        show do
            title "Vacuum"
            check "screw bottle top fertilizer onto empty #{quantity} bottle"
            check "connect to vacuum"
        end
        
        show do
            title "Add solution"
            check "Turn on vacuum"
            check "remove top from filter sterilizer"
            check "slowly pour in the unsterilized #{reagent} solution"
        end
    end
end # module