def cost(op)
    program_type = op.input("Program").value
    case program_type
    when "lib_qPCR1"
    { labor: 26.13, materials: 4.25 }
    when "lib_qPCR2"
    { labor: 27.4, materials: 14.29 }
    end
end