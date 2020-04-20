#this protocol makes 6 1.5 mL tubes of KAPA Master Mix --> Farheen
class Protocol

  def main
  
#   op=operations.first
  operations.retrieve.make
    
    #         #define aliquots to output six seperate item id's
  
    #         num_aliquots=6
    #          aliquot_ids = []
    #         (num_aliquots -1).times do 
    #         item = produce new_sample "#{op.output("KAPA HF Master Mix").sample.name}", of: "Enzyme", as: "Enzyme Stock"
    #         aliquot_ids.push item
    #  end
      
    #  op.temporary[:additional_aliquots] = aliquot_ids
    #  additional_ids = ", #{aliquot_ids.collect { |i| i.id }.join(", ")}" 
    
    output_id = []
    operations.each do |op|
        op.outputs.each do |output|
            output_id.push(output.item.id)
        end
    end
 
    #ask tech to gather items
    show do
        title "Gather the following items:"
        
        check "USE ENZYME BLOCK"
        check "Kapa HiFi Buffer (yellow)"
        check "dNTP Mix"
        check "Kapa DNA PolYmerase (green)"
        check "MG H20"
        check "#{operations.length} 14 mL round bottom tube(s)"
    end
    
    #display directions to place tube in ice bath
    show do
        title "Make ice bath"
        
        check "Make an ice bath and place each 14 mL test tube in ice"
        check "Pipette 2.4 mL of the 5X Kapa HiFi Buffer into each test tube."
    end
    
    #ask tech to pipette solutions into test tube
    show do
        title "Pipette"
        
        check "Pipette 360 uL of 10 mM dNTP mix into each test tube."
        check "Pipette 240 uL Kapa DNA Polymerase into each test tube."
        check "Pipette 3 mL MG water into each test tube."
    end
    
    #display directions to vortex test tubes
    show do
        title "Vortex"
        
        check "Vortex to mix"
        check "Aliquot 1 mL into #{operations.length * 6} 1.5 mL tubes."
    end
    
    #display directions to label test tubes
    show do
        title "Label"
        
        check "Label #{operations.length * 6} empty 1.5 mL tubes with the following ids #{output_id.join(', ')}"
    end
        
    operations.store
    
    return {}
    
  end

end