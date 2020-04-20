#Must be at least 10 days since seeds were sown out
def precondition(op)
    if op.input("Plants").item
        if Time.zone.now - op.input("Plants").item.created_at  > 60*60*24*10
            true
        else
            false
        end
    end
end