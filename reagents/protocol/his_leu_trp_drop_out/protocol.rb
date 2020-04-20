needs "Reagents/MediaMethods"

class Protocol
    include MediaMethods 

  def main

    operations.retrieve interactive: false
    operations.make
    
show do #gather
    title "Gather the following items:"
    
    check "500 mL bottle"
    check "His solution, Leu solution, or Trp solution"
end

show do #weigh
    title "Add powder"
    
    check "Weigh out 5g of powder and add to bottle"
end
show do #DI water carboy
    title "Add water"
    
    check "Take the bottle to the DI water carboy and add up to the 500 mL mark"
end

show do #label
    title "Label"
    
    check "Label bottle with -xx solution"
    check "Shake until powder has dissolved"
    check "If it is taking a long time, place on heat block and stir/heat at 60C"
end
#step 5-7
    steps 500, "drop out solution"
show do #label
    title "After all of the solution has been filtered,"
    
    check "Turn off vacuum"
    check "Remove bottle top filter sterilizer"
    check "Label bottle with 'His/Leu/Trp Solution Sterile 10mg/mL, 'date,' and your initials"
end
show do #end
    title "Return."
    
    check "Throw away bottle top filter sterilizers"
    check "Place empty 500 mL bottle in dishwashing station"
    check "Return the His, Leu, or Trp solutions"
end


    
    operations.store interactive: false
    
    return {}
    
  end

end
