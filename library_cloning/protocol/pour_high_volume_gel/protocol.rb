# edited by SG for gel type, percentage, high throughput
needs "Standard Libs/Debug"
needs "Standard Libs/Feedback"

class Protocol
  include Debug
  include Feedback
    
        
  GEL_VOL_mL=50.0 # mL  
  
  # I/O
  PERCENTAGE="percentage"
  GEL_TYPE="gel type"
  GEL="gel"
  
  # params
  COMB_TYPE="thick" # so have enough room for 50uL reactions + loading dye
  MICROWAVE_TIME_MIN=1 # min
  
  def main
      
    # gels can differ between operations, unlikely we will have many high-volume, so pour one at time and aim to use the whole gel:
    # 4 50µL reactions, 1 lane for ladder, 1 lane for uncut
    
    # make the output gel item
    operations.make
    
    # loop over separate pour full gel box operations
    operations.each do |op|
        
        mass = ( (op.input(PERCENTAGE).val / 100) * GEL_VOL_mL).round 2 # g
        error = ( mass * 0.05 ).round 5 # allowed error in g is +/- 5%
   
        show do
            title "Pour high volume gel"
            check "Grab a flask from on top of the microwave M2."
            check "Get a graduated cylinder from on top of the microwave. Measure and add <b>50 mL</b> of 1X TAE from jug J2 to the flask."
            check "Using a digital scale, measure out <b>#{mass} g</b> (+/- #{error} g) of <b>#{op.input(GEL_TYPE).val}</b> agarose powder and add it to the flask."
            warning "Make sure you are using <b>#{op.input(GEL_TYPE).val}</b> agarose!"
            if(op.input(GEL_TYPE).val=="low melting")
                note "<b>Low-melting</b> agarose is located in the cabinet above the microwave."
            end
            check "Microwave <b>#{MICROWAVE_TIME_MIN} min</b> on high in microwave M2, then swirl. The agarose should now be in solution."
            note "If it is not in solution, microwave 7 seconds on high, then swirl. Repeat until dissolved."
            warning "Work in the gel room, wear gloves and eye protection all the time"
        end

        # get agar ready
        show do
            title "Add GelGreen"  
            warning "GelGreen is supposedly safe, but stains DNA and can transit cell membranes (limit your exposure)."
            warning "GelGreen is photolabile. Limit its exposure to light by putting it back in the box."
            note "Add <b>#{5*GEL_VOL_mL/50.0} µL</b> of GelGreen into the pipet tip. Expel the GelGreen directly into the molten agar (under the surface), then swirl to mix."
        end

        # get tray ready
        show do
            title "Add combs"
            check "Go get a 49 mL Gel Box With Casting Tray (clean)"
            check "Retrieve 2 <b>6-well</b> purple combs from A7.325"
            check "Position the gel box with the electrodes facing away from you."
            check "Add a purple comb to the side of the casting tray nearest the side of the gel box."
            check "Put the <b>#{COMB_TYPE}</b> side of the comb down."
            check "Add another purple comb to the center of the casting tray."
            check "Put the <b>#{COMB_TYPE}</b> side of the comb down."
            note "Make sure that both combs are well-situated in their grooves of the casting tray."
        end
        
        show do
            title "Pour and label the gel"
            note "Using a gel pouring autoclave glove, pour agarose from one flask into the casting tray. 
                  Pour slowly and in a corner for best results. Pop any bubbles with a 10 µL pipet tip."
            note "Write <b>#{op.output(GEL).item}</b> + #{Time.zone.now.to_date} on piece of lab tape and affix it to the side of the gel box."
            note "Leave the gel at location A7.325 to solidify."
        end
    end 
    
    operations.store(io: "output") 
    
    # operations.store
    
    get_protocol_feedback
    return {}
    
  end

end