needs "Tissue Culture Libs/TissueCultureConstants"

module CentrifugeLib
  include TissueCultureConstants
  
  EQUIPMENT = [
      "2 X Centrifuge buckets",
      "2 X Bucket adapters",
      "2 X Safety cups"
    ]
    
  def centrifuge_samples(samples, speed, minutes, temperature, with_prep=true, with_return=true)
    prep_centrifuge(minutes, temperature) if with_prep # gather equipment and setup centrifuge
    load_centrifuge_buckets(samples) # load your sample into the buckets
    centrifuge(speed, minutes, temperature)
    return_buckets() if with_return # clean and sterilize the buckets
  end
  
  def prep_centrifuge(minutes, temperature)
    set_centrifuge_temperature(minutes, temperature)
    gather_equipment()
  end
  
  def set_centrifuge_temperature(minutes, temp)
    show do
      title "Prepare centrifuge"
      
      check "Ask manager if you can use the centrifuge for #{minutes} minutes"
      check "Set the temperature of the centrifuge to #{temp}C."
    end
  end
  
  def gather_equipment()
    show do
      title "Gather the following equipment:"
      EQUIPMENT.each do |e|
        bullet e
      end
      
      warning "Thoroughly clean the buckets and adapters with water and scubber. They \
      may have been used for bacteria/yeast and may be very gross."
      check "Spray buckets/adapters with #{ENVIROCIDE}, wipe down and let air dry."
    end
  end
  
  def load_centrifuge_buckets(samples)
    put_in_hood samples + EQUIPMENT + ["Conical tube rack"]
    
    show do
      title "Load centrifuge buckets"
      check "Assemble centrifuge buckets"
      check "Load the following samples: #{samples.join(', ')}"
      check "Close the seal of the buckets"
      check "Spray down the outside of the buckets with #{ENVIROCIDE} and wipe dry."
      check "Remove buckets from #{HOOD}"
      note "IMAGE OF ASSEMBLED BUCKET"
      warning "Be sure to balance the buckets! Balancing tubes are located near the sink in the #{BSL2}."
    end
  end
  
  def centrifuge(speed, t, temp)
    
    show do
      title "Centrifuge #{speed}xg for #{t} minutes @ #{temp}C"
      warning "Remove <b>ALL</b> PPE before leaving the #{BSL2}!"
      check "Bring assembled buckets into #{MAINLAB}"
      check "Put buckets into centrifuge"
      check "Centrifuge #{speed}xg for #{t} minutes @ #{temp}C"
      note eggtimer(t)
    #  check "Click on the following timer: #{timer(time)}"
    end
  end
  
  def return_buckets()
    show do
      title "Return buckets"
      check "When centrifuge is done, return buckets to #{BSL2}"
    end
    
    required_ppe STANDARD_PPE
    put_in_hood ["Centrifuge Buckets"]
    
    show do
      title "Open centrifuge lids"
      warning "NEVER open lids outside of the #{HOOD}. This can release dangerous particles!"
      check "Open the centrifuge lids, remove samples and place samples in a rack."
      check "Re-assembled buckets, close lid, and move to corner of the #{HOOD}."
      warning "Centrifuge buckets will need to be sterilized before returning to the #{MAINLAB}. \
      Keep them in the #{HOOD} until you have sterilized them."
    end
  end
  
  def sterilize_buckets()
    show do
      title "Sterilize centrifuge buckets"
      check "Clear all other items except centrifuge buckets."
      check "While still in the #{HOOD}, disassemble buckets"
      check "Spray down lid, bucket, and adapter with #{ENVIROCIDE}"
      check "Leave to air dry in the #{HOOD}"
      check "Close hood and turn on UV lamp"
      check "While wearing proper PPE, return in 30 minutes to retrieve buckets and adapters"
      check "Remove all PPE and reutnr buckets and adapters to the #{MAINLAB}"
    end
  end
end