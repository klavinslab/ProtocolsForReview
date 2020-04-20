# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    operations.make
    
    show do
       title "Gather the Following Items:"
       check "#{operations.length} 1 L bottle(s)"
       check "#{operations.length} 500 mL bottle(s)"
       check "50% Glycerol"
    
    end
    show do
           title "Add 50% Glycerol to 500mL bottles"
           note "using a serological pipette, add 100 mL of 50% Glycerol to each 500mL bottle"
    end
    show do
            title "Measure Water and Mix"
            note "Take the bottle to the DI water carboy and add water up to the 500 mL mark. Mix solution"
    end
    show do
           title "Label and bring over to the autoclaving station"
           note "Label bottle(s) with '10% Glycerol', your initials, the date, and #{operations.map { |op| op.output("Glycerol").item.id }.to_sentence}"
           note "Bring to autoclave station"
    end
    
    show do 
        title "Prepare DI water"
        note "fill each 1L bottle with filtered water to the 1 L mark"
        note "Label bottle(s) with 'DI water' your initials, the date, and #{operations.map { |op| op.output("Glycerol").item.id }.to_sentence}"
        note "bring to autoclave station"
    end
    
    
    operations.each do |op|
        op.output("Water").item.move "Bench"
        op.output("Glycerol").item.move "Bench"
    end
    
    operations.store interactive: false
    
    return {}
    
  end

end
