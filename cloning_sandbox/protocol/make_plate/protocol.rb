

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    operations.retrieve.make

    # will match the following
    # A11 => {"row": "A", "from": 11, "to": nil}
    # A3-5 => {"row": "A", "from": 3, "to": 5}
    parser = /(?<row>[a-zA-Z])(?<from>\d+)(?:-(?<to>\d+))?/

    
    fmt.each do |k, v|
         
    end
    

    show do
        
    end

    operations.store

    {}

  end

end
