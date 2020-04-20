def precondition(op)
    # return true if response provided for sequencing results
    if op.plan
        # associate overnight and plate if possible
        # on_id = op.input("Plasmid").item.get :from
        # if on_id
        #     on = Item.find(on_id)
        #     if on.object_type.name == "TB Overnight of Plasmid"
        #         op.plan.associate "overnight_#{op.input("Plasmid").sample.id}", on_id
                
        #         plate_id = on.get :from
        #         if plate_id
        #             plate = Item.find(plate_id)
        #             op.plan.associate "plate_#{op.input("Plasmid").sample.id}", plate_id if plate.object_type.name == "Checked E coli Plate of Plasmid"
        #         end
        #     end
        # end
        
        # check plan associations
        response = plan.get(plan.associations.keys.find { |key| key.include? "sequencing ok?" })
        if response.present? &&
           (response.downcase.include?("yes") || response.downcase.include?("resequence") || response.downcase.include?("no")) &&
           !(response.downcase.include?("yes") && response.downcase.include?("no"))
            if (op.plan.get("plate_#{op.input("Plasmid").sample.id}".to_sym) || op.plan.get(:plate)).present? &&
               (op.plan.get("overnight_#{op.input("Plasmid").sample.id}".to_sym) || op.plan.get(:overnight)).present?
                return true
            else
                op.associate :see_dev, "Your plan is missing an overnight or plate association. Please contact Aquarium dev team :)"
            end
       end
       
       response = plan.get(plan.associations.keys.find { |key| key.include? "sequencing ok?" })
        if response.present? &&
           (response.downcase.include?("yes") || response.downcase.include?("resequence") || response.downcase.include?("no")) &&
           !(response.downcase.include?("yes") && response.downcase.include?("no"))
            return true
        end
    end
    
    return false
end