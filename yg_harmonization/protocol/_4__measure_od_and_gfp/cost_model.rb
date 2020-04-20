# def cost(_op)
#   { labor: 0, materials: 0 }
# end
def cost(_op)
  mats = 0
  plate = 3.90
  sc_vol = 1.0#mL
  mats += plate
  mats += sc_vol * 0.02
  
  time = 0
  time += 5.0 #mins
  
  { labor: time, materials: mats }
end

# materials
# SC Media - $0.02/mL
# 96 Flat Bottom Plate - $3.90/plate
# 1mL of SC Media - Blank

# Time/labor
# 10 mins
