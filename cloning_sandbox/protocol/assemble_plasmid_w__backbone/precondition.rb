def precondition(op)
    
    
    op.input_array("Fragment").each do |f|
        if f.sample.properties["Length"] == 0.0
            op.error :need_fragment_length, "Your fragment #{f.sample.name} needs a valid length for assembly."
            
            return false
        end
    end
    
    return true
end