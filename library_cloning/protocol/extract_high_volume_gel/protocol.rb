# Extract Fragment Protocol
# V1.0.2; 2017-07-17 JV
# Written by Ayesha Saleem
# Revised by Justin Vrana 2017-07-13; corrected upload issue
# Revised by Justin Vrana 2017-07-17; unique upload table
# SG simplified for high-volume extraction 2017-12-12
# no batching needed for high volume - entire gel contains one fragment
needs "Standard Libs/UploadHelper"

class Protocol
    
    include UploadHelper

    # I/O
    INPUT="Fragment"
    OUTPUT = "Fragment in gel slices"
    EXPECTED_LENGTH="expected length (bp)"
    
    # other params
    NUM_TUBES= 4 # number of 1.5 mL tubes needed to hold slices from 1 gel box. 8 slices total, 2 slices per tube
    MAX_WEIGHT_G = 0.7 # g, can fit ~700mg + 700ul into 1.5 tube for purification  
    GEL_DIR="/bioturk/Dropbox/GelImages/" # dir where gel images are saved on computer
    
    def main
        
        # get stuff
        operations.retrieve(interactive: false)
        
        operations.each do |op|
                
            # image gel    
            show do
                title "Image gel #{op.input(INPUT).item} (pre-extract)"
                check "Clean the transilluminator with ethanol."
                check "Put the gel #{op.input(INPUT).item} on the transilluminator."
                check "Turn off the room lights before turning on the transilluminator."
                check "Put the camera hood on, turn on the transilluminator and take a picture using the camera control interface on computer."
                check "Check to see if the picture matches the gel before uploading."
                check "Rename the picture you just took exactly as <b>gel_bef_#{op.input(INPUT).item}</b>."
            end
            
            # upload of image BEFORE cutting from gel
            ups = uploadData("#{GEL_DIR}gel_bef_#{op.input(INPUT).item}", 1, 3) # 1 image, 3 tries
            if(ups.nil?) # should not happen!
                show {note "no uploads, nothing to associate..."}
                #return
            end
            if(!ups.nil?)
                up_bef=ups[0]
            end
            
            # data associations - "BEFORE" gel image
            if(!up_bef.nil?)
                op.plan.associate "gel_image_bef", "combined gel fragment", up_bef
                op.input(INPUT).item.associate "gel_image_bef", up_bef
                # can't associate with output now because it was not made yet
            end
            
            # display expected length and have tech verify that length         
            tab_length = [ [ "Gel ID", "Expected length (bp)"] , [ "#{op.input(INPUT).item}", "#{op.input(EXPECTED_LENGTH).val.round}"] ] 
            length_ver = show do
                title "Verify Fragment Lengths for gel #{op.input(INPUT).item}"
                table tab_length
                select [ "Yes", "No"], var: "choice", label: "Is length correct?", default: 0 # default is "Yes" so test will run
            end
            
            # error op if fragment does not match expected length
            if(length_ver[:choice]=="No")
                op.error :incorrect_length, "The fragment did not match the expected length."
            end
        
        end # operations.each
             
        # make for ok lengths only
        operations.running.make
            
        # continue for ok lengths only    
        operations.running.each do |op|
             
            # extract gel slices
            show do
                title "Cut out fragments"
                check "Take out #{NUM_TUBES} 1.5 mL tubes."
                check "Label unmarked tubes: <b>#{1}</b> to <b>#{NUM_TUBES}</b>"
                check "Cut out the bands of length <b>#{op.input(EXPECTED_LENGTH).val.round} bp</b>. Place <b>two</b> bands into each labeled 1.5 mL tube"
            end
            
            # upload of image AFTER cutting from gel
            # image gel    
            show do
                title "Image gel #{op.input(INPUT).item} (post-extract)"
                check "Clean the transilluminator with ethanol."
                check "Put the gel #{op.input(INPUT).item} on the transilluminator."
                check "Turn off the room lights before turning on the transilluminator."
                check "Put the camera hood on, turn on the transilluminator and take a picture using the camera control interface on computer."
                check "Check to see if the picture matches the gel before uploading."
                check "Rename the picture you just took exactly as <b>gel_aft_#{op.input(INPUT).item}</b>."
            end
            
            # uplaod "AFTER" gel image
            ups = uploadData("#{GEL_DIR}gel_bef_#{op.input(INPUT).item}", 1, 3)
            if(ups.nil?) # should not happen!
                show {note "no uploads, nothing to associate..."}
                #return
            end
            # data associations - "AFTER" gel image
            if(!ups.nil?)
                up_aft=ups[0]
            end
            if(!up_aft.nil?)
                op.plan.associate :gel_image_aft, "combined gel fragment", up_aft  # upload association
                op.input(INPUT).item.associate "gel_image_aft", up_aft        # regular association
                op.output(OUTPUT).item.associate "gel_image_aft", up_aft      # regular association
                op.output(OUTPUT).item.associate "gel_image_bef", op.input(INPUT).item.get(:gel_image_bef)      # can associate now that output exists
            end
            
            # divide slices
            data = show do
                title "Weigh tubes"
                note "Perform this step using the scale inside the gel room"
                note "The goal of the following is to have slightly less than #{MAX_WEIGHT_G} g of extracted gel in each of 1.5 mL tube. If necessary, transfer gel between tubes or label and weigh additional tubes."
                check "Zero the scale with an empty 1.5 mL tube"
                check "Weigh tubes <b>#{1}</b> to <b>#{NUM_TUBES}</b>"
                check "If the weight is greater than #{MAX_WEIGHT_G} g, carefully transfer some of the gel slice to a tube with less material and reweigh tubes"
                note "If you need additional 1.5 tubes to contain the slices, label them <b>#{NUM_TUBES+1}</b>, etc."
                check "Write each tube's weight on the side of each tube"
                note "Make sure each tube weighs less than #{MAX_WEIGHT_G} g"
                check "Turn off scale"
                get "number", var: "num_tubes", label: "Enter the number of 1.5 mL tubes containing slices", default: NUM_TUBES
            end
            op.output(OUTPUT).item.associate "number_of_tubes", data[:num_tubes]
            
            # purify or store 
            choice = show do 
                title "Please select from the following:"
                select ["Yes", "No"], var: "choice", label: "Would you like to purify the gel slices immediately?"
            end
            if choice[:choice] == "Yes"
                op.output(OUTPUT).item.move("Bench")
            else
                show do
                    title "Group gel slices and label"
                    check "Tape 1.5 mL tubes containing the gel slices together using lab tape. On the tape, label them #{op.output(OUTPUT).item}"
                    op.output(OUTPUT).item.move("4C Fridge")
                end
            end
            
            # data associations - choice, 2nd gel image
            op.plan.associate :choice, choice[:choice] # purify now or later
            
            # locations
            op.input(INPUT).item.mark_as_deleted   # delete gel item
            
        end # operations.running.each
        
        # clean up
        show do
            title "Clean Up"
            check "Turn off the transilluminator."
            check "Dispose of the gel and any gel parts by placing it in the waste container. Spray the surface of the transilluminator with ethanol and wipe until dry using a paper towel."
            check "Remove the blue light goggles, clean them, and put them back where you found them."
            check "Clean up the gel box and casting tray by rinsing with water. Return them to the gel station."
            check "Dispose gloves after leaving the room."
        end
        
        operations.store
            
        return {}
        
    end # main
    
end # protocol
