#Gibson Master Mix to make 80 aliquots
class Protocol

  def main
    #ISO buffer
    operations.add_static_inputs("T5 Exo", "T5 exonuclease", "Enzyme Stock")
    operations.add_static_inputs("Phusion Poly", "Phusion Polymerase", "Enzyme Stock")
    operations.add_static_inputs("Taq Lig", "Taq DNA Ligase", "Enzyme Stock")
    operations.retrieve.make
    
    operations.each do |op|
        show do
            title "5X ISO buffer"
            check "Pipette 320 uL 5X ISO Buffer to mix."
        end
        
        show do 
            title "T5 exonuclease"
            check "Pipette 0.64 uL of 10 U / uL T5 exonuclease to mix."
        end
        
        show do
            title "Taq DNA ligase"
            check "Pipette 160 uL of 40 U / uL Taq DNA ligase to mix"
        end
        
        show do
            title "Water"
            check "Add water to 1.2 mL (699.36 uL)."
        end
        
        show do 
            title "Phusion"
            check "Add 20 uL of Phusion Master Mix"
        end
        
        show do 
            check "Partition into 15 uL Aliquots and store at -20 C"
            note "It can be stored at -20 C for at least one year, the enzymes remain active following
            at least 10 freeze-thaw cycles"
            note "Ideal for the assembly of DNA molecules with 20-150 bp overlaps. For DNA molecules
            overlapping by larger than 150 bp, prepare the assembly mixture by using 3.2 ?l of 10 U / uL T5 exo."
        end
        
        num = show do
            note "Record the amount of aliquots created for this batch"
            get "number", var: :count, label: "How many Aliquots", default: 40
        end[:count]
        
        samp = Sample.find_by_name("Gibson Aliquot")
        coll = Collection.find(op.output("Gibson Batch").item) # cast output to collection
        
        #add samples to output collection
        num.times do
            coll.add_one(samp)
        end
        
        show do
            title "Batch Successfully Created"
            table coll.matrix
        end
    end
        
    operations.store
    return {}
    
  end

end

