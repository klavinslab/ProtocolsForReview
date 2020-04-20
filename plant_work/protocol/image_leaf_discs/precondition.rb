def precondition(op)
   op.input("Leaf discs").item.get(:bleached) == "thrice"
end