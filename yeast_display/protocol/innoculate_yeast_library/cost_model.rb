def cost(op)
   if (op.output("Yeast Culture").object_type.try(:name) == "Yeast 5ml culture")
     { labor: 3.57, materials: 0.72 }
   elsif (op.output("Yeast Culture").object_type.try(:name) == "Yeast Library Liquid Culture")
     { labor: 3.57, materials: 2.11 }
   end
   
end