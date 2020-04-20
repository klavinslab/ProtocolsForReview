def cost(op)
  { labor: 9.16, materials: 0.38 + (0.25 * op.input_array("Enzymes").length) }
end

##Labor: Based on 25mins to process 7 samples.
##Reagents: Based on 0.5µl of Enzyme cost $0.25, 3 10µl pipette tips, 1 Stripwell well and no buffer cost because it comes with the restriction enzymes. 