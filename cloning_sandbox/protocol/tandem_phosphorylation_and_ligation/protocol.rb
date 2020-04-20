# Philip J. Leung, April 2019. Assistance from E. Lopez. Several code blocks lifted from O. de Lange 'Blunt end cloning'

# Context in full workflow. Fragment: Stripwell --> [Tandem Phosphorylation and Ligation] --> Plasmid: ligation product ---> [ E. coli transformation].

needs "Standard Libs/Debug"

class Protocol
    include Debug
    
    BUFFER_VOL = 50 # vol of buffer in each ligase buffer aliquot
    REACTION_VOLUME = 10.0
    MIN_PIPETTE_VOL = 0.2

    def main
        
        operations.retrieve.make
        
        operations.group_by {|op| op.output('Plasmid').collection}.map {|out_coll, ops|
            in_collection = ops.map {|op| op.input("Fragment").collection }.uniq
            take in_collection, interactive: true
            
            ligase_buffer_batch = Collection.find_by_object_type_id(ObjectType.find_by_name("2X KLD Buffer Batch").id)
       
           show do
              title "Thaw 2X KLD buffer"
                check "Take an aliquot from the ligase buffer batch #{ligase_buffer_batch.id} at #{ligase_buffer_batch.location}"
                check "Leave on your bench to thaw"
                warning "Return box to freezer as soon as aliquot retrieved. This buffer is sensitive to freeze/thaw cycles"
            end
                
            ligase_buffer_batch.subtract_one Sample.find_by_name("2X KLD Buffer"), reverse: true
            
            show do
                title "Retrieve stripwell"
                    id=out_coll.id
                    check "Label new stripwell #{id}" # label with out_coll.id
                    check "Transfer 1 µl from each well into the corresponding well of the new stripwell #{id}" # transfer to out_coll
            end
                
                #for each stripwell do all
                
                show do
                    title "Load 2X KLD buffer"
                    note "Don't need to change tips"
                    note "5µl into each well"
                    warning "Check buffer has thawed properly."
                    table ops.start_table
                        .output_collection("Plasmid")
                        .output_column("Plasmid", heading: "Well", checkable: true)
                    .end_table
                end 
              
                enzyme = Sample.find_by_name("KLD Enzyme Mix").in("Enzyme Stock").first
               
                take [enzyme], interactive: true 
               
                show do
                    title "Load KLD Enzyme Mix"
                    warning "Change tips each time"
                    warning "Use enzyme block"
                    note "1µl into each well"
                    table ops.start_table
                        .output_collection("Plasmid")
                        .output_column("Plasmid", heading: "Well", checkable: true)
                    .end_table
                end
                
                release [enzyme], interactive: true 
               
               show do
                    title "Load water"
                    warning "Change tips each time"
                    note "3µl into each well"
                    check "Pipette up and down to mix"
                    table ops.start_table
                        .output_collection("Plasmid")
                        .output_column("Plasmid", heading: "Well", checkable: true)
                    .end_table
                end
               
                show do
                    title "Seal stripwell"
                    warning "Press firmly to ensure seal"
                end
                
                show do
                    title "Incubate reaction at RT"
                    check "Incubate the stripwell for 5 minutes at room temperature on the benchtop."
                    check "Proceeed to next step."
                    note "Ignore request to return stripwell to fridge"
                end
        }
            
      
        operations.store
  
    end

end
