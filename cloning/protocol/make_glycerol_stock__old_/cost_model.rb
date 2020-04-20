def cost(op)
  if op.output("Plasmid").item
    { labor: 2.51, materials: 0.66 }
  else
    { labor: 0, materials: 0 }
  end
end