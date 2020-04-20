    eval Library.find_by_name("Preconditions").code("source").content
    extend Preconditions
def precondition op
    return (time_elapsed op, "Plate", days: 1, hours: 12 )
    return true
end