# SG
# take imgae of streaked plates (verification that strain has no insert before making comp cells)
needs "Standard Libs/UploadHelper"
class Protocol
    
    include UploadHelper
    
    # I/O
    GROWTH_PLATE="Growth Plate"
    CONTROL_PLATE="Control Plate"
    
    # other
    GEL_DIR="/bioturk/Dropbox/GelImages/" # dir where gel images are saved on computer
    
    def main
        
        # get plates
        operations.retrieve
        
        operations.each { |op|
        
        # take images and upload
        show do
            title "Image streaked plates"
            warning "Image <b>BOTH</b> plates at the same time. Make sure the Aquarium IDs are visible in the picture."
            check "Clean the transilluminator with ethanol."
            check "Put plates #{op.input(CONTROL_PLATE).item.id} <b>AND</b> #{op.input(GROWTH_PLATE).item.id} on the transilluminator"
            check "Turn off the room lights before turning on the transilluminator"
            check "Put the camera hood on, turn on the transilluminator and take a picture using the camera control interface on computer"
            check "Check that the Aquarium IDs are visible"
            check "Rename the picture you just took exactly as <b>plates_#{op.input(GROWTH_PLATE).item.id}</b>"
        end
            
        # upload of image 
        ups = uploadData("#{GEL_DIR}plates_#{op.input(GROWTH_PLATE).item.id}", 1, 3) # 1 image, 3 tries
        if(ups.nil?) # should not happen!
            show {note "no uploads, nothing to associate..."}
            #return
        end
        if(!ups.nil?) # associate
            tmp=ups[0]
            up=Upload.find(tmp[:id])
            op.plan.associate :plates_image, "#{tmp[:id]} #{tmp[:name]} plan note", up 
            op.input(CONTROL_PLATE).item.associate "plates_image", ups[0]
            op.input(GROWTH_PLATE).item.associate "plates_image", ups[0]
        end
        
        # update locations
        op.input(CONTROL_PLATE).item.update_attributes(location: "Bench")
        op.input(GROWTH_PLATE).item.update_attributes(location: "Bench")
            
        } # each 
        
        # pass input growth plate to output
        operations.each do |op|
            op.pass(GROWTH_PLATE)
        end
        
        # keep plates on bench 
        operations.store
        
        return {}
        
    end

end
