# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    show do
        title "Test keys"
        note "Arrows advance or go back"
        note "Ctrl-A checks all checkboxes"
        check "Like this one"
    end
    
    show do
        title "Here's another slide"
        check "With a check box"
    end
        
  end

end
