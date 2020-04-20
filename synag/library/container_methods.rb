# Library code here

module Stripwells
    
    def spin_down(container, seconds)
        show do 
            title "Spin down #{container}(s)"
            check "Take stripwell(s) to tabletop centrifugue"
            note "Balance any empty wells with water"
            check "Close lid and allow to spin for #{seconds} seconds"
        end
    end
end

module GatherPlate
    
def get_plate(reuse, number)
    if reuse == true
        location = "Bag labelled 'clean, non-sterile' from top-left drawer in set of draws next to the cleaning sink'"
    else
        location = "Cardboard box marked '96-well u-bottomed plates' in draw under the cytometer marked 'open plates'"
    end
    
    show do 
        title "Retrieve 96 well plate(s)"
        check "Retrieve #{number} 96 well plate(s) from #{location}"
    end
    
end

def return_plate(reuse, number)
    location = "Bag labelled 'clean, non-sterile' from top-left drawer in set of draws next to the cleaning sink'"
    
    if reuse == true
          
        show do 
            title "Wash and return plate(s)"
            check "Dump out the contents of the plate(s) into a red autoclave waste bin"
            check "Spray all wells in the plate with 70% ethanol"
            check "Leave for 1 minute for the ethanol to have time to kill any remaining cells"
            check "Wash out all wells thoroughly with ddH20 from the faucet"
            check "Place the plates upside on paper towel, and then return to  #{location}"
        end
    end
    
    if reuse == false
        show do
            title "Discard 96 well plate"
            check "Discard plate(s) into a red autoclave waste bin"
        end
    end
end

end
