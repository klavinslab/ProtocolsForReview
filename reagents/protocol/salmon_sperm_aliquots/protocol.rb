class Protocol

  def main

    op = operations.first
    operations.make

    operations.each do |op|
        show do
            title "Gather tube"
            check "Gather a 1 mL Tube of Preboiled Salmon Sperm DNA." 
        end
        
        show do
            title "Arrange Stripwell"
            check "Arrange 96 stripwells of all different sizes on a green Stripwell holder."
        end
        
        show do
            check "In a 14 mL tube, add 1 ml Preboiled Salmon Sperm DNA and 4 mL TE Buffer"
            check "Vortex to mix"
        end
        
        ss_aliquot = Sample.find_by_name("Salmon Sperm DNA")
        96.times { op.output("SS Batch").collection.add_one ss_aliquot}
        
        show do
            title "Aliquot and Cap"
            check "Aliquot 50 uL into each well" 
            check "Cap all wells."
        end
    
        template = [['98 C for 5 minutes'], ['4 C for infinity']]
        
        show do
            title "Arrange Stripwell"
            check "Place all 96 wells in a Thermocycler."
            check "Run the 'Boil' Protocol at 98 C for:"
            table template
        end
        
        show do
            check "As soon as the 5 minute boil is done, place all stripwell in a box labeled 'Salmon Sperm'."
            check "Mark date and initials of output #{op.outputs[0].item.id.to_s}; store in M20 immediately."
        end
    end
    
    operations.store

    {}

  end

end