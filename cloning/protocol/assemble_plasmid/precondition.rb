def precondition(op)
    
    if op.input_array("Fragment").length < 2
        op.error :more_fragments, "You usually shouldn't do a gibson assembly with less than 2 fragments. Was this intentional?"
        return true
    end
    
    
    op.input_array("Fragment").each do |f|
        if f.sample.properties["Length"] == 0.0
            op.error :need_fragment_length, "Your fragment #{f.sample.name} needs a valid length for assembly."
            
            return false
        end
    end
    
    return true
end