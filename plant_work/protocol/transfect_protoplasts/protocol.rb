
class Protocol
    
    PROTOPLASTS = "Protoplasts"
    DNA = "Plasmid"
    OUTPUT = "Transfected protoplasts"
    PEG_WEIGHT = "4000"
    TOTAL_DNA = "Total DNA (ug)"
    PROTOPLAST_COUNT = "Number of protoplasts"
    MM_TUBE_LABEL = "'PEG mix'"
    TRANSFECTION_TIME = 15
    END_WI_VOL = 500
    PLANT_AGE_KEY = "age_of_plants"
    CONTAINER = '50 mL Falcon'
    
    def main
        
        operations.retrieve({only: DNA}).make
        
        check_dna
        
        add_DNA_to_transfection_tubes
        
        prepare_PEG_mix
        
        add_cells_and_PEG_mix
        
        incubate_transfections (TRANSFECTION_TIME)
        
        wash_with_w5_resupend_wI(100, "x g", 400, "#{END_WI_VOL} uL")
        
        associate_operation_details
        
        operations.store

    end
        
    

    
####------------------------------------------------------------###
    def add_DNA_to_transfection_tubes
        
        show do 
            title "Gather and label #{CONTAINER}(s)"
            check "Gather #{operations.length} #{CONTAINER}(s)"
            note "Label as follows"
            operations.each do |op|
                check " #{op.output(OUTPUT).item.id}"
            end
        end
        
       
            show do 
                title "Add DNA to transfection tubes"
                 operations.each do |op|
                    note "Add DNA to #{CONTAINER} #{op.output(OUTPUT).item.id}"
                    op.input_array(DNA).items.each do |i|
                        vol = op.get(:ug_per_item) / (i.get(:concentration).to_f / 1000)
                        op.associate "#{i.id}_vol", vol
                        check "Add #{vol.round(1)} uL of #{i.id} into #{op.output(OUTPUT).item.id}"
                    end
                end
            end
        
    end
    
####------------------------------------------------------------###
    
    def prepare_PEG_mix
        # So that if in future we change this we can keep track of what PEG weight was used in previous jobs. 
        operations.each do |op|
            op.associate :peg_weight, PEG_WEIGHT
        end
        
        tube_label = MM_TUBE_LABEL
        conversion = operations.length * 1.2
        if operations.length < 5 then tube_type = "2 mL Eppendorf" else tube_type = "15 mL Falcon tube" end
        mix = {"30% PEG #{PEG_WEIGHT}" => 100 , "1.25 M Mannitol" => 19.2, "2 M CaCl2" => 6} #Note the keys and values are accessed as array positions [0] and [1]
        
        
        show do 
            title "Gather materials"
            check "1 x #{tube_type}"
            check "Label tube #{tube_label}"
            mix.each do |m|
                check "Retrieve stock of #{m[0]}"
                note "If cloudy vortex to ensure the suspension is evenly mixed"
            end
        end
        
        show do 
            title "Add ingredients to #{tube_type} #{tube_label} "
                mix.each do |m|
                    check "#{(m[1] * conversion).round(1)} µL of #{m[0]}"
                    note "Pipette slowly to ensure accurate volume"
                end
                check "Vortex to mix"
        end
        
    end
    
####------------------------------------------------------------###
    def add_cells_and_PEG_mix
        tube_label = MM_TUBE_LABEL
        
        operations.each do |op|
            if debug 
                op.input(PROTOPLASTS).item.associate :density, 980000
            end
            
            proto_count = op.input(PROTOPLAST_COUNT).val.to_f
                
            cells_per_ml = op.input(PROTOPLASTS).item.get(:density).to_f
            cells_per_ul = cells_per_ml / 1000
            ul_required = proto_count / cells_per_ul
            op.associate :proto_vol, ul_required.round(1) 
            op.output(OUTPUT).item.associate :cells_in_mix, proto_count
            op.output(OUTPUT).item.associate :cells_per_ml, (proto_count / (END_WI_VOL.to_f / 1000))
        end
        
        unique_proto_tubes = []
        operations.each do |op|
            i = op.input(PROTOPLASTS).item
            unless unique_proto_tubes.include? i then unique_proto_tubes.push(i) end
        end
    
        show do 
            title "Add protoplasts to transfection tubes"
            unique_proto_tubes.each do |i|
                check "Retrieve Tube of protoplasts #{i.id} from #{i.location}"
            end
            warning "use cut tip to avoid bursting protoplasts when passing through narrow pipette tips"
            note "Gently resuspend protoplasts by rolling and inverting the falcon tube before transferring into transfection tubes"
            operations.each do |op|
                check "#{op.get(:proto_vol)} µL from #{op.input(PROTOPLASTS).item.id} to #{CONTAINER} #{op.output(OUTPUT).item.id}"
            end
        end
        
        show do
            title "Add PEG mix"
            operations.each do |op|
                check " 120 µL from #{tube_label} into #{CONTAINER} #{op.output(OUTPUT).item.id}"
                note "Mix by holding #{CONTAINER} by the <b>closed</b> lid and flicking the base of the tube 10 tens."
            end
        end
        
        show do 
            title "Discard left over protoplasts"
            unique_proto_tubes.each do |i|
                check "Discuard #{i.id} into biohazard waste"
                i.mark_as_deleted
                i.save
            end
        end
        
    end

####------------------------------------------------------------###
    def incubate_transfections(time)
        
        # If later on incubation time is made into a parameter this will make it easy to integrate into protocol. 
        operations.each do |op|
            op.associate :transfection_time, time
            op.output(OUTPUT).item.associate :transfection_time, time
        end
        
        show do 
            title " Incubate transfection mixes"
            check "Wrap transfection mix tubes in aluminum foil"
            check "Place on orbital shaker"
            note "Leave to incubate for #{time}, at 50 rpm"
            timer initial: { hours: 0, minutes: time, seconds: 0}
        end
        
    end

####------------------------------------------------------------###    
    def wash_with_w5_resupend_wI(spin_speed, units, w5_vol, wI_vol)
        
        show do 
            title "Add W5"
            check "Add #{w5_vol} uL of W5 to each tube, direclty onto the transfection mix"
            check "Mix gently by inverting a few times"
            check "Spin tubes at #{spin_speed} #{units} for 3 mins in a benchtop centrifuge"
        end
        
        show do 
            title "Resupend in W1"
            check "Remove W5, being careful not to disturb the pelleted protoplasts"
            check "Add #{wI_vol} uL of WI to each tube"
            check "Mix gently by inverting a few times"
            note "Place all tubes in a rack, wrap tubes in aluminum foil, label with your initial and today's date and leave at the bench"
        end
        
        operations.each do |op|
            op.output(OUTPUT).item.location = "Bench"
        end
    end
####------------------------------------------------------------###
    
    def check_dna
        # This method will have the technicians get concentrations for any plasmid stocks for which this information is missing
        # Then the required volume of each stock is calculated, and if there is not enough volume to carry out all operations using a certain item in the job then all of those operations are errored
        
        ## Check which stock items are lacking the required info
        items_without_concs = []
        
        operations.each do |op|
            op.input_array(DNA).items.each do |i|
                if i.get(:concentration).nil?
                    items_without_concs.push(i)
                end
            end
        end
        
        ## Get technicians to check concentrations and volumes
        unless items_without_concs.empty?
            items_without_concs.each do |i|
                concs = show do 
                    title "Check Concentration"
                    note "Measure concentration in ng/ul for #{i.id}, using the nanodrop"
                    get "number", var: "#{i.id}", label: "Concentration in ng/uL", default: 500
                end
                
                i.associate :concentration, concs["#{i.id}".to_sym]
            end
        end
        
                ## Create an array of unique item ids
        unique_items = []
        operations.each do |op|
            op.input_array(DNA).items.each do |i|
                unless unique_items.include? i.id then unique_items.push(i) end
            end
        end

        vol_check = show do 
            title "Check volume of Plasmid stock items"
            unique_items.each do |i|
                if debug
                    i.associate :volume, 200 
                end
                if i.get(:volume)
                    note "There should be #{i.get(:volume)} µL in tube #{i.id}. Does this look right?"
                    select ["Yes","No"], var: "#{i.id}", label: "Choose something", default: 0
                end
            end
        end
        
        unique_items.each do |i|
            if vol_check["#{i.id}".to_sym] == "No"
                check_volume(i)
            end
        end
    
        
        ## Work out the total required volumes for each of those stocks. 
        required_volumes = {}
        unique_items.each do |i|
            total_vol = 0
            operations.each do |op|
                total_DNA = op.input(TOTAL_DNA).val
                ug_per_item = total_DNA / op.input_array(DNA).length.to_i
                op.associate :ug_per_item, ug_per_item
                op.output(OUTPUT).item.associate :ug_per_item, ug_per_item
                    op.input_array(DNA).items.each do |s|
                            if s.id == i.id then total_vol = total_vol + ug_per_item end
                    end
            end
            required_volumes[i] = total_vol
        end
        
        ## Error out any options with insufficient volume available
        required_volumes.each do |r|
            stock_item = Item.find(r[0])
            available_vol = stock_item.get(:volume).to_f
            if available_vol < r[1].to_f.round(1)
                operations.each do |op|
                    if op.input_array(DNA).items.include? stock_item 
                        op.error :insufficient_volume, "Not enough of this stock available" 
                    end
                end
            end
            stock_item.associate :volume, (available_vol - r[1])
        end
        
         
    end
    
####------------------------------------------------------------###
    
    def check_volume(i)
        
        vol = show do 
            title "Check Volumes"
            note "Check volume of #{i.id} using a p200 pipette, to nearest 10 uL. If you aren't sure how to do this check with a lab manager"
            get "number", var: :entry, label: "Volume in uL", default: 50
        end
        
        i.associate :volume, vol[:entry]
    end

####------------------------------------------------------------###
    
        def associate_operation_details
        
        # operations.each do |op|
        #     if debug then op.input(PROTOPLASTS).item.associate PLANT_AGE_KEY, 10 end
        #     op.output(OUTPUT).item.associate :plant_age_in_days, op.input(PROTOPLASTS).item.get(PLANT_AGE_KEY)
        # end
        
        operations.each do |op|
            n = 1
            op.input_array(DNA).samples.each do |s|
                op.output(OUTPUT).item.associate "plasmid_#{n}", op.input(DNA).sample.id
                n = n + 1
            end
        end
        
    end
        
        

  
 end
  
  