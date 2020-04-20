

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    operations.retrieve.make

    show do
        table operations.running.start_table
            .input_collection("Stripwell", heading: "Stripwell id")
            .custom_column(heading: "Well") { |op| op.input("Stripwell").column + 1 }
            .output_item("Stock", heading: "New Fragment Stock Id")
            .end_table
            
    end 
    
    operations.store

    {}

  end

end
