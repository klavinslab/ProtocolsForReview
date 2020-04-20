class Protocol
  
  def main
    
    # grams of Instant Ocean Mix per liter of DI H20
    recipe = 35.8 # (g)
    
    # total volume of mix to be produced
    volume = operations.sum{ |op| op.input("Volume (L)").val } # (L)
    
    show do
      title "Make Artificial Seawater"
      note "Obtain a bottle from the closet" # TODO get real location
      note "Obtain the Instant Ocean Mix from cupboard A2505"
      note "Add #{(recipe * volume).round(2)} g of Instant Ocean Mix to the bottle"
      note "Add #{volume} L of water to the bottle"
      note "<a href='https://youtu.be/8B7xr_EjbzE' target='_blank'>Shake, Rattle, and Roll!</a>"
    end
    
  end

end