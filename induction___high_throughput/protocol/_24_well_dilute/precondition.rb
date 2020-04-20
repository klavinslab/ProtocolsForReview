# before dilution, wait till 24-well growth reaches growth time
def precondition(op) 
    #return time_elapsed op, "24 well plate", hours: op.input("24 well plate").item.get("growthTime_hrs")
    return true
end