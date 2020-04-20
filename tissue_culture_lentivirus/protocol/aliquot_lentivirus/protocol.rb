# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol
    INPUT = "Lentivirus Harvest"
    OUTPUT = "Aliquot"
    
  def main

    operations.retrieve.make
    
    lentivirus_warning()
    
    # A place holder for this operation...
    
    operations.store
    
    return {}
    
  end

end
