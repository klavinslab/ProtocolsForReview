# frozen_string_literal: true

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol
    
    ALPHABET = ["A", "B", "C", "D", "E", "F", "G", "H"]
    
    def main
        operations.make.retrieve
        
        # fill columns with 8 of each
        copy_eight_columns
        
        # make visual table 
        well_table = create_table_references
        
        # combine 8 rows into 4 tubes for each column
        combine_tubes(well_table)
        
        # mark input as deleted
        operations.each do |op|
            op.input("96 Well").collection.mark_as_deleted
        end
        
        operations.store
    end
    
    # input is only one sample in row 1 but in reality it is in all 8 rows.
    # this populates the well plate with 7 more samples per column
    def copy_eight_columns
        collection = operations.first.input("96 Well").collection
        for i in 0..collection.matrix[0].length-1
            for j in 1..collection.matrix.length-1 
                collection.set(j, i, collection.matrix[0][i])
            end
        end
    end
    
    # make table with A-H, 1-12 references
    def create_table_references
        well_table = operations.first.input("96 Well").collection.matrix
        well_table.unshift([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        well_table[0].unshift(" ")
        for i in 1..well_table.length - 1
            well_table[i].unshift(ALPHABET[i - 1])
        end 
        well_table
    end
    
    # label tubes, combine tubes with updating hightlights for every sample
    def combine_tubes(well_table)
        operations.each do |op|
            show do
                title "Label tubes"
                note "Take 4 1.5 mL tubes and label them:"
                check "#{op.output("Tube 1").item}"
                check "#{op.output("Tube 2").item}"
                check "#{op.output("Tube 3").item}"
                check "#{op.output("Tube 4").item}"
                
            end
            indexOfSample = well_table[1].find_index(op.input("96 Well").sample.id)
            oldContent = well_table[1][indexOfSample]
            for i in 1..well_table.length - 1
                well_table[i][indexOfSample] = {content: oldContent, style: {background: "#00ff00"}}
            end
            show do
                title "Combine rows into tubes"
                note "<b>Sample: #{op.input("96 Well").sample.name}, Sample ID: #{op.input("96 Well").sample.id}</b>"
                table well_table
                note "Combine rows A, B, C, D, E, F, G, H of the highlighted column into 4 tubes"
                check "Combine row A & B into tube #{op.output("Tube 1").item}"
                check "Combine row C & D into tube #{op.output("Tube 2").item}"
                check "Combine row E & F  into tube #{op.output("Tube 3").item}"
                check "Combine row G & H into tube #{op.output("Tube 4").item}"
            end
            for i in 1..well_table.length - 1
                well_table[i][indexOfSample] = {content: oldContent, style: {background: "#ffffff"}}
            end
        end
    end
    
end
