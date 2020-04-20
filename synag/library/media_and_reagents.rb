module PBSF

    
        BSA = {form: "15 mL Falcon Tube", location: "Small Fridge opposite media bay. Location R4.100"}
        PBS = Item.where(object_type_id: ObjectType.find_by_name("Container").id, sample: Sample.find_by_name("PBS 10x pH 7.4")).reject { |i| i.location == "deleted" }[0]
    
    def prepare_assay_buffers (pbs_vol, pbsf_vol)
        
        buffers = [pbs = {}, pbsf = {}]
        pbs[:sample_id] = 22033
        pbs[:vol_required] = pbs_vol
        pbs[:name] = 'PBS'
        pbsf[:sample_id]  = 22034
        pbsf[:vol_required] = pbsf_vol
        pbsf[:name] = 'PBSF'
        container_id = ObjectType.find_by_name('Container').id
        
        buffers.each do |b|
            b[:old_item] = Item.where(object_type_id: container_id, sample_id: b[:sample_id]).reject { |i| i.location == "deleted"}[0]
            
            if b[:old_item]
                age_vol_check(b)
            end
            
            if b[:old_item]
                prepare_buffer(b[:name])
            end
            
        end
    
    end
    
    def age_vol_check(b)
        
        ans = show do
            title "Check Buffer Age and Volume"
            note "Retrive Buffer #{b[:old_item].id} from the fridge"
            note "The date the Buffer was made should be on the side of the tube in the format mm/dd/yyyy"
            note "Select No if the buffer was made more than 2 weeks ago or has no date."
            note "Also select No if the volume in the tube is less than #{b[:vol_required]} mL"
            select ["Yes","No"], var: :x, label: "Usable?", default: 0 
        end
        
        if ans[:x] == 'No'
            show do 
                title "Discard buffer"
                check "Discard buffer #{b[:old_item].id}"
            end
            b[:old_item].mark_as_deleted
        end
        
    end
    
    def prepare_buffer(pbs_or_pbsf)
        vol = 45
        vol_ul = (vol * 1000).round(1)
        pbs_ul = (vol_ul / 10).round(0)
        water_ul = ((vol_ul - pbs_ul).to_f / 1000).round()
        if vol < 15 then v = "15" elsif (vol > 15 && vol < 50) then v = "50" end    
        container = "#{v} mL Falcon tube"
        
        if pbs_or_pbsf == 'PBS'
            new_item = Item.make({ quantity: 1, inuse: 1 }, sample: Sample.find(22033), object_type: ObjectType.find_by_name('Container'))
        elsif pbs_or_pbsf == 'PBSF'
            new_item = Item.make({ quantity: 1, inuse: 1 }, sample: Sample.find(22034), object_type: ObjectType.find_by_name('Container'))
        end
            
        show do 
            title "Gather reagents and items to prepare Assay buffer"
            check "Prepare the following in the media bay"
            check "#{container}, label it '#{pbs_or_pbsf} + #{new_item.id} + today's date (mm/dd/yyyy) + your initials' "
            check " Retrieve Item #{PBS.id} of #{PBS.sample.name} from #{PBS.location}"
            # check "Item #{BSA.id} of #{PBS.id} from #{BSA.location}"
            check "Measure out #{water_ul} mL of ddH20, either using the markings on the side of the #{container} or a measuring cylinder"
            check "Add  the #{pbs_ul} µL of pbs into the #{container}"
            check "Return #{PBS.sample.name} to #{PBS.location}"
        end
        
        if pbs_or_pbsf == 'PBSF'
            show do 
                title "Weight out BSA"
                check "Take the #{BSA[:form]} of BSA powder from #{BSA[:location]}"
                check "Onto a piece of weigh paper, weight out #{(vol.to_f / 1000).round(4)} g"
                check "Add the BSA into the #{container} labelled #{pbs_or_pbsf}"
            end
        
            show do 
                title "Clean up Balance area"
                check "Clean the balance with a Kimwipe, wet with ddH20"
                check "Return the BSA to #{BSA[:location]}"
            end
        end
            
    end
    
    def  prepare_antibody(pbsf, fitc)
        location = {"wizard" => "Small Fridge opposite balance area", "box" => "White box labelled 'Anti-MYC'"}
        
        show do 
            title "Retrieve antibody"
            note "#{location["wizard"]}"
            note "#{location["box"]}"
        end
        
        
        show do 
            title "Prepare antibody"
            check "Take a 1.5 mL epi"
            check "Add #{pbsf.round(1)} µl of PBSF" #3.1 is for 3 technical replicates with a little extra to make sure we don't run out. 10 is for the volume of each aliquot
            check "Add #{fitc.round(1)} µl of <b> 1 µg/µl FITC </b>"
            check "Vortex 5 seconds on low speed"
            check "Spin down in tabletop centrifuge"
            check "Cover in aluminum foil and place to the side for use later"
            check "Return the antibody to #{location["box"]} in #{location["wizard"]}"
        end
        
    end
    
end