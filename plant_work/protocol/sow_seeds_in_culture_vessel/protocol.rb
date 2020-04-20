#Protcol first drafted by Xavaar Quaranto. Largely rewritten by Orlando de Lange 02.06.2020

class Protocol

    INPUT1 = "Seeds"
    INPUT2 = "Culture vessel"
    OUTPUT = "Seedlings"
    
    REAGENT_LOC = "top right draw under the grow tent"
    
    VOL = 400
    MIX = "Shake each tube back and forth with lid closed till seeds become dispersed"
    COTTONSWAB = true
    COTTONSWAB_INSTRUCTIONS = "Use a sterile cotton swab to disperse any clumps of seeds, aiming to achieve single seeds not touching any others"
    
    
    IMPLEMENT_OPTIONS = ["sterile bulb syringe pipette", "p1000 pipette with fresh tip"]
    IMPLEMENT = IMPLEMENT_OPTIONS[1]
    GOAL_OPTIONS = ["singles", "patches"]
    GOAL = GOAL_OPTIONS[1]
    
    FLOW = "Flow hood"
    STER_TIME = "Sterilization_time"
    LIGHTING = "Light_regime"

    
  def main
    
    operations.make
    
    sow_seeds
    
    place_jars_in_growth_chamber
    
    clean_up
    
    associate_data
    
    operations.store(interactive: false)
    
    {}

  end
##-------------------------------------------## 

    def sow_seeds
        
        flow_hood_ops = operations.select{|op| op.input(FLOW).val == "Yes"}
        no_hood_ops = operations.select{|op| op.input(FLOW).val == "No"}
        
        unless flow_hood_ops.empty?
            gather_materials(flow_hood_ops)
            move_to_flow_hood
            sterilize_and_sow_seeds(flow_hood_ops)
        end
        
        unless no_hood_ops.empty?
            gather_materials(no_hood_ops)
            sterilize_and_sow_seeds(no_hood_ops)
        end
        
    end
    
    def gather_materials(ops)
        
        non_zero_ops = ops.select{|op| op.input(STER_TIME).val != 0}
        
        show do 
            title "Gather and relabel Jars of Plant Media"
            ops.each do |op|
                check "One jar of Plant media #{op.input(INPUT2).sample.name} from batch #{op.input(INPUT2).collection.id} in #{op.input(INPUT2).item.location}"
                check "Label the jar #{op.output(OUTPUT).item.id}"
                note "---"
            end
        end
        
        show do 
            title "Gather and relabel seedstock aliquots"
            ops.each do |op|
                check "One tube of seeds from batch #{op.input(INPUT1).collection.id} of #{op.input(INPUT1).sample.name} seedstock aliquots in #{op.input(INPUT1).item.location}"
                check "Label the tube of seeds #{op.output(OUTPUT).item.id % 1000}"
                note "---"
            end
        end
        
        show do 
            title "Gather materials for sowing"
            unless COTTONSWAB == false
                check "A batch of sterile cotton swabs, containing at least #{ops.length} swabs"
            end
            check " A bottle of sterile distilled water from check #{REAGENT_LOC}"
            unless non_zero_ops.empty?
                check "A bottle of 70% Ethanol from #{REAGENT_LOC}"
                check "A bottle of 10% bleath from #{REAGENT_LOC}"
            end
        end
    end
    
    
    def move_to_flow_hood
        
        show do
            title "Move to flow hood"
            note "Take all the materials gathered in the previous step, and move to the flow hood in the Side room"
            note "Open the flow hood, turn on the light"
            note "With 70% ethanol spray and wipe down the surface of the flow hood and everything you are placing into the flow hood"
            note "Remember to work slowly and carefully, away from the front of the hood"
        end
        
    end
    
    def sterilize_and_sow_seeds(ops)
        
        zero_ops = ops.select{|op| op.input(STER_TIME).val == 0}
        non_zero_ops = ops.select{|op| op.input(STER_TIME).val != 0}
        
        
        unless non_zero_ops.empty?
            sterilize(non_zero_ops)
        end

        add_seeds_to_jars(ops)

    end
    
    def sterilize(ops)
        
        ster_groups = ops.group_by{|op| op.input(STER_TIME).val}
        # x is now a hash containing keys which are the parameter values, and values which are the lists of operations that correspond to the parameter value. 
        # x.each do |group| ==> group[0] is the grouping value, group[1] is the list of operations
        
        ster_groups.each do |x|
            add_reagent(x[0],x[1], "70% Ethanol")
            wash(x[1])
            add_reagent(x[0],x[1], "10% Bleach")
            wash(x[1])
        end
        
    end
    
    def add_reagent(time,ops,reagent_name)
          
        show do 
            title "Add #{reagent_name}"
            check "Add #{VOL} uL of #{reagent_name} to each of the following tubes:"
            ops.each do |op|
                bullet "#{op.output(OUTPUT).item.id % 1000}"
            end
            check MIX
            check "Close lids and slowly and steadily invert the tubes in your hands for #{time} minutes"
            timer initial: { hours: 0, minutes: time, seconds: 0}
        end
    end
        
    
    def wash(ops)
        
        tube_list = []
        ops.each{|op| tube_list.push(op.output(OUTPUT).item.id % 1000)}
        
        show do 
            title "Wash seeds"
            note "Do the following for tubes #{tube_list}"
            check "Remove previous reagent into the waste beaker"
            2.times do 
                check "Add #{VOL} uL sterile water to each tube"
                check "Invert twice, allow seeds to settle"
                check "Discard water"
            end
        end
        
    end
        
    
    
    def add_seeds_to_jars(ops)
        
        show do 
            title "Add water to seed tubes"
            ops.each do |op|
                check "Add #{VOL} of sterile distilled water into tube #{op.output(OUTPUT).item.id % 1000}"
            end
        end
        
        show do 
          title "Sow seeds"
          note "Use a fresh p1000 pipette tip for each transfer. Pipette up and down twice to mix the seeds and then transfer in scattered drops into the jar. Aim to transfer all the seeds, but its ok if a few remain in the tube"
          ops.each do |op|
             check " Seeds from #{op.output(OUTPUT).item.id % 1000} into #{op.output(OUTPUT).item.id}"
          end
        end
        
        unless COTTONSWAB == false
            show do 
                title "Disperse seeds"
                note "Use an unused end of a sterile cottonswab. Gently wipe the cottonswab over the surfrace of the media first lengthwise then from top to bottom. The goal is to disperse the seeds to the point where seeds are evenly distributed and none are touching. This goal is hard to achieve in practice, so disperse as best you can. Don't drag the swab too forcefully through the media or the gel will break apart."
                ops.each do |op|
                    check "Disperse seeds from in #{op.output(OUTPUT).item.id}"
                end
            end
        end
    end
    
        
  ##-------------------------------------------##       


      def associate_data
            operations.each do |op|
              op.output(OUTPUT).item.associate :flow, op.input(FLOW).val
              op.output(OUTPUT).item.associate :ster_time, op.input(STER_TIME).val
              op.output(OUTPUT).item.associate :light_regime, op.input(LIGHTING).val
            end
        end
        
    ##-------------------------------------------##    
    def place_jars_in_growth_chamber
        
        show do 
            title "Place jars into growth chamber"
            note "The desired lighting conditions are displayed for each jar of seeds. If these are either different from each other, or are different from the current settings of the growth chamber, please alert the indicated user"
            operations.each do |op|
                check "Jar #{ op.output(OUTPUT).item.id} to #{op.output(OUTPUT).item.location}"
                note "Desired lighting is #{op.input(LIGHTING).val}. Operations submitted by user #{op.user.name}"
            end
        end
        
    end
    
    def clean_up
        
        show do 
            title "Clean up"
            check "Discard seed aliquot tubes into biohazard waste"
            note "Return all materials used in the protocol"
            note "If you used the flow hood wipe it down with ethanol and turn off light and blower, and close front pane"
        end
    end
    
    ##-------------------------------------------##  

end

