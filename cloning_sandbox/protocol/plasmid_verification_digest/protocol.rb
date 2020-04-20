# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!
needs "Cloning Libs/Cloning"
class Protocol
include Cloning

DNA_AMOUNT = 500 #ng

    
    def check_volume op
        
        missing = op.collect { |op| op.input("DNA").item}.select { |b| b.get(:volume).nil? } 
    
        if missing.empty? == false
            nv = show do 
                    title "Please estimate the volume of the following"
                    missing.each do |m|
                    note "#{m}"
                    get "number", var: "c#{m.id}", label: "#{m} item", default: 20
                    end
                end
        
            missing.each do |m|
                m.associate :volume, nv["c#{m.id}".to_sym] #Convert string to symbol so it can be associated.
            end
            
        end
    end

  BUFFER_VOL = 1
  
  def main

    operations.retrieve only: ["DNA"]
    
    check_concentration operations, "DNA"
    check_volume operations
    
    buffer = Sample.find_by_name("Cut Smart").in("Enzyme Buffer Stock").first
    
    operations.each do |op|
        dna_µl = (DNA_AMOUNT / op.input("DNA").item.get(:concentration).to_f).round(1)
        op.associate :dna_vol, dna_µl
        enzyme_vol = 0.5 * op.input_array("Enzymes").length
        water_µl = (10.0 - dna_µl - BUFFER_VOL - enzyme_vol).round(2)
        op.associate :water_vol, water_µl
        if dna_µl > op.input("DNA").item.get(:volume)
            op.error :insufficient_volume, "Insufficient volume to run digest for #{op.input("DNA").sample}"
        end
    end
    
    ## Use 200 ng per reaction.
    operations.make
    
    stripwells = operations.running.map {|op| op.output("Cut DNA").collection}.uniq
    
    show do 
        title "Retrieve Enzyme buffer"
        note "Retrive a tube of CutSmart buffer"
        check "#{buffer.id}, from #{buffer.location}"
    end

    show do 
        title "Label stripwell(s)"
        note "Take #{stripwells.length} stripwell(s), and label as follows"
         stripwells.each do |s|
            check "#{s.id}"
        end
    end 
    
    show do 
        title "Add water to tubes"
        table operations.running.start_table
            .output_collection("Cut DNA", heading: "Stripwell")
            .custom_column(heading: "Well Number") { |op| (op.output("Cut DNA").column + 1)  }
            .custom_column(heading: "MG H20", checkable: true) { |op| op.get(:water_vol) }
            .end_table
    end
    
        show do 
        title "Add buffer to tubes"
        note "Add 1µl of CutSmart buffer (Item ID: #{buffer.id})"
        table operations.running.start_table
            .output_collection("Cut DNA", heading: "Stripwell")
            .custom_column(heading: "Well Number") { |op| (op.output("Cut DNA").column + 1)  }
            .custom_column(heading: "CutSmart", checkable: true) { "1 µl"}
            .end_table
    end
    
    show do 
        title "Add DNA to tubes"
        table operations.running.start_table
            .output_collection("Cut DNA", heading: "Stripwell")
            .custom_column(heading: "Well Number") { |op| (op.output("Cut DNA").column + 1)  }
            .input_item("DNA", heading: "DNA stock")
            .custom_column(heading: "Volume (µl)", checkable: true) { |op| op.get(:dna_vol) }
            .end_table
    end
    
    operations.running.each do |op|
        new_vol = op.input("DNA").item.get(:volume) - op.get(:dna_vol)
        op.associate :volume, new_vol
    end
    
    show do 
        title "Retrieve Enzymes"
        note "In the next step you will be asked to receive enzymes needed to set up digests"
        note "<b>Take a -20 block from the small freezer next to the cleaning sink. Place enzymes into this block"
        warning "Enzymes are very temperature sensitive"
    end
    
    operations.retrieve only: ["Enzymes"]
    
    
   
    show do
        title "Add Enzymes"
         operations.running.each do |op|
            note "Stripwell: #{op.output("Cut DNA").collection}, Well: <b>#{op.output("Cut DNA").column + 1}</b>"
            op.input_array("Enzymes").each do |e|
                check "0.5 µl of #{e.sample.name}( Stock ID:#{e.item.id})"
            end
        end
    end

    
    show do 
        title "Incubate"
        check "Spin down stripwell(s) in a table top centrifuge"
        check "Secure lids to stripwell(s)"
        check "Place in 37°C incubator"
        note "Continue to next step to return items"
    end
    
    operations.running.each do |op|
        op.output("Cut DNA").item.move "37C Incubator"
    end
    
    operations.store
    
    return {}
    
  end

end
