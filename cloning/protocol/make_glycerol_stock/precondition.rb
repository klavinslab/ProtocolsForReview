def precondition(op)
    needs_seq = op.input("Needs Sequencing Results?").val.strip == "Yes"
    # op.associate :item_thing, op.input("Overnight").item.get(:sequence_verified).downcase
    # seq_response = op.plan.get("Item #{op.item.id} sequencing ok?")
    return !needs_seq || (op.input("Overnight").item && op.input("Overnight").item.get(:sequence_verified) && op.input("Overnight").item.get(:sequence_verified).downcase.include?("yes"))
end