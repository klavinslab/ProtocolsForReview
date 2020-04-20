def cost(_op)
    mats = 0
    time = 0
    well_vol = 200.0#ul
    wells = _op.input_array("Yeast Plate").length * 6# Bio Reps
    
    # SC Media
    media = ((well_vol * wells)/1000.0) * 0.02
    mats += media
    
    # 96 Flat Bottom Plate
    mats += 3.90
    
    # labor - 
    time += (wells * 15.0)/60.0#sec
    
    { labor: time, materials: mats }
end
# def cost(_op)
#   { labor: 0, materials: 0 }
# end
# SC Media - $0.02/mL
# 96 Flat Bottom Plate - $3.90/plate

# Labor/Time 
# ~33sec/well