module AssociationPassing
    def pass_association (op,input,output,key)
            op.output(output).item.associate key, op.input(input).item.get(key)
    end
end