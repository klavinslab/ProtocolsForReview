needs "Plant Work/Plant Work Training"
needs "Plant Work/Plant Work General"
needs "Standard Libs/Add Output"

class Protocol

include Training
include General
include AddOutput

  def main

        standard_PPE
        
        if training_mode? == "Yes"
                training_mode_on = true
            else 
                training_mode_on = false
        end
        
        operations.each do |op|
            sample = Sample.find_by_name("YEB medium")
            container = "#{op.input("Volume").val} mL #{op.input("Media type").val}"
            add_output op,"Media", sample, container
        end
        
        operations.make
        
        liquids = operations.select {|op| op.output("Media").object_type.name.include? "Liquid"}
        solids = operations.select {|op| op.output("Media").object_type.name.include? "Agar"}
        larges = operations.select {|op| op.output("Media").object_type.name.include? "400"}
        smalls = operations.select {|op| op.output("Media").object_type.name.include? "200"}
        
        show do
            title "Overview"
            note "You will be making:#{liquids.length} bottles of Liquid YEB and #{solids.length} bottles of solid YEB media"
            note "Go to the media bay to begin work"
        end
        
        if training_mode_on
          media_bay_ground_rules
        end

	    show do
            title "Gather ingredients"
            check "Beef extract (Media bay, cabinet)"
            check "Yeast extract (Media bay, cabinet)"
            check "Peptone (Big white bottle on shelf by media bay cabinet)"
            check "Sucrose (Chemical cabinet, S)"
            check "Magnesium chloride hexahydrate (Chemical cabinet, M)"
                if solids.length > 0 
                    check "Bactoagar (Media bay, shelf)"
                end
	    end 
	    
	    show do 
	        title "Gather and label bottles"
            note "#{larges.length} 500 mL glass bottles"
             note "Label bottle with 'YEB agar', the date and your initials as well as their unique IDs."
                larges.each do |lrg|
                    check "label #{lrg.output("Media").item.id}"
                end
            note "Gather #{smalls.length} 250 mL glass bottles"
                note "Label bottle with 'YEB agar', the date and your initials as well as their unique IDs."
                    smalls.each do |sm|
                        check "label #{sm.output("Media").item.id}"
                    end
        end
            
	   show do
		    title "Weigh out Beef extract"
			 larges.each do |lrg|
                    check "2g into bottle #{lrg.output("Media").item.id}"
                end
             smalls.each do |sm|
                        "1g into bottle #{sm.output("Media").item.id}"
                end 
		end
		
		show do
		    title "Weigh out Peptone"
			 larges.each do |lrg|
                    check "2g into bottle #{lrg.output("Media").item.id}"
                end
             smalls.each do |sm|
                        "1g into bottle #{sm.output("Media").item.id}"
                end 
		end
		
		show do
		    title "Weigh out Sucrose"
			 larges.each do |lrg|
                    check "2g into bottle #{lrg.output("Media").item.id}"
                end
            smalls.each do |sm|
                "1g into bottle #{sm.output("Media").item.id}"
            end 
		end
		
		
		
		show do
		    title "Weigh out Yeast extract"
			 larges.each do |lrg|
                    check "0.4g into bottle #{lrg.output("Media").item.id}"
                end
            smalls.each do |sm|
                "0.2g into bottle #{sm.output("Media").item.id}"
            end 
		end
			

		 show do
		  title "Weigh out Magnesium chloride"
		    larges.each do |lrg|
                check "0.2g into bottle #{lrg.output("Media").item.id}"
            end
            smalls.each do |sm|
                "0.1g into bottle #{sm.output("Media").item.id}"
            end
        end
        
        if solids.length > 0
            show do 
                title "Weigh out Bactoagar"
                larges.each do |lrg|
                    if lrg.output("Media").object_type.name.include? "Agar"
                        check "0.2g into bottle #{lrg.output("Media").item.id}"
                    end
                end
                smalls.each do |sm|
                    if sm.output("Media").object_type.name.include? "Agar"
                        "0.1g into bottle #{sm.output("Media").item.id}"
                    end
                end
            end
        end
                
		    
	    show do
		    title "Add DI Water"
		    check "Take the bottles to the DI water carboy "
		    larges.each do |lrg|
		        check "Fill bottle #{lrg.output("Media").item.id} to the 400 mL mark"
		    end
		    smalls.each do |sm|
		        check "Fill bottle #{sm.output("Media").item.id} to the 200 mL mark"
		    end
	    end
		    
	    show do
		    title "Finish up"
		    check "Seal lids"
		    check "Shake well to mix ingredients"
		    check "Place autoclave tape on each lid and place all in the plastic bin by the lab autoclave"
		    warning "Make sure the lids are unscrewed a few turns (i.e. only loosely secured) to prevent shattering in the autoclave."
	    end
		
		    return {}
        end
    end