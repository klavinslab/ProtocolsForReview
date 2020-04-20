class Protocol
  def main
      operations.make
    # Prepare electroporator 
        show do
            title "Prepare bench"
            note "If the electroporator is off (no numbers displayed), turn it on using the ON/STDBY button."
            note "Set the voltage to 1250V by clicking up and down button."
            note " Click the time constant button to show 0.0."
            image "initialize_electroporator"
            
            check "Retrieve and label #{operations.length} 1.5 mL tubes with the following ids: #{operations.collect { |op| "#{op.output("Transformed E Coli").item.id}"}.join(",")} "
            check "Set your 3 pipettors to be 2 uL, 42 uL, and 900 uL."
            check "Prepare 10 uL, 100 L, and 1000 L pipette tips."      
            check "Grab a Bench SOC liquid aliquot (sterile) and loosen the cap."
        end

    # Take Gibson result or plasmid and E coli comp cells and create output Transformed E Coli aliquots
        operations.retrieve
        
        
    comp_cells = Hash.new(0)
    amp = 0
    kan = 0
    
    # TODO: JV 2017-50-16 This index is not done correctly should be "batch.set r-1, c-1, nil"
    # TODO: JV 2017-50-16 We need a better "add_one" and "subtract_one" for batch collections method.
    
    # Detract comp cells from batches, store how many of each type of comp cell there are, and figure out how many Amp vs Kan plates will be needed 
        operations.each do |op|
            batch_id = op.input_array("Comp Cells").item_ids[0]
            batch = Collection.find_by_id(batch_id)
            n = batch.num_samples
            r = (n / 10) + 1
            c = n % 10
            
            if c == 0 
                c = 9
                r = r - 1
            end
            
            batch.set r, c, nil
            
            sample = op.input_array("Comp Cells").samples[0].name
            comp_cells["aliquot(s) of #{sample} from batch #{batch_id} "] = comp_cells[sample] + 1 
            
            is_kan = op.input("Plasmid").sample.properties["Bacterial Marker"] =~ /kan/i
            is_kan ? kan = kan + 1 : amp = amp + 1
        end
        
    # Get comp cells and cuvettes 
        show do 
            title "Get cold items"
            note "Retrieve a styrofoam ice block and an aluminum tube rack. Put the aluminum tube rack on top of the ice block."
            image "arrange_cold_block"
            check "Retrieve #{operations.length} cuvettes and put inside the styrofoam touching ice block."
            note "Retrieve the following electrocompetent aliquots from the M80 and place them on an aluminum tube rack: "
            comp_cells.each { |key, val| check "#{val} #{key} " }
            image "handle_electrocompetent_cells"
        end
        
    # Label comp cells 
        show do 
            title "Label aliquots"
            check "Label each electrocompetent aliquot from 1-#{operations.length}."
            note "If still frozen, wait till the cells have thawed to a slushy consistency."
            warning "Transformation efficiency depends on keeping electrocompetent cells ice-cold until electroporation."
            warning "Do not wait too long"
            image "thawed_electrocompotent_cells"
        end
        
    index = 0
    
    # Display table to tech
        show do
            title "Add plasmid to electrocompetent aliquot, electroporate and rescue "
            note "Repeat for each row in the table:"
            check "Pipette 2 uL plasmid/gibson result into labeled electrocompetent aliquot, swirl the tip to mix and place back on the aluminum rack after mixing."
            check "Transfer 42 uL of e-comp cells to electrocuvette with P100"
            check "Slide into electroporator, press PULSE button twice, and QUICKLY add 900 uL of SOC"
            check "pipette cells up and down 3 times, then transfer 300 uL to appropriate 1.5 mL tube with P1000"
            table operations.start_table 
                .input_collection("Plasmid")
                .custom_column(heading: "Well") { |op| op.input("Plasmid").column }
                .custom_column(heading: "Electrocompetent Aliquot") { index = index + 1 }
                .output_item("Transformed E Coli")
                .end_table
        end
        
    # Incubate tubes
        show do 
            title "Incubate tubes"
            check "Put the transformed E. coli aliquots into #{operations[0].input("Plasmid").sample.properties["Transformation Temperature"].to_i} C incubator using the small green tube holder."
            note "Retrieve all the tubes 30 minutes later by doing the following plate_ecoli_transformation protocol. You can finish this protocol now by perfoming the next return steps."
            note "Place #{amp} Amp plates and #{kan} Kan plates into the incubator"
            image "put_green_tube_holder_to_incubator"
        end
        
    # Clean up
        show do
            title "Clean up"
            check "Put all cuvettes into washing station."
            check "Discard empty electrocompetent aliquot tubes into waste bin."
            check "Return the styrofoam ice block and the aluminum tube rack."
            image "dump_dirty_cuvettes"
        end
        
    return {}
  end
end 