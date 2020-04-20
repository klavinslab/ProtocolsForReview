def cost(op)
  { labor: 0.41667, materials: 0.1796 }
end

# Per operation
# 4mLs SC media - 0.0135875 * 4 - 0.05435$
# 1/24 of 24 Deep Well Plate (1 of 20 uses) - 0.059$
# 1/24 Serilogical pipette - 0.00625$
# 1/24 gas perm cover - 0.06$
#
# Labor 
# Time approx 10min for 24 samples
# 10 *60s = 600s/24
# 25s per op
# 0.41667 per op

# def one_time_cost(job_id)
#     frac = job_id.length
#     materials = 0
#     pipe_5mL = 0.15
#     materials += pipe
#     return materials/frac
# end