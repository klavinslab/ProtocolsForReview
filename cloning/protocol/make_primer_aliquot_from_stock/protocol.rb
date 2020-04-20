class Protocol

  def main
      
    operations.retrieve.make
    
    # label new aliquot tubes and dilute
    show do 
      title "Grab 1.5 mL tubes"
      
      check "Grab #{operations.length} 1.5 mL tubes"
      check "Label each tube with the following ids: #{operations.map {|op| op.output("Aliquot").item.id}.to_sentence}"
      check "Using the 100 uL pipette, pipette 90uL of water into each tube"
    end
  
    # make new aliquots
    show do 
      title "Transfer primer stock into primer aliquot"
      
      check "Pipette 10 uL of the primer stock into the primer aliquot according to the following table:"
      table operations.start_table
                .input_item("Stock")
                .output_item("Aliquot", checkable: true)
                .end_table
      check "Vortex each tube after the primer has been added."
    end
      
    operations.store
  end
end
