eval Library.find_by_name("Cloning").code("source").content
extend Cloning

def precondition(op)
    # return true if response provided for sequencing results
    if op.plan
        # check plan associations
        response = plan.get(plan.associations.keys.find { |key| key.include? "#{op.input("Stock").item.id} sequencing ok?" })
        if response.present? &&
           (response.downcase.include?("yes") || response.downcase.include?("resequence") || response.downcase.include?("no")) &&
           !(response.downcase.include?("yes") && response.downcase.include?("no"))
           
            # Set plasmid stock and overnight to sequence-verified
            stock = op.input("Stock").item
            stock.associate :sequence_verified, "Yes"
            if stock.get(:from) && response.downcase.include?("yes")
                overnight = Item.find(stock.get(:from).to_i)
                pass_data "sequencing results", "sequence_verified", from: stock, to: overnight
            end
            
            return true
        end
    end
end
