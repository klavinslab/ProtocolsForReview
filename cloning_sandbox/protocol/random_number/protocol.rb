# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    operations.each do |op|
        show do 
            note "#{op.input("Number")}"
        end
    end
    
    return {}
    
  end

end
