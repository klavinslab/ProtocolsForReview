

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol
    
  INPUT = "Plate"
  YEAST_PLATE = "Yeast Plate"
  QC_TEST_PLATE = "Yeast Fluorescence QC test plate"
  NIGHTSEA_STORAGE = "in labelled draw near to gel dock"
  WORK_ROOM = "Lab Equipment Room 380B"
  FP = "Fluorescent protein"
  MCHERRY = "mCherry"
  MTURQ = "mTurq"
  CORRECT_COLONY_UPPER_LIMIT = 5
  NUM_COLONIES_KEY = "num_colonies"
  ASSOCIATION_KEY = "correct_colonies"
  MASTER_PLATE_KEY = "master_plate_id"
  
    def main
      
        gather_materials
        
        screen_plates
        
        operations.store
    
        {}

    end
    
        #-------- Gather Materials -----------#
  
        def gather_materials
          
            operations.retrieve
            
            show do 
                title "Take plates to room #{WORK_ROOM}"
                check "Plate plates down on a clear work surface and retrieve the 'Nightsea'"
                note "Nightsea is stored #{NIGHTSEA_STORAGE}"
            end
            
        end
    
        #-------- Screen Plates -----------#
      
        def screen_plates
            qc_plate_ops =  operations.select{|op| op.input(INPUT).object_type.name == QC_TEST_PLATE}
            trafo_plate_ops = operations.select{|op| op.input(INPUT).object_type.name == YEAST_PLATE }
          
            show do 
                title "Notes on use of the Nightsea"
                note "The <b>lightsource (gun)</b> has two settings: Green or Blue"
                note "To turn the lightsource on pull the trigger-like toggle down"
                note "To switch between settings turn left or right"
                note "If no light is produced the batteries may be empty. Consult a lab manager"
                note "The <b> emissiion filters</b> are two pairs of glasses with yellow or red colored lenses"
                note "The YELLOW filters are used with the BLUE lightsource setting"
                note "The RED filters are used with the GREEN lightsource setting"
            end
            
            if qc_plate_ops then screen_qc_plate_ops(qc_plate_ops) end
            if trafo_plate_ops then screen_trafo_ops(trafo_plate_ops, CORRECT_COLONY_UPPER_LIMIT) end
                
        end
        
        #-------- Screen Trafo Ops -----------#
        def screen_trafo_ops(trafo_plate_ops, limit)
            
            trafo_plate_ops.each do |op|
                if op.input(FP).val == MTURQ then settings = {expect: "green", filter: "Yellow", gun: "Blue"} end
                if [MCHERRY].include? op.input(FP).val then settings = {expect: " orange/red", filter: "Red", gun: "Green"} end
                plate = op.input(INPUT).item

                show do 
                    title "Screen plate #{plate.id}"
                    note "Correct colonies will glow bright #{settings[:expect]}"
                    note "Switch the lightsource to #{settings[:gun]} and put on the #{settings[:filter]} glasses"
                    note "Shine the light on each colony on the plate in turn"
                    note "Use a sharpie to circle <b>up to #{limit}</b> correct colonies as you go"
                    note "Label colonies using the format c[#] e.g. c1, c2"
                end

            end
            
            trafo_plate_ops.each do |op|
                plate = op.input(INPUT).item
                strain = op.input(INPUT).sample
                
                num = show do 
                    title "How many correct colonies, from 0 to #{limit}, were circled on plate #{plate.id}"
                    get "number", var: "cc", label: "Number of correct colonies", default: 3
                end
                
                cc_array = []
                n = 1
                
                if num[:cc] == 0
                    op.error :no_correct_colonies, "No correct colonies on the plate"
                else
                    num[:cc].times do 
                        cc_array.push("c#{n}")
                        n = n + 1
                    end
                    
                    plate.associate ASSOCIATION_KEY.to_sym, cc_array
                    
                    unless debug
                        qc_answer =  FieldValue.where(parent_id: strain.id, parent_class: "Sample", name: "Has this strain passed QC?").first
                        qc_answer.value = "Yes"
                        qc_answer.save 
                    end
                end
                
            end
        end
        
        #-------- Screen Collection Ops -----------#
        def screen_qc_plate_ops(qc_plate_ops)
            
            qc_plate_ops.each do |op|
                
                master_plate = check_for_master_plate(op, op.input(INPUT).item)
                
                num_colonies = get_num_colonies(op.input(INPUT).item)
                
                correct_colonies = screen_plate(op, op.input(INPUT).item, num_colonies)
                
                associate_correct_colonies(op, correct_colonies, op.input(INPUT).item, master_plate)
                
                discard_plate(op.input(INPUT).item)
            
            end
        end
        
        #----------------------------------------#
        
        def check_for_master_plate(op, plate)
            
            if debug then plate.associate MASTER_PLATE_KEY.to_sym, 12345 end
            
            master_plate_id = plate.get(MASTER_PLATE_KEY.to_sym)
            
            if master_plate_id.nil?
                op.error :no_master_plate, "There's no master plate for this operation to refer to "
                show do 
                    note "No Master Plate association for this plate"
                    note "Notify user #{op.user.name}"
                end
            else
                master_plate = Item.find(master_plate_id)
                return master_plate
            end
        
        end
        
        #----------------------------------------#
       
        def get_num_colonies(plate)
             if debug then plate.associate NUM_COLONIES_KEY.to_sym, 6 end
            return plate.get(NUM_COLONIES_KEY.to_sym)
        end
        
        #----------------------------------------#
       
        def screen_plate(op, plate, num_colonies)

            if op.input(FP).val == MTURQ then settings = {expect: "green", filter: "Yellow", gun: "Blue"} end
            if [MCHERRY].include? op.input(FP).val then settings = {expect: " orange/red", filter: "Red", gun: "Green"} end
            test_cc_array = Array (1..num_colonies.to_i)
            
            show do 
                title "Screen QC test plate #{plate.id}"
                note "Correct colonies will glow bright #{settings[:expect]}"
                note "Switch the lightsource to #{settings[:gun]} and put on the #{settings[:filter]} glasses"
                check "Check the colony patches labelled positive and negative control to get a frame of reference"
                note "Use the labelled neg and pos controls on the plate as reference points"
            end
            
            res = show do
                title "Check test colonies"
                note "Check each of the labelled test colonies on the plate"
                test_cc_array.each do |c|
                    note "Colony #{c}"
                    select ["Yes","No"], var: "#{c}".to_sym, label: "Correct?", default: 0
                end
            end
            
            cc_array = []
            test_cc_array.each do |c|
                if res["#{c}".to_sym] == "Yes"
                    cc_array.push("c#{c}")
                end
            end
            
            return cc_array
        end
        
        #----------------------------------------#
        def associate_correct_colonies(op, correct_colonies, plate, master_plate)
            
            master_plate.associate ASSOCIATION_KEY.to_sym, correct_colonies
            op.associate ASSOCIATION_KEY.to_sym, correct_colonies
            strain = op.input(INPUT).sample
            
            if debug
                show do 
                    title "Sanity check"
                    note "Master plate: #{master_plate.id}"
                    note "correct colony association:#{master_plate.get(ASSOCIATION_KEY.to_sym)}"
                end
            end
            
            if correct_colonies.empty? 
                op.error :no_correct_colonies, "No correct colonies for this plate" 
            else 
                unless debug
                    qc_answer =  FieldValue.where(parent_id: strain.id, parent_class: "Sample", name: "Has this strain passed QC?").first
                    qc_answer.value = "Yes"
                    qc_answer.save 
                end
            end
            
        end
        
        #----------------------------------------#
        
        def discard_plate(plate)
            
            show do 
                title "Discard plate #{plate.id}"
                check "Discard plate #{plate.id} in Biohazard waste"
            end
            
            plate.mark_as_deleted
            plate.save
        end

end

