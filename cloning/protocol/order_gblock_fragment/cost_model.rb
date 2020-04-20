#def get_sequence op
  #  sequence = op.outputs[0].sample
  #  return sequence
    # sample.properties['Length']
#   sequence = op.input("Bases").val
#   sequence = sequence[:original_value] if sequence.is_a?(Hash)
#   sequence = sequence.gsub(/\s+/, "").upcase
#   sequence
#end

#def cost(op)
 # c = 0.0
  #s = get_sequence op
  #c = case s.properties['Length']
      #  when (125..500) then
          89.00
      #  when (501..750) then
          129.00
      #  when (751..1000) then
          149.00
      #  when (1001..1250) then
          209.00
      #  when (1251..1500) then
          249.00
      #  when (1501..1750) then
          289.00
      #  when (1751..2000) then
          329.00
      #  when (2001..2250) then
          399.00
      #  when (2251..2500) then
          449.00
      #  when (2501..2750) then
          499.00
      #  when (2751..3000) then
          549.00
     # end
  #    m =  Parameter.get_float('markup rate') + 1
  
def cost(op)
    {labor: 4.38, materials: 0}
end