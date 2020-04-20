

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol
    
  CONC = "Concentrations"
  OUTPUT = "Serial Dilution"

  def main

    operations.retrieve.make

    if debug
        operations.each do |op|
            show do
                fv = op.input(CONC)
                note fv.name
                fv.value = "[[1,2,3,4,5,6,7,8]]"
                fv.save
                
                fv_unit = op.input("Unit")
                fv_unit.value = "uM"
                fv_unit.save
                
                note "value #{op.input(CONC).value}"
                note "val #{op.input(CONC).val}"
            end
        end
    end
    
    operations.each do |op|
        # make matrix here of form [[]]
    end
    
    show do
            title "Matrix"
            operations.each do |op|
                note "#{op.output(OUTPUT).collection.matrix}" 
                note "#{op.output(OUTPUT).item.get(:concentration)}"
                note "#{op.output(OUTPUT).item.get(:reagent)}"
            end
    end if debug

    operations.store

    {}

  end

end
