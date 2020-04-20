class Protocol
    
    ##TASK: Add constants for all inputs and outputs. 
    INPUT = "a_strains"
    INPUT_2 = "alpha_strains"
    OUTPUT = "Mated"
    PARAM_1 = "Inducer (Sample ID or '0')"
    PARAM_2 = "Inducer Object Type Name"
    PARAM_3 = "Inducer Stock Conc. (nM)"

    def main
        
        ############################
            #Gather items
            
            show do 
                title "Gather the following"
                check "Rack for culture tubes"
                check "#{operations.length} x 14 mL glass culture tube"
                check "1 x 10 mL seriological pipette"
                check "10 µl pipette and tips"
                check ""
            end
            
            operations.retrieve.make
                
        ################################
        
        operations.each do |op|
    
            
            ###########################
            
            #Prepare the output item
            
            ypad = Item.where(sample: 11767, object_type_id: ObjectType.find_by_name("800 mL Liquid"))
            ###
            
            
            show do 
                title "Prepare output culture"
                check "Take a 14 mL glass culture tube"
                #TASK: Instruction to label tube with its output number. 
                check "Label 14 mL glass culture tube: #{op.output(OUTPUT).item.id}"
                check "Using a 10 mL seriological pipette, add 3 mL of YPAD medium from bottle #{ypad.first}"
            end
            
            ############################
            #Find the inducer.
            inducer_sample = Sample.find(op.input("Inducer (Sample ID or '0')").val)
            inducer_object_type = ObjectType.find_by_name(op.input("Inducer Object Type Name").val)
            
            debug = true
            
            if debug 
                inducer_sample = Sample.find(12205)
                inducer_object_type = ObjectType.find(475)
            end
            
            
            inducer = Item.where(sample: inducer_sample, object_type: inducer_object_type)
            
            if inducer.empty?
                op.error("Inducer item unavailable")
                show do 
                    title "Operation eror"
                    note "Operation #{op.id} errored because no inducer item was unvailable"
                end
            end

            
            #########################
            #Add inducer
            
            ##TASK: Make the following block conditional on the Inducer sample input not being '0'
            if op.input(PARAM_1).val != 0
                
    
            show do 
                title "Retrieve inducer"
                note "Retrieve a tube of #{inducer_sample.name}: #{inducer_object_type.name}"
                check "Retrieve tube #{inducer.first.id} from #{inducer.first.location}"
            end
            
            ##TASK add a block that calculates how many µl of inducer for a final concentration of 100 nM in the output culture. HINT: Use the input_parameter
            inducer_conc = op.input(PARAM_3).val
            if debug
                inducer_conc = 100000
            end
                µl = (100 / inducer_conc.to_f) * 3000
            
            show do
                title "Add inducer"
                check "Add #{µl} µl of #{inducer_sample.name}: #{inducer_object_type.name}"
                check "Return tube #{inducer.first.id} to #{inducer.first.location}"
                
            end
            
            ##TASK: add a block to return the inducer. 
            end
            
            
            ############################
            #Make tables of input arrays (a strain)
            a_strains_ids = []
            a_strains_names = []
            
            op.input_array(INPUT).each do |i|
                a_strains_ids.push(i.item.id)
                a_strains_names.push(i.sample.name)
            end
            
            a_strains_volumes = Array.new(a_strains_ids.length, "2.5 µl")
            
            t = Table.new
            t.add_column("Tube ID", a_strains_ids)
            t.add_column("Strain Name", a_strains_names)
            t.add_column("Volume", a_strains_volumes)
            
            show do 
                title "Add 'a strains'"
                check "Transfer the following into tube : #{op.output(OUTPUT).item.id}"
                table t
            end
            
            alpha_strains_ids = []
            alpha_strains_names = []
            
            op.input_array(INPUT_2).each do |i|
                alpha_strains_ids.push(i.item.id)
                alpha_strains_names.push(i.sample.name)
            end
            
            alpha_strains_volumes = Array.new(alpha_strains_ids.length, "5 µl")
            
            t2 = Table.new
            t2.add_column("Tube ID", alpha_strains_ids)
            t2.add_column("Strain Name", alpha_strains_names)
            t2.add_column("Volume", alpha_strains_volumes)
            
            show do
                title "Add 'Alpha strains'"
                check "Transfer the following into tube: #{op.output(OUTPUT).item.id}"
                table t2
            end
            
            ###########
            #Put everything away
            
            show do 
                title "Clean up"
                note "Discard culture tubes: #{op.input_array(INPUT).item_ids}"
                note "Discard culture tubes: #{op.input_array(INPUT_2).item_ids}"
            end
            
            op.input_array(INPUT).items.each do |i|
               i.mark_as_deleted
               i.save
            end
            
            op.input_array(INPUT_2).items.each do |i|
               i.mark_as_deleted
               i.save
            end
            
            ###########
            
            show do
                title "Moving mating culture"
                check "Store the mated yeast strains into the 30C shaking incubator"
            end
        end  
        
        #move culture
        operations.running.each do |op|
            a_item_samples = op.input_array(INPUT).sample_ids.zip(op.input_array(INPUT).item_ids)
            alpha_item_samples = op.input_array(INPUT_2).sample_ids.zip(op.input_array(INPUT_2).item_ids)
            op.output(OUTPUT).item.associate :from_a_sample_item, a_item_samples
            op.output(OUTPUT).item.associate :from_alpha_sample_item, alpha_item_samples
            op.output(OUTPUT).item.move "30C Incubator"
            #TASK: Associate the arrays of a and alpha strain IDs with each output item. 

         end
         
            
    
                
        # Store inventory
        operations.store
        
            
        
    end
end