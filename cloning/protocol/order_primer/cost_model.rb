def cost(op)
    
  props = op.output("Primer").sample.properties
  overhang = props["Overhang Sequence"]
  seq = overhang.strip() + props["Anneal Sequence"].strip()
  n = seq.length
  
  if n <= 60
    c = n * Parameter.get_float('short primer cost')
  elsif n <= 90
    c = n * Parameter.get_float('medium primer cost')
  else
    c = n * Parameter.get_float('long primer cost')
  end
  
  { labor: 1.8, materials: c }
  
end