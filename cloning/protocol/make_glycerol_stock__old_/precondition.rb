def precondition(op)
    # return true if response provided for sequencing results
    if op.plan
        # check plan associations
        response = plan.get(plan.associations.keys.find { |key| key.include? "sequencing ok?" })
        if response.present? &&
           (response.downcase.include?("yes") || response.downcase.include?("resequence") || response.downcase.include?("no")) &&
           !(response.downcase.include?("yes") && response.downcase.include?("no"))
            return true
        end
    end
    
    return false
end