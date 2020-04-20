MASTER = "Master"
OUTPUT = "New Test"
POS = "Positive"
NEG = "Negative"
NUM = 6
MASTER_PLATE_KEY = "master_plate_id"
NUM_COLONIES_KEY = "num_colonies"

class Protocol

  def main

    operations.make 
    
    get_plates("YPAD")
    
    streak_across(NUM)
    
    add_controls
    
    plates_into_incubator
    
    operations.store({interactive: true, method: "boxes", io: "input"})

    {}

  end
  
  def plates_into_incubator
        show do 
          title "Place plates into 30C incubator"
          note "Put the freshly prepared plates into the 30C incubator"
          operations.each do |op|
              check "#{op.output(OUTPUT).item.id}"
              op.output(OUTPUT).item.location = "30C Incubator"
          end
        end
    end
  
    def add_controls
        
        operations.retrieve(only: [POS,NEG])
        
        operations.each do |op|
            pos = op.input(POS).item
            neg = op.input(NEG).item
            p2 = op.output(OUTPUT).item.id
            
            show do 
                title "Streak across and label controls"
                note "Single colonies are not needeed"
                check "Streak a small blob from glycerol stock #{pos.id} onto plate #{p2} and label 'Positive control'"
                check "Streak a small blob from glycerol stock #{neg.id} onto plate #{p2} and label 'Negative control'"
            end
            
    
        end
        
        # show do 
        #     title "Return glycerol stocks"
        #     operations.each do |op|
        #         check "#{pos.id} to #{pos.location}"
        #         check "#{neg.id} to #{neg.location}"
        #     end
        # end
    end
                
        
  
    def streak_across(num)
        
        operations.each do |op|
            p1 = op.input(MASTER).item
            p2 = op.output(OUTPUT).item
            n = 1 
                show do 
                    title "Streak colonies from #{p1.id} to #{p2.id}"
                    note "Carry out the following #{num} times for a total of #{num} streaked colonies"
                    check "Streak a single colony from #{p1.id} onto a bar patch of #{p2.id}"
                    check "Label the colonies on both plates cN e.g. c1 for the first colony, c2 for the second..."
                end
                
            p2.associate MASTER_PLATE_KEY.to_sym, p1.id
            p2.associate NUM_COLONIES_KEY.to_sym, NUM
            if debug
                show do
                    title "Association check"
                    note "Master plate ID: #{p2.get(MASTER_PLATE_KEY.to_sym)}"
                    note "Num colonies: #{p2.get(NUM_COLONIES_KEY.to_sym)}"
                end
            end
        end
        
        
    end
                    
        
        
  
    def get_plates(media_type)
        s = Sample.find_by_name(media_type)
        ot = ObjectType.find_by_name("Agar Plate Batch")
        b = Collection.where(object_type_id: ot.id).select{ |b| b.get_non_empty.length > operations.length && !b.deleted? && (b.matrix[0].include? s.id) }.first
      
        show do
          title "Retrieve #{media_type} plates"
          check "Retrieve #{operations.length} plates from batch #{b.id} in #{b.location}"
          note "Label plates"
          operations.each do |op|
              check "#{op.output(OUTPUT).item.id}"
          end
          check "Using a pen divide each plate into #{NUM + 2} sectors. Check with lab manager if there is a template available for this"
        end
        
        operations.each{|op| b.remove_one(s.id)}
        
        show do 
            title "Retrieve yeast transformation plates"
          table operations.start_table
            .input_item(MASTER, heading: "Yeast plate", checkable: true)
            .custom_column(heading: "Location") { |op| op.input(MASTER).item.location}
            .end_table
        end

    end
      
      
      

end
