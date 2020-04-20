class Protocol
   
    MEDIUM = "SDO -Lys -Leu"
    MEDIUM_OBJ = "800 mL Liquid"
    INDUCER = "Beta-estradiol"
    INDUCER_OBJ = "100 uM Stock"
    INPUT = "Small"
    OUTPUT = "Large"
    
    def main
        be = Item.where(sample: Sample.find_by_name(INDUCER), object_type_id: ObjectType.find_by_name(INDUCER_OBJ))
        medium = Item.where(sample: Sample.find_by_name(MEDIUM), object_type_id: ObjectType.find_by_name(MEDIUM_OBJ))


        
        operations.retrieve.make
        
        operations.each do |op|
        
        show do
            title "Transfer overnight"
            check "Take a 1.5 mL tube"
                        #TASK: Fill in this instruction with the item number of the output item.
            check "Label #{op.output(OUTPUT).item.id}"
            check "Using a pipette transfer 1 mL from #{op.input(INPUT).item.id}"
        end
        #######
        show do 
            title "Retrive #{MEDIUM} liquid medium"
            ### Instruction to get medium of a certain object_type, with a certain ID number, from a certain location
            #check "get #{medium.first.id} of #{medium.first.object_type} from #{medium.first.location}"
        end
        
        #############
        2.times do
            show do 
                title "Wash pellet"
                check "Add 1 mL of #{MEDIUM}"
                check "Vortex to resuspend"
                check "Spin down for 1 minute in a tabletop centrifuge"
                check "Discard supernatant."
                check "Resuspend in 1 mL #{MEDIUM}"
            end
        end
        #############
        
        show do
            ### TASK:Instruction to get inducer of a certain object_type, with a certain ID number, from a certain location
            title "Get inducer"
            check "Retrive #{INDUCER} inducer"
            check "Get #{be.first.id} of #{be.first.object_type} from #{be.first.location}"
        end
        
        show do 
            title "Prepare large overnight culture"
            check "Take a 250 mL bevelled glass culture flask"
            check "Add 50 mL of #{MEDIUM}, measured with a measuring cylinder"
            check "Add 50µl of #{INDUCER} "
            check "Label #{op.output(OUTPUT).item.id}"
        end
        
        #TASK: Add a show block with instructions to take 1 mL of INPUT culture and add it to the OUTPUT culture. 
        
        show do
            title "Mixing cultures"
            check "take 1 mL of #{op.input(INPUT).item.id} culture and add it to the #{op.output(OUTPUT).item.id} culture."
        end
        
        show do 
            title "Place flask in the shaker"
            note "You may have to move around the metal flask clamps inside the shaker. Ask for help if unsure"
            check "Place the culture flask #{op.output(OUTPUT).item.id} into the 30C Shaker"
            warning "Check that the  it is held securely in a correctly sized flask clamp."
        end
        


        
        op.input(INPUT).item.mark_as_deleted
        op.input(INPUT).item.save
        op.output(OUTPUT).item.location = "30C Shaker"
        op.output(OUTPUT).item.save
       
    end
        
        
        
        
    end
    
end