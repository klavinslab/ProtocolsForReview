def cost(op)
  if op.input("Restriction Enzyme").val == "BsaI"
  { labor: 8.39, materials: 8.31 }
  elsif op.input("Restriction Enzyme").val == "BbsI"
  { labor: 8.39, materials: 11.56 }
  end
end