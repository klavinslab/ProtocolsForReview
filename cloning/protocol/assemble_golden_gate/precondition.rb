def precondition(op)
    # if debug
    #   return true
    # else 
    #     op.input_array("Parts").each do |part|   
    #         if part.item.get(:vol_for_40fm).nil?
    #             op.associate :attention "Submit a 'Prepare 40 fm µl-1 dilution' operation for part #{part.sample.name}"
    #             return false
    #         else
    #             return true
    #         end
    #     end
    # end
    return true
end