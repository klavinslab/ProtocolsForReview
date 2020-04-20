# grow one or more 24-well plates
# assume same frequency, temperature, shaker for all. growth time may differ.
# ok to batch IF there is room in shakers. 
# batching makes sure that plates from same op are in the same shaker.
#
# no new plate, so no data association handling
#
# TO DO: what if there is room for some, but not all? run only some?
needs "Standard Libs/Debug" 
needs "Induction - High Throughput/HighThroughputHelper"     

class Protocol
  include Debug
  include HighThroughputHelper 
     
  # i/o item names
  INPUT_NAME='in 24 well plates'  
  OUTPUT_NAME='out 24 well plates'
  TIME='time (hrs)' 
  # shaking params
  FREQ=281
  TEMP=37
  SHAKERS=['MaxQ','New Brunswick 37C','Plate shaker inside 37C incubator']
  FREQS=[281, 268, 1000] 

  def main

    # NO MAKE NEEDED. we are passing input array to output.   
    
    # make sure you have enough room in the shaker 
    operations.each_with_index { |op, op_ind|
        # set up shaking 
        data=show {
          title "Choose a shaker for ALL plates for this experiment"
          select SHAKERS, var: "Shaker_model", label: "Choose the shaker you will be using:", default: 2 
          warning "You will need room for #{op.input_array(INPUT_NAME).length} plate(s) in the shaker(s). Please check before proceeding!"
        }
        shaker=data[:Shaker_model] # a string
        shaker_ind=SHAKERS.index(shaker) # find index of chosen shaker
        
        show do 
          title "Set shaker parameters"
          check "Set #{SHAKERS[shaker_ind]} shaker to #{FREQS[shaker_ind]} rpm and #{TEMP}C"
          if (shaker.eql? 'MaxQ')
              note "Add adapters if necessary. Adapters and screws can be found in top drawer under the shaker."
          end  
          check "Place the #{op.input_array(INPUT_NAME).length} 24-well plate(s) in shaker, and turn shaker on"
        end 

        # show user the time
        show do
            title "Growth time"
            note "The plates should be shaken for #{op.input(TIME).val} hrs"
        end

        # update locations for all plates in this experiment, assign items to output array
        op.input_array(INPUT_NAME).items.each_with_index { |item,ii| 
            #take care of timing 
            item.associate :growthTime_hrs, op.input(TIME).val
            
            # update location
            item.move("Shaker #{shaker}")
            item.save
        } 
        
        # pass input to output
        passArray(op.input_array(INPUT_NAME), op.output_array(OUTPUT_NAME))
        
    } # operations.each
    
    # needed
    operations.store 
    
    return {}
    
  end

end
