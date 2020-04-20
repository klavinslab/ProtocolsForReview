#Xavaar

class Protocol

    INPUTOUTPUT = 'Duckweed Container'
    PLANTMEDIA = "Media"
    
    
    KEEP = 'Keep Jar'
    
    
    LIMIT = 2 #Limit to the # of Duckweed vessals that will be kept in the inventory before automati disposal
    

    DEFAULTWEIGHT = -1.0
    CONTAINER = "Plate"
    
  def main
      
        operations.retrieve.make
        
        imageContainers('Old')
        
        labelVessals
        
        weighStuff(1) #Each time this function is called you have to pass it an arbtrary label so it stores the infor it gathers under a uniqe label
        
        splitDWJar
        
        weighStuff(2)
        
        associateValues
        
        imageContainers('Old')
        
        imageContainers('New')
        
        discard
        
        operations.store
        
        {}

  end
  
  
  def labelVessals
      show do
          title "Check Media Volume"
          note " PUT A CHECK VOLUME STEP HERE"
      end
      
      show do
          title "Pour and Label Media #{CONTAINER}s"
          check "Gather #{operations.length} #{CONTAINER}s from PLACE"
          check "Use media from #{operations[0].input(PLANTMEDIA).item.id} to fill each #{CONTAINER} to the fill line."
          note "Label #{CONTAINER}s according to the following table"
          table operations.start_table
            .custom_column(heading: "Labels", checkable: true) { |op| "#{op.output(INPUTOUTPUT).item.id}"}
            .end_table
        end
        
    end

    def weighStuff(aID)
        
        show do 
            title "Move to Weighstation"
            note "Put everything on the cart and go to the scale in the media bay"
        end
        
        dw = "dwWeight#{aID}"
        mj = "mjWeight#{aID}"
        
        if aID == 1
            jar1 = "#{CONTAINER} of Duckweed"
            jar2 = "Media #{CONTAINER}"
        else
            jar1 = "Old #{CONTAINER} of Duckweed"
            jar2 = "New #{CONTAINER} of Duckweed"
        end
        
        check = true
        
        while check == true
            show do 
                title "Weigh #{CONTAINER}s"
                note "Weigh each <b>#{jar1}</b> and enter the weight in the following table"
                table operations.start_table
                    .custom_column(heading: "#{jar1}") { |op| "#{op.input(INPUTOUTPUT).item.id}" }
                    .get(dw.to_sym, type: 'number', heading: "Weight", default: DEFAULTWEIGHT) 
                    .end_table
                note "Weigh each <b>#{jar2}</b> and enter the weight in the following table"
                table operations.start_table
                    .custom_column(heading: "#{jar2}") { |op| "#{op.output(INPUTOUTPUT).item.id}" }
                    .get(mj.to_sym, type: 'number', heading: "Weight", default: DEFAULTWEIGHT) 
                    .end_table
            end
            
            operations.each do |op|
                if  op.temporary[dw.to_sym].to_f > 0 and op.temporary[mj.to_sym].to_f > 0
                    # show do 
                    #     note "false scenario"
                    #     note "#{ op.temporary[dw.to_sym].to_f }"
                    #     note "#{op.temporary[mj.to_sym].to_f}"
                    # end
                    check = false
                else
                    # show do 
                    #     note "True scenario"
                    #     note "#{ op.temporary[dw.to_sym].to_f }"
                    #     note "#{op.temporary[mj.to_sym].to_f}"
                    # end
                    check = true
                end
            end
            
            if check == true
                show do
                    title "Negative Weight Entered"
                    note "It appears you have entered a negative weight or have forgotten to enter a value for one or more item, please reenter values on the next slide"
                end
                if debug
                    show do
                        title "Debug Break"
                    end
                    break
                end
            else
                # show do
                #     note "loop broke"
                # end
                break
            end
        end
    end
    
    def splitDWJar
        
        show do 
            title "Move to the Flow hood"
            note "Gather all #{CONTAINER}s and materials and move to the the flow hood"
            check "Open the flow hood and turn on the lights"
            check "Surface sterilize every item before placing it in the flow hood"
        end
        
        show do
            title "Split Duckweed"
            note "Place the Duckweed culture by its corresponding media #{CONTAINER} as shown in the following table and transfer half of the duckweed into the new media #{CONTAINER}"
            table operations.start_table 
              .custom_column(heading: "#{CONTAINER} of Duckweed") { |op| "#{op.input(INPUTOUTPUT).item.id}" }
              .custom_column(heading: "Media #{CONTAINER}") { |op| "#{op.output(INPUTOUTPUT).item.id}" }
              .custom_column(heading: "CheckBoxes", checkable: true) { |op| "+" }
              .end_table
        end
        
        show do
            title "Clean Up Flow Hood"
            note "Remove all your materials from the flow hood"
            check "Wipe down are surfaces in the flow hood"
            check "Close the flowhood and turn off the lights"
        end
    end

    def associateValues

        operations.each do |op|
            
            
            mjWeightDict = {}
            #This is to onboard objects created before this protocol was implemented, and work in the test mode
            if not op.input(INPUTOUTPUT).item.associations.has_key?(:wet_weights)
                dwWeightDict = {}
            else
                dwWeightDict =  op.input(INPUTOUTPUT).item.associations[:wet_weights]
            end

            mjWeightDict[Time.zone.now] = op.temporary[:mjWeight1].to_f
            dwWeightDict[Time.zone.now] = op.temporary[:dwWeight1].to_f
            sleep(1)
            mjWeightDict[Time.zone.now] = op.temporary[:mjWeight2].to_f
            dwWeightDict[Time.zone.now] = op.temporary[:dwWeight2].to_f
            
            
            op.input(INPUTOUTPUT).item.associate :wet_weights, dwWeightDict
            op.output(INPUTOUTPUT).item.associate :wet_weights, mjWeightDict

            items = Item.where(sample_id: op.input(INPUTOUTPUT).sample.id , object_type_id: op.input(INPUTOUTPUT).item.object_type.id).reject {|i| i.location == "deleted"}
           
           #Checks if ther are more than the threshold # of items in inventory and if the user wants to keeep the item
            if items.length > LIMIT and op.input(KEEP).to_s == "No"
                op.input(INPUTOUTPUT).item.mark_as_deleted
            end
            


        end
    end
    
    # Need to work on this image upload
   
    def imageContainers(type)
        
        #This is so when you take pictures of the input jars for the second time in the operation it only takes pictures of those which haven't been deleted
        if type == 'Old'
            operationZ = operations.select { |op| op.input(INPUTOUTPUT).item.location != "deleted" }
            opInOut = "op.input(INPUTOUTPUT)"
        elsif type == 'New'
            operationZ = operations
            opInOut = "op.output(INPUTOUTPUT)"
        end
        
        #This is a list of item ids to check the pictures labels against
        idList = []
        operationZ.each do |op|
            idList << eval(opInOut).item.id
        end
        
        redFlag = true
        while redFlag == true #This loop should never run more thatn once in test simulation because test automatically labels everything perfect
            redFlag = false #Starts as true to start the loop but immediatly changes to false
            
            #This is to account for multiple images taken on the same day, its needs to be expanded more to be recursive or something
            
            dwImages = show do 
                title "Image the <b>#{type}</b> #{CONTAINER}s of Duckweed"
                note "Image each of the following <b>#{type}</b> #{CONTAINER}s from above"
                note "As you take each image label it with the format <b>'#{Date.today}_ItemID'</b> and save it under TDB"
                warning "Double Check to make sure each picture is labled correcty, if not the Protocol will Crash."
                table operationZ.start_table
                    .custom_column(heading: "#{type} #{CONTAINER}s" ,checkable: true) { |op| "#{eval(opInOut).item.id}"}
                    .end_table
                note "Upload the images"
                upload var: :images
            end
            
            if debug
                images = []
                operationZ.each do |op|
                    images << {name:"#{Date.today}_#{eval(opInOut).item.id}.jpg",id:5555}
                end
                dwImages = {}
                dwImages[:table_inputs] = []
                dwImages[:images] = images
                dwImages[:timestamp] = "The time i guess..."
            end
            
            if debug
                show do 
                    title "Debug picture Hash Check"
                    note "#{dwImages}"
                end
            end
            ##This is was dwImages acutally looks like when its running
            #{:table_inputs=>[], :images=>[{:name=>"2020-03-23_458446.png", :id=>42361}], :timestamp=>1584988862.39}
            
            #All this is to make sure the user uploades images exactly how they are supposed to
            imageNameList = []
            dwImages[:images].each do |i|
                imageNameList << i[:name]
            end
            
            misLabledList =[]
            idList.each do |id|
                check = false
                imageNameList.each do |iN|
                    iN = iN.to_s
                    if iN.include?("_#{id.to_s}")
                        check = true
                        break
                    end
                end
                
                if check == false
                    redFlag = true
                    misLabledList << id.to_s
                end
            end
            
            if redFlag == true
                show do 
                    title "Incorrect Image Upload"
                    note "The images for the following items were either mislabled or not uploaded. Please re-label the images and try again"
                    misLabledList.each do |i|
                        check "#{i}"
                    end
                end
            end
            
            if debug and redFlag == true
                break 
                show do
                    note" Debug break, but this should never happen anyway..."
                end
            end
        end
        
        operationZ.each do |op|
            if type == 'Old'
                #This is to onboard objects created before this protocol was implemented, and it makes it work in the test mode.
                if not eval(opInOut).item.associations.has_key?(:images)
                    imageDict = {}
                else
                    imageDict =  eval(opInOut).item.associations[:images]
                end
            elsif type == 'New'
                imageDict = {}
            end
            
           # newImage = dwImages[:images].where(name: "#{Date.today}_#{op.input(INPUTOUTPUT).item.id}.jpg") ##Why Can't I use where here idk...
           #This seems like a bad solutions but
            newImage = nil
            dwImages[:images].each do |i|
                if i[:name].include?("#{Date.today}_#{eval(opInOut).item.id}")
                    newImage = i
                    break
                end
            end
            
            imageDict["#{DateTime.now}"] = newImage
            eval(opInOut).item.associate :images, imageDict
        end
        
        if debug
            operations.each do |op|
                show do
                    note"#{eval(opInOut).item.associations[:images]}"
                end
            end
        end
    end
    
    def discard
        
        discardList = operations.select { |op| op.input(INPUTOUTPUT).item.location == "deleted"  }
        
        if discardList.any?
            show do
                title "Discard Duckweed #{CONTAINER}s"
                note "SPECIFIC INSTURCTIONS TO BE INCLUDED"
                table discardList.start_table
                    .custom_column(heading: "#{CONTAINER} of Duckweed") { |op| "#{op.input(INPUTOUTPUT).item.id}" }
                    .end_table
            end
        end
    end

    
### 
end

##Useful Method
# show do
#     note"How to check the number of this type of sample in the system?"
#     note "#{op.input(INPUTOUTPUT).sample.name}"
#     note " #{op.input(INPUTOUTPUT).item.object_type.id}"
#      items = Item.where(sample_id: op.input(INPUTOUTPUT).sample.id , object_type_id: op.input(INPUTOUTPUT).item.object_type.id).reject {|i| i.location == "deleted"}
#      note "#{items.length}"
#     items.each do |i|
#      note "#{i.id}, #{i.location}"
#     end
# end

# Method to remove 1 item per operation from a collection
# s = op.input(VESSAL).sample.id
# col = op.input(VESSAL).collection
# col.remove_one(s)