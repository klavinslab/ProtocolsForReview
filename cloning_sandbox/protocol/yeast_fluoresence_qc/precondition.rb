    eval Library.find_by_name("Preconditions").code("source").content
    extend Preconditions
def precondition op
    if op.input("Plate").object_type.name == "Yeast Fluorescence QC test plate"
        return (time_elapsed op, "Plate", days: 1, hours: 12 )
    else
        return true
    end
end