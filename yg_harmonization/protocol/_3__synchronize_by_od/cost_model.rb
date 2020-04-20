# def cost(_op)
#   { labor: 0, materials: 0 }
# end
# Needs editing - 01182018
def cost(_op)
    
    # Materials
    mats = 0.0
    
    well_vol = 1.0#mL
    dilutions = 3 #[0.0003, 0.00015, 0.000075].length # _op.input("Final OD").val 

    in_wells = 30
    
    out_wells = dilutions * in_wells
    tot_sc_media = well_vol * out_wells
    
    mats += tot_sc_media * 0.02
    mats += 8.90# 96DWPlate
    
    # Labor/time
    time = 0.0
    
    plate_reader = 5.0#mins
    fill_w_media = 5.0#sec/well
    trans_cult = 3.0#sec/well
    
    time += (fill_w_media * out_wells)/60.0
    time += (trans_cult * out_wells)/60.0
    time += plate_reader
    
    { labor: time, materials: mats }
end

# Materials
# SC Media - $0.02/mL
# 96 Deep Well Plate - $8.90/plate
#
# Time/Labor
# plate_reader - ~5.0 mins/plate
# Fill Plate w Media - ~ 5min 20sec
# Transfer Cults & inoculate - ~4min 48sec