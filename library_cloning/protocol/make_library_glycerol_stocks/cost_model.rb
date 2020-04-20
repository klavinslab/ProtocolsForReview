def cost(op)
    input_op = op.input("Yeast Culture")
    output_op = op.output_array("Yeast Culture")
    
    if output_op.length > 1
        output_materials = output_op.length * 0.68
        { labor: 13.71 , materials: output_materials}
    else
        { labor: 3.5, materials: 0.68}
    end
end