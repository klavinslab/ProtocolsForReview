eval Library.find_by_name("Preconditions").code("source").content
extend Preconditions

def precondition(op) 
  time_elapsed op, "Plate", hours: 8
  true
end