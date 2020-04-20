
needs "Cloning Sandbox/Twist"
# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol
    
    include TwistOrder

  def main

    operations.each do |op|
        
        get_shipment_content(op.input("Order number").val)
        
        sample_ids(op)
    end

    {}

  end
  
  
  def sample_ids(op)
      
        order_format = op.input("Format").val
    
        table_data = show do
            title "Input data"
            note "How many samples in this order"
            get  "number", var: :num, heading: "How many?", default: 10
        end
        
        # rows = Range.new(0,table_data[:num])
        sample_array = [*1..table_data[:num]]
        
        # default_id = Array.new(table_data[:num], 12345)
        # default_ng = Array.new(table_data[:num], 500)
  
        data = show do 
            note "Enter the Sample ID and ng of DNA from each entry in the Twist order"
            sample_array.each do |s|
                get "number", var: "sample_id_#{s}", label: "Sample ID", default: 12345
                get "number", var: "ng_dna_#{s}", label: "ng of DNA", default: 500
                select ["Fragment", "Plasmid"], var: "Sample Type_#{s}", label: "sample type?", default: 0
            end
        end
        
        items = []
            sample_array.each do |s|
                if data["Sample Type_#{s}".to_sym] == "Plasmid" then type = "Plasmid" && container = "Plasmid Stock"
                elsif data["Sample Type_#{s}".to_sym] == "Fragment" then type = "Fragment" && container = "Fragment Stock" end
                sample = Sample.find( data["sample_id_#{s}".to_sym])
                i = produce new_sample(sample.name, of: type, as: container)
                i.associate:ng_dna, data["ng_dna_#{s}".to_sym]
                items.push(i)
            end
        
        
        if order_format == "Plate"
            wells =  show do 
                title "Enter well numbers"
                note "Enter the well number for each sample"
                items.each do |i|
                    note "Well number for i"
                    get "text", var: "Well_id_#{i}", label: "Well for #{i.sample.name}", default: "A1"
                end
            end
            
            items.each do |i|
                i.associate :well_in_twist_plate, wells["Well_id_#{i}".to_sym]
            end
        end
            
            show do 
                title "Label tubes"
                note "#{items.to_sentence}"
            end
            
            items.each do |i|
                conc = (i.get(:ng_dna) / 40)
                i.associate :concentration, conc
            end
            
            volumes = Array.new(items.length, "50 µl")
            ids = Array.new(items.map{|i| i.id})
            locations = Array.new(items.map{|i| i.location})
            if order_format == "Plate"
                wells = Array.new(items.map{|i| i.get(:well_in_twist_plate)})
            end
            
            t1 = Table.new
                if order_format == "Plate" then t1.add_column("Plate Well", wells) end
                t1.add_column("Items", ids)
                t1.add_column("Water", volumes)
               
    
            show do 
                title "Rehydrate"
                if order_format == "Tubes"
                    check "Spin down all tubes briefly in a microcentrifuge"
                elsif order_format == "Plate"
                    check "Spin down the plate in the plate rotor of the large microcentrifuge"
                end
                note "Add MG H20 according to the following table"
                table t1
                check "Vortex tubes"
            end
            
            t2 = Table.new
                t2.add_column("Items", ids)
                t2.add_column("Location",locations)
            
            show do 
                title "Store items"
                table t2
            end
                
        
        # t = Table.new
        # t.add_response_column("Sample ID", default_id, { type: "number", key: :sample_id})
        # t.add_response_column("Tube contents (ng)",  default_ng, {type: "number", key: :ng_of_DNA})
        
        # responses = show do 
        #     table t
        # end
        
        # sample_ids = responses[:sample_id]
        # sample_ids_get = get_table_response(responses, {:sample_id, table_data[:num]})
        
    end
    
    

end
