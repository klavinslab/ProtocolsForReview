def cost(op)
    quantity = op.input("Quantity").val || 1.0
  { labor: 0, materials: quantity * op.output("Ordered Item").sample.properties['Unit Price'] }
  { labor: 0, materials: 0 }
end