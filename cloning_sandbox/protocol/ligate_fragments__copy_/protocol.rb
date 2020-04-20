# O. de Lange, June 2017. Assistance from G. Newman. 
needs "Cloning Sandbox/Reaction Buffers"
class Protocol
    include Ligase
        
      LIGASE = "T4 DNA Ligase"
      LIGASE_BUFFER = "T4 Ligase Buffer Batch"
      BUFFER_VOL = 10 # vol of buffer in each ligase buffer aliquot
      REACTION_VOLUME = 20.0
      Insert_fM = 150
      Backbone_fM = 50
      MIN_PIPETTE_VOL = 0.2
  
    def calc_fM(i)
        s = Sample.find_by_id(i.sample_id)
        c = i.get :concentration
        l = s.properties["Length"].to_f
        fMul = c / (6.5 * 10**-4 * l)
        fMul
    end

    def check_concentration op
        
        backbones = op.collect { |op| op.input("Backbone").item}.select { |b| b.get(:concentration).nil? } 
        
        if backbones.empty? == false
            cc = show do 
                    title "Please nanodrop the following DNA stocks"
                    backbones.each do |b|
                    note "#{b}"
                    get "number", var: "c#{b.id}", label: "#{b} item", default: 42
                    end
                end
        
            backbones.each do |b|
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
    
    def main
        
        operations.retrieve.make
        
        check_concentration operations
       
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
            .custom_column(heading: "MG H20 ", checkable: true){|op| "#{14.5-((Backbone_fM/calc_fM(op.input("Backbone").item))).round(1)} l" }
            .end_table
        end
        
        show do
            title "Load ligase buffer"
            note "Add <b>2l</b> of ligase buffer into each tube"
              table operations.start_table
            .output_item("Plasmid", heading: "Add ligase buffer to tube", checkable: true)
            .end_table
        end
        
        show do
            title "Add backbone DNA"
            note "Add the following volumes of backbone DNA"
            table operations.start_table
            .custom_column(heading: "Take"){|op| "#{(Backbone_fM/calc_fM(op.input("Backbone").item)).round(1)} l"}
            .input_item("Backbone", heading: "From Tube...")
            .output_item("Plasmid", heading: "Into Tube...", checkable: true)
            .end_table
        end
        
        show do
            title "Add Insert DNA"
            note "Add 3 l Insert (phosphorylated Fragment DNA) to each tube"
            table operations.start_table 
            .input_item("Insert", heading: "Phosphorylated fragment DNA")
            .custom_column(heading: "Volume"){"3 l"}
            .output_item("Plasmid", heading: "ligation reaction", checkable: true)
            .end_table
        end
        
        enzyme = Sample.find_by_name("T4 DNA Ligase").in("Enzyme Stock").first
       
        take [enzyme], interactive: true 
       
        show do
            title "Load ligase"
            warning "Change tips each time"
            note "0.2 l into each well"
            warning "Dip pipette tip just below the surface of the ligase and visually inspect to insure take up of enzyme"
           table operations.start_table
            .output_item("Plasmid", heading: "Add ligase to tube", checkable: true)
            .end_table
        end
        
        release [enzyme], interactive: true 
        
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