needs "Tissue Culture Libs/CollectionDisplay"


# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol
    include CollectionDisplay
  def main

    operations.retrieve.make

    tin  = operations.io_table 'input'
    tout = operations.io_table 'output'

    collection = operations.map { |op| op.inputs[0].collection }.first
    tbl = create_collection_table(collection)

    operations.each { |op|
        show do
            title "highlight_alpha_non_empty"
            note "<i>Here you can input a collection and display volumes (or whatever) on a table.</i>"
            check "Please pipette the following amount of SuperDuperMagic media into the plate."
            table highlight_alpha_non_empty(op.inputs[0].collection) {|r,c| "10uL" }
        end
    }
    
    show do
        title "highlight_alpha_rc"
        
        note "<i>If you have a list of rows and columns, you can highlight and display things on a collection table.</i>"
        table highlight_alpha_rc(operations.first.inputs[0].collection, [[0,1]]) { |r,c| "112lkjl" }
    end
    
    # id_block = Proc.new { |op| op.input("Plate").child_sample_id }
    tables = highlight_collection(operations) { |op| op.input('Plate') }
    tables.each do |collection, tbl|
        show do
            title "get plate #{collection.id}"
            table tbl
        end
    end

    {}

  end

end
