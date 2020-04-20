

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol
    
  INPUT = "Plate"
  OUTPUT = "Checked plate"
  OUTPUT_OT_NAME = "Checked E coli Plate of Plasmid"
  NIGHTSEA_STORAGE = "in labelled draw near to gel dock"
  WORK_ROOM = "Lab Equipment Room 380B"
  FP = "Fluorescent protein"
  MCHERRY = "mCherry"
  MTURQ = "mTurq"
  EC_PINK = "ecPink"
  SELECTION_METHOD = "Selection"
  NEG = "Negative"
  POS = "Positive"
  CORRECT_COLONY_UPPER_LIMIT = 5
  ASSOCIATION_KEY = "Correct_colonies"
  MASTER_PLATE_KEY = "master_plate_id"
  
    def main
        gather_materials
        
        estimate_colonies
        
        screen_plates
        
        reassign_as_outputs

        operations.store
            
    
        {}

    end
    
    def reassign_as_outputs
        operations.each do |op|
            plate = op.input(INPUT).item
            checked_ot = ObjectType.find_by_name(OUTPUT_OT_NAME)
            plate.object_type_id = checked_ot.id
            plate.save
            op.output(OUTPUT).set item: plate
            plate.store
        end
    end
    
    def estimate_colonies
        
        info = show do
          title "Estimate colony numbers"
          operations.each do |op|
            plate = op.input("Plate").item
            get "number", var: "n#{plate.id}", label: "Estimate how many colonies are on #{plate}", default: 5
            select ["normal", "contamination", "lawn"], var: "s#{plate}", label: "Choose whether there is contamination, a lawn, or whether it's normal."
          end
        end    
        
        operations.each do |op|
          plate = op.input("Plate").item
          if info["n#{plate.id}".to_sym] == 0
            plate.mark_as_deleted
            plate.save
            op.temporary[:delete] = true
            op.error :no_colonies, "There are no colonies for plate #{plate.id}"
          else
            plate.associate :num_colonies, info["n#{plate.id}".to_sym]
            plate.associate :status, info["s#{plate.id}".to_sym]
          end
        end
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

           screen_trafo_ops(CORRECT_COLONY_UPPER_LIMIT)
                
        end
        
    #-------- Screen Trafo Ops -----------#
        def screen_trafo_ops(limit)
            
            operations.each do |op|
                
                if op.input(FP).val == MTURQ then settings = {expect: "green", filter: "Yellow", gun: "Blue"} end
                if [MCHERRY, EC_PINK].include? op.input(FP).val then settings = {expect: " orange/red", filter: "Red", gun: "Green"} end
                plate = op.input(INPUT).item

                show do 
                    title "Screen plate #{plate.id}"
                    if op.input(SELECTION_METHOD).val == POS
                        note "Correct colonies will glow bright #{settings[:expect]}"
                    elsif op.input(SELECTION_METHOD).val == NEG
                        note "Correct colonies are those that <b>do not</b> glow bright #{settings[:expect]}"
                    end
                    note "Switch the lightsource to #{settings[:gun]} and put on the #{settings[:filter]} glasses"
                    note "Shine the light on each colony on the plate in turn"
                    note "Use a sharpie to circle <b>up to #{limit}</b> correct colonies as you go"
                    note "Label colonies using the format c[#] e.g. c1, c2"
                end

            end
            
             operations.each do |op|
                plate = op.input(INPUT).item
                
                num = show do 
                    title "How many correct colonies, from 0 to #{limit}, were circled on plate #{plate.id}"
                    get "number", var: "cc", label: "Number of correct colonies", default: 3
                end
                
                cc_array = []
                n = 1
                num[:cc].times do 
                    cc_array.push("c#{n}")
                    n = n + 1
                end
                
                plate.associate ASSOCIATION_KEY.to_sym, cc_array
            end
        end

end
