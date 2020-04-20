# Library code here

module Ligase
    
    def ligase_batch
        
        ziplock_take = "Wire rack, under the lab coats"
        ziplock_store = "SF2"
        ligase_sample = Sample.find_by_name("10X Taq DNA Ligase Buffer")
        stripwell_object_type = ObjectType.find_by_name("Stripwell")
        stock_object_type = ObjectType.find_by_name("Enzyme Buffer Stock")
        batches = Collection.containing(ligase_sample , ot = stripwell_object_type)
       
         
        if batches.empty?
             
            ligase_item = Item.where(sample_id: ligase_sample.id, object_type_id: stock_object_type.id).reject {|i| i.location == "deleted"}
            lig_tube = ligase_item.first
            
            show do 
                title "Thaw ligase"
                check "Take Ligase buffer stock #{lig_tube.id} from #{lig_tube.location}"
                note "Let the ligase buffer thaw in your hand"
                check "Vortex to ensure there are no undissolved flakes in the bottom of the tube"
            end

            
            aliquots = show do
                title "Prepare aliquots"
                check "Lay out a stripwell"
                check "Pipette 25µl Ligase buffer into each well"
                check "Repeat this process till you have emptied the 1.5 mL tube of buffer. Discard the empty tube"
                note "How many 25 µl aliquots will you get from this tube? "
                get "number", var: :aliquots, label: "Number of aliquots", default: 25
            end
            
            num_to_make = aliquots[:aliquots]
            ligase_sample_list = []
            
            num_to_make.times do 
                ligase_sample_list.push(ligase_sample.id)
            end
            
            stripwells = Collection.spread(ligase_sample_list, "Stripwell")
            
            lig_tube.mark_as_deleted
            lig_tube.save
            
            stripwell_ids = []
                stripwells.each do |s|
                    s.location = ziplock_store
                end
            
            show do
                title "Label and store aliquots"
                check "Grab a ziplock bag from #{ziplock_take}"
                check "Label the bag with #{stripwell_ids.to_sentence}"
                check "Store the bag in #{ziplock_store}"
            end

        end
             
         batches = Collection.containing(ligase_sample , ot = stripwell_object_type)
        
             
        batch = batches.first

    end
    
       

        
        
    def thaw_buffer
        show do
            title "Thaw ligase buffer"
            check "Take an aliquot from the ligase buffer batch #{ligase_buffer_batch.first.id} at #{ligase_buffer_batch.first.location}"
            check "Leave on your bench to thaw"
            warning "Return box to freezer as soon as aliquot retrieved. This buffer is sensitive to freeze/thaw cycles"
        end
    end
    
end