# O. de Lange, June 2017. Assistance from G. Newman. 
needs "Cloning Sandbox/Reaction Buffers"

class Protocol
    include Ligase
        
      LIGASE_BUFFER = "T4 Ligase Buffer Batch"
      REACTION_VOLUME = 20.0
      MIN_PIPETTE_VOL = 0.2
  
    def check_concentration op
        
        backbones = op.collect { |op| op.input("Backbone").item}.select { |b| b.get(:concentration).nil? } 
        inserts = op.collect { |op| op.input("Insert").item}.select { |b| b.get(:concentration).nil? } 
        dna_items = backbones + inserts
        
        if dna_items.empty? == false
            cc = show do 
                    title "Please nanodrop the following DNA stocks of type"
                    dna_items.each do |b|
                    note "#{b}"
                    get "number", var: "c#{b.id}", label: "#{b} item", default: 42
                    end
                end
        
            dna_items.each do |b|
                b.associate :concentration, cc["c#{b.id}".to_sym] #Convert string to symbol so it can be associated.
            end
        end
    end
    
    def calc_output_ng(i)
            s = Sample.find_by_id(i.sample_id)
            l = s.properties["Length"].to_f
            ng = (50 * l) / 1520 
            ng
    end
    
    def parameter_set op
        #Find ligase. Associate with op. 
         enzymes = Item.where(sample_id: Sample.find_by_name("T4 DNA Ligase"), object_type_id: ObjectType.find_by_name("Enzyme Stock")).reject {|i| i.location == "deleted"}
         ligase = enzymes.shuffle.first
         op.associate :ligase, ligase.id

        #Set the masses of DNA to be used for each operation. 
        
        ratio = op.input("Insert:Backbone").val
        total_ng = op.input("Total_DNA_ng").val
        insert_amount = ratio[0].to_i
        total_µl = REACTION_VOLUME
        op.associate :calculation, insert_amount + 1
        op.associate :backbone_ng, (backbone_ng = (total_ng / (insert_amount + 1)))
        op.associate :insert_ng, (total_ng - backbone_ng)
        insert_conc = op.input("Insert").item.get(:concentration).to_f
        backbone_conc = op.input("Backbone").item.get(:concentration).to_f
        op.associate :ul_insert, ((insert_conc / op.get(:insert_ng)).round(1))
        op.associate :ul_backbone, ((backbone_conc / op.get(:backbone_ng)).round(1))
        op.associate :ul_h20, (total_µl - (op.get(:ul_backbone) + op.get(:ul_insert) + 2 + op.input("Ligase Volume").val))
        op.output("Plasmid").item.associate :concentration, (total_ng / total_µl)
        
    end
    
    def main
        
        operations.retrieve.make
        
        check_concentration operations
    
        operations.each do |op|
            parameter_set op
        end
        
        show do
            title "Label tubes"
            note "Take #{operations.length} 1.5ml tubes and label as follows"
            operations.each do |op|
              check "#{op.output("Plasmid").item.id}"
            end
        end
        
        aliquots_needed = (2.0 * operations.length / 25.0).ceil
        batch = ligase_batch
        
        # ligase_buffer_batch = Collection.where(object_type_id: ObjectType.find_by_name("T4 Ligase Buffer Aliquot").id).reject { |i| i.location == "deleted" }
       
       show do
          title "Thaw ligase buffer"
            check "Retreive #{aliquots_needed} aliqout(s) of ligase buffer from the ziplock bag in #{batch.location}, labelled with #{batch.id}"
            check "Leave on your bench to thaw"
            warning "Return buffer batch to freezer as soon as aliquot retrieved. This buffer is sensitive to freeze/thaw cycles"
        end
        
        
        aliquots_needed.times do
            batch.subtract_one Sample.find_by_name("T4 DNA Ligase Buffer"), reverse: true
        end
        
    
        show do
            title "Load water"
            note "Add water to each 1.5 ml tube, according to the table below"
            table operations.start_table 
            .output_item("Plasmid", heading: "Tube ID")
            .custom_column(heading: "MG H20 ", checkable: true){|op| "#{op.get(:ul_h20)}"}
            .end_table
        end
        
        show do
            title "Load ligase buffer"
            note "Add <b>2µl</b> of ligase buffer into each tube"
              table operations.start_table
                .output_item("Plasmid", heading: "Add ligase buffer to tube", checkable: true)
                .end_table
        end
        
        show do
            title "Add backbone DNA"
            note "Add the following volumes of backbone DNA"
            table operations.start_table
            .custom_column(heading: "Take"){|op| "#{op.get(:ul_backbone)}"}
            .input_item("Backbone", heading: "From Tube...")
            .output_item("Plasmid", heading: "Into Tube...", checkable: true)
            .end_table
        end
        
        show do
            title "Add Insert DNA"
            note "Add the following volumes of insert DNA"
            table operations.start_table 
            .input_item("Insert", heading: "Phosphorylated fragment DNA")
            .custom_column(heading: "Volume"){|op| "#{op.get(:ul_insert)}"}
            .output_item("Plasmid", heading: "ligation reaction", checkable: true)
            .end_table
        end
        
        show do 
            title "Retrieve Ligase enzyme stock(s)"
            warning "Transfer stocks into a -20°C cooling block. Do not allow them to warm to room temperature"
            operations.each do |op|
                enzyme = Item.find(op.get(:ligase))
                check "Take Enzyme stock #{enzyme.id} from #{enzyme.location}"
            end
        end

        show do
            title "Load ligase"
            warning "Change tips each time"
            note "Add the following volumes of Ligase into each well"
            warning "Dip pipette tip just below the surface of the ligase and visually inspect to insure take up of enzyme"
           table operations.start_table
            .custom_column(heading: "Volume ligase"){|op| "#{op.input("Ligase Volume").val}"}
            .custom_column(heading: "Ligase item ID"){|op| "#{op.get(:ligase)}"}
            .output_item("Plasmid", heading: "Into ligation reaction", checkable: true)
            .end_table
        end
        
        show do 
            title "Return Ligase enzyme stock(s)"
            operations.each do |op|
                enzyme = Item.find(op.get(:ligase))
                check "Take Enzyme stock #{enzyme.id} back to #{enzyme.location}"
            end
        end
        
        run_location = show do
            title "Store reaction on the bench"
            check "Spin down tubes in tabletop mini-centrifuge"
            check "Leave the reactions on the bench. DNA ligation takes place at room temperature."
            get "text", var: "store_at", label: "Please describe where you will be leaving these tubes so that another tech could find them", default: "Bench two, by the label printer"
            note "This protocol will finish here and after 2 hours these Blunt End cloning reactions will be available as inputs for E. coli transformation"
        end
        
        operations.each do |op|
            op.output("Plasmid").item.location = run_location[:store_at]
            op.output("Plasmid").item.save
        end
        
        operations.store
    
    end

end