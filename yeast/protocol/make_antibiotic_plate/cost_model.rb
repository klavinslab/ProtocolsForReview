def cost(op)
  out_sample_name = op.output("Plate").sample.name
  
  case out_sample_name
  when "YPAD + Bleo"
    { labor: 3.43, materials: 2.04}
  when "YPAD + G418"
    { labor: 3.43, materials: 2.75}
  when "YPAD + clonNAT"
    { labor: 3.43, materials: 1.16}
  when "YPAD + Hygro"
    { labor: 3.43, materials: 2.85}
  else 
    { labor: 3.43, materials: 2.02}
  end
    
  
end