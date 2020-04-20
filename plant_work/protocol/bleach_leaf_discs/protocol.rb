# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    operations.retrieve(interactive: false)
    
    show do
        title "Gather items"
        check "#{operations.length} tubes of leaf discs from the 37°C incubator"
        check "GUS waste bottle"
        check "95% ethanol for staining"
        check "1000 µl tips and corresponding pipette"
        warning "Wear gloves, safety goggles and lab coat to avoid contact with 95% ethanol"
    end

    
 operations.each do |op|
        
        #REPLACE GUS STAINING SOLUTION OR ETHANOL
        if op.input("GUS").item.get(:bleached).nil? == true
                show do
                    title "Replace GUS staining solution with ethanol for #{op.input("GUS").item}"
                    check "Using a pipette, remove the GUS staining solution from all tubes labelled #{op.input("GUS").item.id}"
                    check "Discard GUS staining solution into the GUS waste bottle"
                    check "Add 1 ml of 95% ethanol"
                end
        else 
            show do 
                title "Replace ethanol in tube #{op.input("GUS").item.id}"
                check "Using a pipette remove 95% ethanol and discard into GUS waste"
                check "Add 1 ml of fresh 95% ethanol"
            end
        end
        
        #Create output from input. 
        op.pass("GUS", "Ethanol") 
        op.output("Ethanol").item.location = "37°C Incubator"
        op.output("Ethanol").item.save
        
        if  op.input("GUS").item.get(:bleached).nil? == true    
            op.output("Ethanol").item.associate :bleached, "once"
            op.change_status "pending"
        elsif   op.input("GUS").item.get(:bleached) == "once"
            op.output("Ethanol").item.associate :bleached, "twice"
            op.change_status "pending"
        elsif   op.input("GUS").item.get(:bleached) == "twice"
            op.output("Ethanol").item.associate :bleached, "thrice"
        end
        
    end
    
    show do
        title "Place tubes in Incubator"
        check "Place tubes in a tube rack"
        check "Place tube rack in the 37°C standing incubator"
    end
    
    operations.store(interactive: false) 
    
    return {}
    
  end

end
