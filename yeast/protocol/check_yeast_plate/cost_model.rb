# Check E coli Plate Cost Model

def cost(op)
  if op.status == 'error'
    { labor: 0, materials: 0 }
  else
    { labor: 1.49, materials: 0.02 }
  end
end