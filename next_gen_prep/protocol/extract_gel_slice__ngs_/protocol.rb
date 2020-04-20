# Extract Fragment Protocol
# V1.0.2; 2017-07-17 JV
# Written by Ayesha Saleem
# Revised by Justin Vrana 2017-07-13; corrected upload issue
# Revised by Justin Vrana 2017-07-17; unique upload table
# Revised by SG 05-2018; accepts general gel inputs, does not assume output sample property "Length"

needs "Standard Libs/Feedback"
needs "Next Gen Prep/NextGenPrepHelper"
needs "Standard Libs/UploadHelper"

class Protocol

    include Feedback, NextGenPrepHelper, UploadHelper

    # I/O
    FRAGMENT = "Fragment"
    FRAGMENT_OUT ="Fragment"
    MIN_WEIGHT = 0.0
    MAXWEIGHT = 10.0
    TRIES = 3

    def main

        associate_random_barcodes(operations: operations, in_handle: FRAGMENT) if debug

        # Sort operations by gels and columns (these can get out of order from PCR)
        operations.sort! { |op1, op2|
            fv1 = op1.input(FRAGMENT)
            fv2 = op2.input(FRAGMENT)
            [fv1.item.id, fv1.row, fv1.column] <=> [fv2.item.id, fv2.row, fv2.column]
        }

        # find expected lengths for inputs - may need to add/change cases in the future
        operations.each { |op|
            if(!op.output(FRAGMENT).sample.nil?)
                nm=SampleType.find(op.output(FRAGMENT).sample.sample_type_id).name # sample type
                case nm
                when "Fragment" || "Plasmid" # have sample property "Length"
                    op.temporary[:length] = op.output(FRAGMENT).sample.properties["Length"]
                when "DNA Library" # should have "Library Stock" object_type with associated "length"
                    stock=find(:item,
                                object_type: { name: "Library Stock" },
                                sample: { name: op.output(FRAGMENT).sample.name }
                                ).first
                    if(!stock.nil?)
                        op.temporary[:length] = stock.get(:length)
                    end
                end
            end
        }

        # -----------------new stuff

        sampleToLength = {}

        # this goes through each op, and if this op has a :length symbol AND this op's sample is in
        # not in the hash, then we record the sample id => length
        operations.each do |op|
            if (op.temporary[:length] != nil && !(sampleToLength.key? op.input(FRAGMENT_OUT).sample.id))
                sampleToLength[op.input(FRAGMENT_OUT).sample.id] = op.temporary[:length] 
            end
        end

        # this gets the ops that didnt have a length field.
        # these must be different samples than in the sampleToLength hash, othewise we would have caught it.
        length_unknown=operations.select{|op| op.temporary[:length].nil?}

        # get the samples of the length_unknown list.
        samples_unknown = length_unknown.select{|op| op.input(FRAGMENT).sample}
        samples_unknown.uniq! {|op| op.input(FRAGMENT).sample.id}
        
        # show do
        #     title "debugging"
            
        #     note "length unknown"
        #     length_unknown.each do |op|
        #         note "#{op.input(FRAGMENT_OUT).sample.id}"
        #     end
        #     note "sample unknown"
        #     samples_unknown.each do |op|
        #         note "#{op.input(FRAGMENT_OUT).sample.id}"
        #     end
        # end
        
        
        if(samples_unknown.any?)
            # get lengths for all samples for which length is not defined - ideally this should not be needed!!!
            get_response = show do
                title "Enter the expected lengths in bp for these samples:"
                note "Ask a lab manager if you do not know"
                
                samples_unknown.each do |op|
                    get "number", var: "#{op.input(FRAGMENT).sample.id}", label: "Enter sample length in bp for #{op.input(FRAGMENT).sample.name}", default: "0"
                end
            end

            samples_unknown.each do |op|
                curr_length = get_response["#{op.input(FRAGMENT).sample.id}".to_sym]
                sampleToLength[op.input(FRAGMENT).sample.id] = curr_length
            end
        end

        # --------------end new stuff

        # # ask tech to enter missing lengths
        # length_unknown=operations.select{|op| op.temporary[:length].nil?}
        # if(length_unknown.any?)
        #     # get lengths for all samples for which length is not defined - ideally this should not be needed!!!
        #     show do
        #         title "Enter the expected lengths in bp for these samples:"
        #         note "Ask a lab manager if you do not know"
        #         table length_unknown.start_table
        #             .custom_column(heading: "Sample Name", checkable: true) { |op| op.input(FRAGMENT).sample.name }
        #             .get(:length, type: 'number', heading: "Expected length (bp)")
        #             .end_table
        #     end
        # end

        grouped_by_gel = operations.group_by { |op| op.input(FRAGMENT).collection }

        grouped_by_gel.each do |gel, grouped_ops|
            grouped_ops.extend(OperationList)
            # gel image names
            grouped_ops.each do |op|
                op.temporary[:image_name] = "gel_#{gel.id}"
            end
            
            # ---------------------------------------------IMAGE 
            show do
                title "Image gel #{gel.id}"
                check "Clean the transilluminator with ethanol."
                check "Put the gel #{gel} on the transilluminator."
                check "Turn off the room lights before turning on the transilluminator."
                check "Put the camera hood on, turn on the transilluminator and take a picture using the camera control interface on computer."
                check "Check to see if the picture matches the gel before uploading."
                check "Rename the picture you just took exactly as <b>#{grouped_ops.first.temporary[:image_name]}</b>."
            end
            
            # ---------------------------------------------UPLOAD
            ups = uploadData("/gel_#{gel.id}", 1, TRIES) # 1 file per gel
            image_name = grouped_ops.first.temporary[:image_name]
            # associate to gel, plan, op 
            # can't associate to outputs yet because they are only made if lengths are verified
            up=nil
            if(!(ups.nil?))
              up=ups[0]
        
              gel_item = Item.find(gel.id)
        
              # associate gel image to gel
              gel_item.associate image_name, "successfully imaged gel", up
              
              grouped_ops.each do |op| # associate to all operations connected to gel
                # description of where this op is in the gel, to be used as desc tag for image upload
                location_in_gel = "#{op.input(FRAGMENT).sample.name} is in row #{op.input(FRAGMENT).row + 1} and column #{op.input(FRAGMENT).column + 1}"
                
                # associate image to op with a location description
                op.associate image_name, location_in_gel, up
                
                # associate image to plan, or append new location to description if association already exists
                existing_assoc = op.plan.get(image_name)
                if existing_assoc && op.plan.upload(image_name) == up
                    op.plan.modify(image_name, existing_assoc.to_s + "\n" + location_in_gel, up)
                else
                    op.plan.associate image_name, location_in_gel , up
                end
              end
            end
            
            # ---------------------------------------------VERIFY
            expected_length_table = grouped_ops.start_table
                .custom_column(heading: "Gel ID") { |op| op.input(FRAGMENT).item.id }
                .custom_column(heading: "Row") { |op| op.input(FRAGMENT).row + 1 }
                .custom_column(heading: "Column", checkable: true) { |op| op.input(FRAGMENT).column + 1 }
                .custom_column(heading: "Expected Length") { |op| sampleToLength[op.input(FRAGMENT).sample.id] } #op.temporary[:length]
                .get(:correct, heading: "Does the band match the expected length (y/n)", type: "string", default: "y")
                .end_table
                
            responses = show do
                title "Verify Fragment Lengths for gel #{gel.id}"
                table expected_length_table
            end
            
            grouped_ops.each { |op|
              if(op.temporary[:correct].upcase.start_with?("N"))
                op.error :incorrect_length, "The fragment did not match the expected length."
              end
            }
            
            grouped_ops.select! { |op| op.status == "running"}
            
            grouped_ops.make
            
            # ---------------------------------------------CUT
            qpcr1_ops = grouped_ops.select do |op|
                back_wire = op.input("Fragment").wires_as_dest[0]
                back_wire && FieldValue.find(back_wire.from_id).operation && FieldValue.find(back_wire.from_id).operation.input("Program") &&(FieldValue.find(back_wire.from_id).operation.input("Program").val == "qPCR1")
            end.extend(OperationList)
            qpcr2_ops = (grouped_ops - qpcr1_ops).extend(OperationList)
            
            if qpcr1_ops.any?
                show do
                    title "Cut Out Fragments"
                    note "Take out #{grouped_ops.length} 1.5 mL tubes and label accordingly: #{grouped_ops.map { |op| "#{op.output(FRAGMENT).item}" }.to_sentence}"
                    note "Now, cut out the bands and place them into the 1.5 mL tubes according to the following table:"
                    table qpcr1_ops.start_table 
                        .custom_column(heading: "Gel ID") { |op| "#{op.input(FRAGMENT).item}" }
                        .custom_column(heading: "Row") { |op| op.input(FRAGMENT).row + 1 }
                        .custom_column(heading: "Column", checkable: true) { |op| op.input(FRAGMENT).column + 1 }
                        .custom_column(heading: "1.5 mL Tube ID") { |op| "#{op.output(FRAGMENT_OUT).item}" }
                        .custom_column(heading: "Length") { |op| "#{sampleToLength[op.input(FRAGMENT).sample.id]}"}
                    .end_table
                end
            end
            
            if qpcr2_ops.any?
                show do
                    title "Cut Out Fragments"
                    note "Take out #{grouped_ops.length} 1.5 mL tubes and label accordingly: #{grouped_ops.map { |op| op.output(FRAGMENT).item}.to_sentence}"
                    note "Now, cut out the bands and place them into the 1.5 mL tubes according to the following table:"
                    table qpcr2_ops.start_table
                        .custom_column(heading: "Gel ID") { |op| op.input(FRAGMENT).item.id }
                        .custom_column(heading: "Row") { |op| op.input(FRAGMENT).row + 1 }
                        .custom_column(heading: "Column", checkable: true) { |op| op.input(FRAGMENT).column + 1 }
                        .custom_column(heading: "1.5 mL Tube ID") { |op| op.output(FRAGMENT).item.id }
                        .custom_column(heading: "Length") { |op| "#{sampleToLength[op.input(FRAGMENT).sample.id]}"}
                    .end_table
                end
            end
            # ---------------------------------------------WEIGHT
            # show do
            #     title "Weight Gel Slices"
            #     note "Perform this step using the scale inside the gel room."
            #     check "Zero the scale with an empty 1.5 mL tube."
            #     check "Weigh each slice and enter the weights in the following table:"
            #     table grouped_ops.start_table
            #       .custom_column(heading: "1.5 mL Tube ID") { |op| "#{op.output(FRAGMENT_OUT).item}" }
            #       .get(:weight, type: 'number', heading: "Weight (g)",  default: MIN_WEIGHT)
            #       .end_table
            # end
            
            grouped_ops.each { |op|
                op.output(FRAGMENT_OUT).item.associate(image_name, "Your fragment is in row #{op.input(FRAGMENT).row + 1} and column #{op.input(FRAGMENT).column + 1}", up) 
                op.output(FRAGMENT_OUT).item.associate(:weight, op.temporary[:weight]) 
            }
        end
        
        show do
            title "Weight Gel Slices"
            note "Perform this step using the scale inside the gel room."
            check "Zero the scale with an empty 1.5 mL tube."
            check "Weigh each slice and enter the weights in the following table:"
            table operations.start_table
              .input_item(FRAGMENT, heading: 'Gel ID')
              .custom_column(heading: "1.5 mL Tube ID") { |op| "#{op.output(FRAGMENT_OUT).item}" }
              .get(:weight, type: 'number', heading: "Weight (g)",  default: MIN_WEIGHT)
              .end_table
        end
        
        choice = show do
            title "Clean Up"
            check "Turn off the transilluminator."
            check "Dispose of the gel and any gel parts by placing it in the waste container. Spray the surface of the transilluminator with ethanol and wipe until dry using a paper towel."
            check "Remove the blue light goggles, clean them, and put them back where you found them."
            check "Clean up the gel box and casting tray by rinsing with water. Return them to the gel station."
            check "Dispose gloves after leaving the room."
            grouped_by_gel.each do |gel, grouped_gel|
                gel.mark_as_deleted
            end
            select ["Yes", "No"], var: "choice", label: "Would you like to purify the gel slices immediately?"
        end
        
        operations.running.each do |op|
            txfr_barcode(op, FRAGMENT, FRAGMENT)
            txfr_bin(op, FRAGMENT, FRAGMENT)
        end
        
        if choice[:choice] == "Yes"
            show do
                title "Keep Gel Slices"
                note "Keep the gel slices on your bench to use in the next protocol."
            end
        else
            operations.store
        end

     
        # operations.make

        # split operationlist into ops that have originated from first pcr and those from second pcr.
        # qpcr1_ops = operations.select do |op|
        #     back_wire = op.input("Fragment").wires_as_dest[0]

        #     back_wire && FieldValue.find(back_wire.from_id).operation && FieldValue.find(back_wire.from_id).operation.input("Program") && (FieldValue.find(back_wire.from_id).operation.input("Program").val == "qPCR1")
        # end.extend(OperationList)
        # qpcr2_ops = (operations - qpcr1_ops).extend(OperationList)

        # show do
        #     title "Cut Out Fragments"
        #     note "Take out #{operations.length} 1.5 mL tubes and label accordingly: #{operations.collect { |op| op.output(FRAGMENT).item}.to_sentence}"
        #     note "Now, cut out the bands and place them into the 1.5 mL tubes according to the following table:"
        #     image "Actions/Gel/cut_extra_gel.jpg"
        #     table qpcr1_ops.start_table
        #     .custom_column(heading: "Gel ID") { |op| op.input(FRAGMENT).item.id }
        #     .custom_column(heading: "Row") { |op| op.input(FRAGMENT).row + 1 }
        #     .custom_column(heading: "Column", checkable: true) { |op| op.input(FRAGMENT).column + 1 }
        #     .custom_column(heading: "1.5 mL Tube ID") { |op| op.output(FRAGMENT).item.id }
        #     .end_table
        # end if qpcr1_ops.any?

        # show do
        #     title "Cut Out Fragments"
        #     note "Take out #{operations.length} 1.5 mL tubes and label accordingly: #{operations.collect { |op| op.output(FRAGMENT).item}.to_sentence}"
        #     note "Now, cut out the bands and place them into the 1.5 mL tubes according to the following table:"
        #     table qpcr2_ops.start_table
        #     .custom_column(heading: "Gel ID") { |op| op.input(FRAGMENT).item.id }
        #     .custom_column(heading: "Row") { |op| op.input(FRAGMENT).row + 1 }
        #     .custom_column(heading: "Column", checkable: true) { |op| op.input(FRAGMENT).column + 1 }
        #     .custom_column(heading: "1.5 mL Tube ID") { |op| op.output(FRAGMENT).item.id }
        #     .end_table
        # end if qpcr2_ops.any?

        # min_weight = 0.0
        # max_weight = 10.0

        # gel_slice_table = operations.start_table
        #     .custom_column(heading: "1.5 mL Tube ID") { |op| op.output(FRAGMENT).item.id }
        #     .get(:weight, type: 'number', heading: "Weight (g)")
        #     .end_table

        # show do
        #     title "Weight Gel Slices"
        #     note "Perform this step using the scale inside the gel room."
        #     check "Zero the scale with an empty 1.5 mL tube."
        #     check "Weigh each slice and enter the weights in the following table:"
        #     table gel_slice_table
        # end

        # gels = operations.collect{ |op| op.input(FRAGMENT).item }.uniq
        # choice = show do
        #     title "Clean Up"
        #     check "Turn off the transilluminator."
        #     check "Dispose of the gel and any gel parts by placing it in the waste container. Spray the surface of the transilluminator with ethanol and wipe until dry using a paper towel."
        #     check "Remove the blue light goggles, clean them, and put them back where you found them."
        #     check "Clean up the gel box and casting tray by rinsing with water. Return them to the gel station."
        #     check "Dispose gloves after leaving the room."
        #     gels.each do |g|
        #         g.mark_as_deleted
        #     end
        #     select ["Yes", "No"], var: "choice", label: "Would you like to purify the gel slices immediately?"
        # end

        # if choice[:choice] == "Yes"
        #     show do
        #         title "Keep Gel Slices"
        #         note "Keep the gel slices on your bench to use in the next protocol."
        #     end
        # else
        #     operations.store
        # end

        # # associate gel image, fragment lane with fragment and weight with the gel slices
        # operations.each { |op|
        #     i = op.input(FRAGMENT)
        #     o = op.output(FRAGMENT).item
        #     o.associate(:gel_image, "Your fragment is in row #{i.row + 1} and column #{i.column + 1}", op.temporary[:upload]) if o
        #     o.associate(:weight, op.temporary[:weight]) if o
        #     op.associate(:gel_image, "Your fragment is in row #{i.row + 1} and column #{i.column + 1}", op.temporary[:upload])
        #     op.plan.associate :choice, choice[:choice]
        # }

        # operations.running.each do |op|
        #     txfr_barcode(op, FRAGMENT, FRAGMENT)
        #     txfr_bin(op, FRAGMENT, FRAGMENT)
        # end

        # get_protocol_feedback

        # if debug
        #     display_barcode_associations(operations: operations, in_handle: FRAGMENT)
        # end

        return {}

    end

    #---------------------------------------------------------------

    def ask_for_uploads
        # Request technician for uploads
        # TODO: Ugly. Re-write this as some kind of "Upload Manager" convention?
        counter = 0
        ready = false
        msgs = []
        while counter < 5 and not ready
            counter += 1
            msgs.uniq!
            show do
                title "Upload all gel images"
                if msgs.any?
                    warning "Some images are missing. Make sure the images are named correctly and you've uploaded all of the images"
                    msgs.each do |msg|
                        warning msg if msg
                    end
                end
                upload var: "my_gel_pic"

                t = Table.new
                t.add_column("Gel Row/Col", operations.map { |op|
                    f = op.input(FRAGMENT)
                    "#{f.row + 1} #{f.column + 1}"
                })
                t.add_column("Image name", operations.map { |op| op.temporary[:image_name] } )
                t.add_column("Uploaded?", operations.map { |op|
                    x = "No"
                    x = "Yes (\"#{op.temporary[:image_name]}\")" if op.temporary[:uploaded]
                    x
                    } )
                table t
            end

            op_to_file_hash = match_upload_to_operations operations, :image_name, job_id=self.jid
            op_to_file_hash.each do |op, u|
                op.temporary[:upload] = u
            end

            ready = true
            operations.each do |op|
                if op.temporary[:upload].nil?
                    msgs << "    Gel image <b>\"#{op.temporary[:image_name]}\"</b> not uploaded!"
                    ready = false
                end
            end

            if counter > 5
                ready = true
            end

            if debug and counter > 1
                ready = true
            end
        end
    end

    # method that matches uploads to operations with a temporary[filename_key]
    def match_upload_to_operations ops, filename_key, job_id=nil, uploads=nil
        def extract_basename filename
            ext = File.extname(filename)
            basename = File.basename(filename, ext)
        end

        op_to_upload_hash = Hash.new
        uploads ||= Upload.where("job_id"=>job_id).to_a if job_id
            if uploads
                ops.each do |op|
                    upload = uploads.select do |u|
                        basename = extract_basename(u[:upload_file_name])
                        op.temporary[filename_key].strip == basename.strip
                    end.first || nil
                    op_to_upload_hash[op] = upload
                end
            end
        op_to_upload_hash
    end
end










# # Extract Fragment Protocol
# # V1.0.2; 2017-07-17 JV
# # Written by Ayesha Saleem
# # Revised by Justin Vrana 2017-07-13; corrected upload issue
# # Revised by Justin Vrana 2017-07-17; unique upload table
# # Revised by SG 05-2018; accepts general gel inputs, does not assume output sample property "Length"

# needs "Standard Libs/Feedback"
# needs "Next Gen Prep/NextGenPrepHelper"
# needs "Standard Libs/UploadHelper"

# class Protocol

#     include Feedback, NextGenPrepHelper, UploadHelper

#     # I/O
#     FRAGMENT = "Fragment"
#     FRAGMENT_OUT ="Fragment"
#     MIN_WEIGHT = 0.0
#     MAXWEIGHT = 10.0
#     TRIES = 3

#     def main

#         associate_random_barcodes(operations: operations, in_handle: FRAGMENT) if debug

#         # Sort operations by gels and columns (these can get out of order from PCR)
#         operations.sort! { |op1, op2|
#             fv1 = op1.input(FRAGMENT)
#             fv2 = op2.input(FRAGMENT)
#             [fv1.item.id, fv1.row, fv1.column] <=> [fv2.item.id, fv2.row, fv2.column]
#         }

#         # find expected lengths for inputs - may need to add/change cases in the future
#         operations.each { |op|
#             if(!op.output(FRAGMENT).sample.nil?)
#                 nm=SampleType.find(op.output(FRAGMENT).sample.sample_type_id).name # sample type
#                 case nm
#                 when "Fragment" || "Plasmid" # have sample property "Length"
#                     op.temporary[:length] = op.output(FRAGMENT).sample.properties["Length"]
#                 when "DNA Library" # should have "Library Stock" object_type with associated "length"
#                     stock=find(:item,
#                                 object_type: { name: "Library Stock" },
#                                 sample: { name: op.output(FRAGMENT).sample.name }
#                                 ).first
#                     if(!stock.nil?)
#                         op.temporary[:length] = stock.get(:length)
#                     end
#                 end
#             end
#         }

#         # ask tech to enter missing lengths
#         length_unknown=operations.select{|op| op.temporary[:length].nil?}
#         if(length_unknown.any?)
#             # get lengths for all samples for which length is not defined - ideally this should not be needed!!!
#             show do
#                 title "Enter the expected lengths in bp for these samples:"
#                 note "Ask a lab manager if you do not know"
#                 table length_unknown.start_table
#                     .custom_column(heading: "Sample Name", checkable: true) { |op| op.input(FRAGMENT).sample.name }
#                     .get(:length, type: 'number', heading: "Expected length (bp)")
#                     .end_table
#             end
#         end

#         grouped_by_gel = operations.group_by { |op| op.input(FRAGMENT).collection }

#         grouped_by_gel.each do |gel, grouped_ops|
#             grouped_ops.extend(OperationList)
#             # gel image names
#             grouped_ops.each do |op|
#                 op.temporary[:image_name] = "gel_#{gel.id}"
#             end
            
#             # ---------------------------------------------IMAGE 
#             show do
#                 title "Image gel #{gel.id}"
#                 check "Clean the transilluminator with ethanol."
#                 check "Put the gel #{gel} on the transilluminator."
#                 check "Turn off the room lights before turning on the transilluminator."
#                 check "Put the camera hood on, turn on the transilluminator and take a picture using the camera control interface on computer."
#                 check "Check to see if the picture matches the gel before uploading."
#                 check "Rename the picture you just took exactly as <b>#{grouped_ops.first.temporary[:image_name]}</b>."
#             end
            
#             # ---------------------------------------------UPLOAD
#             ups = uploadData("/gel_#{gel.id}", 1, TRIES) # 1 file per gel
#             image_name = grouped_ops.first.temporary[:image_name]
#             # associate to gel, plan, op 
#             # can't associate to outputs yet because they are only made if lengths are verified
#             up=nil
#             if(!(ups.nil?))
#               up=ups[0]
        
#               gel_item = Item.find(gel.id)
        
#               # associate gel image to gel
#               gel_item.associate image_name, "successfully imaged gel", up
              
#               grouped_ops.each do |op| # associate to all operations connected to gel
#                 # description of where this op is in the gel, to be used as desc tag for image upload
#                 location_in_gel = "#{op.input(FRAGMENT).sample.name} is in row #{op.input(FRAGMENT).row + 1} and column #{op.input(FRAGMENT).column + 1}"
                
#                 # associate image to op with a location description
#                 op.associate image_name, location_in_gel, up
                
#                 # associate image to plan, or append new location to description if association already exists
#                 existing_assoc = op.plan.get(image_name)
#                 if existing_assoc && op.plan.upload(image_name) == up
#                     op.plan.modify(image_name, existing_assoc.to_s + "\n" + location_in_gel, up)
#                 else
#                     op.plan.associate image_name, location_in_gel , up
#                 end
#               end
#             end
            
#             # ---------------------------------------------VERIFY
#             expected_length_table = grouped_ops.start_table
#                 .custom_column(heading: "Gel ID") { |op| op.input(FRAGMENT).item.id }
#                 .custom_column(heading: "Row") { |op| op.input(FRAGMENT).row + 1 }
#                 .custom_column(heading: "Column", checkable: true) { |op| op.input(FRAGMENT).column + 1 }
#                 .custom_column(heading: "Expected Length") { |op| op.temporary[:length] }
#                 .get(:correct, heading: "Does the band match the expected length (y/n)", type: "string", default: "y")
#                 .end_table
                
#             responses = show do
#                 title "Verify Fragment Lengths for gel #{gel.id}"
#                 table expected_length_table
#             end
            
#             grouped_ops.each { |op|
#               if(op.temporary[:correct].upcase.start_with?("N"))
#                 op.error :incorrect_length, "The fragment did not match the expected length."
#               end
#             }
            
#             grouped_ops.select! { |op| op.status == "running"}
            
#             grouped_ops.make
            
#             # ---------------------------------------------CUT
#             qpcr1_ops = grouped_ops.select do |op|
#                 back_wire = op.input("Fragment").wires_as_dest[0]
#                 back_wire && FieldValue.find(back_wire.from_id).operation && FieldValue.find(back_wire.from_id).operation.input("Program") &&(FieldValue.find(back_wire.from_id).operation.input("Program").val == "qPCR1")
#             end.extend(OperationList)
#             qpcr2_ops = (grouped_ops - qpcr1_ops).extend(OperationList)
            
#             if qpcr1_ops.any?
#                 show do
#                     title "Cut Out Fragments"
#                     note "Take out #{grouped_ops.length} 1.5 mL tubes and label accordingly: #{grouped_ops.map { |op| "#{op.output(FRAGMENT).item}" }.to_sentence}"
#                     note "Now, cut out the bands and place them into the 1.5 mL tubes according to the following table:"
#                     table qpcr1_ops.start_table 
#                         .custom_column(heading: "Gel ID") { |op| "#{op.input(FRAGMENT).item}" }
#                         .custom_column(heading: "Row") { |op| op.input(FRAGMENT).row + 1 }
#                         .custom_column(heading: "Column", checkable: true) { |op| op.input(FRAGMENT).column + 1 }
#                         .custom_column(heading: "1.5 mL Tube ID") { |op| "#{op.output(FRAGMENT_OUT).item}" }
#                     .end_table
#                 end
#             end
            
#             if qpcr2_ops.any?
#                 show do
#                     title "Cut Out Fragments"
#                     note "Take out #{grouped_ops.length} 1.5 mL tubes and label accordingly: #{grouped_ops.map { |op| op.output(FRAGMENT).item}.to_sentence}"
#                     note "Now, cut out the bands and place them into the 1.5 mL tubes according to the following table:"
#                     table qpcr2_ops.start_table
#                         .custom_column(heading: "Gel ID") { |op| op.input(FRAGMENT).item.id }
#                         .custom_column(heading: "Row") { |op| op.input(FRAGMENT).row + 1 }
#                         .custom_column(heading: "Column", checkable: true) { |op| op.input(FRAGMENT).column + 1 }
#                         .custom_column(heading: "1.5 mL Tube ID") { |op| op.output(FRAGMENT).item.id }
#                     .end_table
#                 end
#             end
#             # ---------------------------------------------WEIGHT
#             show do
#                 title "Weight Gel Slices"
#                 note "Perform this step using the scale inside the gel room."
#                 check "Zero the scale with an empty 1.5 mL tube."
#                 check "Weigh each slice and enter the weights in the following table:"
#                 table grouped_ops.start_table
#                   .custom_column(heading: "1.5 mL Tube ID") { |op| "#{op.output(FRAGMENT_OUT).item}" }
#                   .get(:weight, type: 'number', heading: "Weight (g)",  default: MIN_WEIGHT)
#                   .end_table
#             end
            
#             grouped_ops.each { |op|
#                 op.output(FRAGMENT_OUT).item.associate(image_name, "Your fragment is in row #{op.input(FRAGMENT).row + 1} and column #{op.input(FRAGMENT).column + 1}", up) 
#                 op.output(FRAGMENT_OUT).item.associate(:weight, op.temporary[:weight]) 
#             }
#         end
        
#         choice = show do
#             title "Clean Up"
#             check "Turn off the transilluminator."
#             check "Dispose of the gel and any gel parts by placing it in the waste container. Spray the surface of the transilluminator with ethanol and wipe until dry using a paper towel."
#             check "Remove the blue light goggles, clean them, and put them back where you found them."
#             check "Clean up the gel box and casting tray by rinsing with water. Return them to the gel station."
#             check "Dispose gloves after leaving the room."
#             grouped_by_gel.each do |gel, grouped_gel|
#                 gel.mark_as_deleted
#             end
#             select ["Yes", "No"], var: "choice", label: "Would you like to purify the gel slices immediately?"
#         end
        
#         operations.running.each do |op|
#             txfr_barcode(op, FRAGMENT, FRAGMENT)
#             txfr_bin(op, FRAGMENT, FRAGMENT)
#         end
        
#         if choice[:choice] == "Yes"
#             show do
#                 title "Keep Gel Slices"
#                 note "Keep the gel slices on your bench to use in the next protocol."
#             end
#         else
#             operations.store
#         end

     
#         # operations.make

#         # split operationlist into ops that have originated from first pcr and those from second pcr.
#         # qpcr1_ops = operations.select do |op|
#         #     back_wire = op.input("Fragment").wires_as_dest[0]

#         #     back_wire && FieldValue.find(back_wire.from_id).operation && FieldValue.find(back_wire.from_id).operation.input("Program") && (FieldValue.find(back_wire.from_id).operation.input("Program").val == "qPCR1")
#         # end.extend(OperationList)
#         # qpcr2_ops = (operations - qpcr1_ops).extend(OperationList)

#         # show do
#         #     title "Cut Out Fragments"
#         #     note "Take out #{operations.length} 1.5 mL tubes and label accordingly: #{operations.collect { |op| op.output(FRAGMENT).item}.to_sentence}"
#         #     note "Now, cut out the bands and place them into the 1.5 mL tubes according to the following table:"
#         #     image "Actions/Gel/cut_extra_gel.jpg"
#         #     table qpcr1_ops.start_table
#         #     .custom_column(heading: "Gel ID") { |op| op.input(FRAGMENT).item.id }
#         #     .custom_column(heading: "Row") { |op| op.input(FRAGMENT).row + 1 }
#         #     .custom_column(heading: "Column", checkable: true) { |op| op.input(FRAGMENT).column + 1 }
#         #     .custom_column(heading: "1.5 mL Tube ID") { |op| op.output(FRAGMENT).item.id }
#         #     .end_table
#         # end if qpcr1_ops.any?

#         # show do
#         #     title "Cut Out Fragments"
#         #     note "Take out #{operations.length} 1.5 mL tubes and label accordingly: #{operations.collect { |op| op.output(FRAGMENT).item}.to_sentence}"
#         #     note "Now, cut out the bands and place them into the 1.5 mL tubes according to the following table:"
#         #     table qpcr2_ops.start_table
#         #     .custom_column(heading: "Gel ID") { |op| op.input(FRAGMENT).item.id }
#         #     .custom_column(heading: "Row") { |op| op.input(FRAGMENT).row + 1 }
#         #     .custom_column(heading: "Column", checkable: true) { |op| op.input(FRAGMENT).column + 1 }
#         #     .custom_column(heading: "1.5 mL Tube ID") { |op| op.output(FRAGMENT).item.id }
#         #     .end_table
#         # end if qpcr2_ops.any?

#         # min_weight = 0.0
#         # max_weight = 10.0

#         # gel_slice_table = operations.start_table
#         #     .custom_column(heading: "1.5 mL Tube ID") { |op| op.output(FRAGMENT).item.id }
#         #     .get(:weight, type: 'number', heading: "Weight (g)")
#         #     .end_table

#         # show do
#         #     title "Weight Gel Slices"
#         #     note "Perform this step using the scale inside the gel room."
#         #     check "Zero the scale with an empty 1.5 mL tube."
#         #     check "Weigh each slice and enter the weights in the following table:"
#         #     table gel_slice_table
#         # end

#         # gels = operations.collect{ |op| op.input(FRAGMENT).item }.uniq
#         # choice = show do
#         #     title "Clean Up"
#         #     check "Turn off the transilluminator."
#         #     check "Dispose of the gel and any gel parts by placing it in the waste container. Spray the surface of the transilluminator with ethanol and wipe until dry using a paper towel."
#         #     check "Remove the blue light goggles, clean them, and put them back where you found them."
#         #     check "Clean up the gel box and casting tray by rinsing with water. Return them to the gel station."
#         #     check "Dispose gloves after leaving the room."
#         #     gels.each do |g|
#         #         g.mark_as_deleted
#         #     end
#         #     select ["Yes", "No"], var: "choice", label: "Would you like to purify the gel slices immediately?"
#         # end

#         # if choice[:choice] == "Yes"
#         #     show do
#         #         title "Keep Gel Slices"
#         #         note "Keep the gel slices on your bench to use in the next protocol."
#         #     end
#         # else
#         #     operations.store
#         # end

#         # # associate gel image, fragment lane with fragment and weight with the gel slices
#         # operations.each { |op|
#         #     i = op.input(FRAGMENT)
#         #     o = op.output(FRAGMENT).item
#         #     o.associate(:gel_image, "Your fragment is in row #{i.row + 1} and column #{i.column + 1}", op.temporary[:upload]) if o
#         #     o.associate(:weight, op.temporary[:weight]) if o
#         #     op.associate(:gel_image, "Your fragment is in row #{i.row + 1} and column #{i.column + 1}", op.temporary[:upload])
#         #     op.plan.associate :choice, choice[:choice]
#         # }

#         # operations.running.each do |op|
#         #     txfr_barcode(op, FRAGMENT, FRAGMENT)
#         #     txfr_bin(op, FRAGMENT, FRAGMENT)
#         # end

#         # get_protocol_feedback

#         # if debug
#         #     display_barcode_associations(operations: operations, in_handle: FRAGMENT)
#         # end

#         return {}

#     end

#     #---------------------------------------------------------------

#     def ask_for_uploads
#         # Request technician for uploads
#         # TODO: Ugly. Re-write this as some kind of "Upload Manager" convention?
#         counter = 0
#         ready = false
#         msgs = []
#         while counter < 5 and not ready
#             counter += 1
#             msgs.uniq!
#             show do
#                 title "Upload all gel images"
#                 if msgs.any?
#                     warning "Some images are missing. Make sure the images are named correctly and you've uploaded all of the images"
#                     msgs.each do |msg|
#                         warning msg if msg
#                     end
#                 end
#                 upload var: "my_gel_pic"

#                 t = Table.new
#                 t.add_column("Gel Row/Col", operations.map { |op|
#                     f = op.input(FRAGMENT)
#                     "#{f.row + 1} #{f.column + 1}"
#                 })
#                 t.add_column("Image name", operations.map { |op| op.temporary[:image_name] } )
#                 t.add_column("Uploaded?", operations.map { |op|
#                     x = "No"
#                     x = "Yes (\"#{op.temporary[:image_name]}\")" if op.temporary[:uploaded]
#                     x
#                     } )
#                 table t
#             end

#             op_to_file_hash = match_upload_to_operations operations, :image_name, job_id=self.jid
#             op_to_file_hash.each do |op, u|
#                 op.temporary[:upload] = u
#             end

#             ready = true
#             operations.each do |op|
#                 if op.temporary[:upload].nil?
#                     msgs << "    Gel image <b>\"#{op.temporary[:image_name]}\"</b> not uploaded!"
#                     ready = false
#                 end
#             end

#             if counter > 5
#                 ready = true
#             end

#             if debug and counter > 1
#                 ready = true
#             end
#         end
#     end

#     # method that matches uploads to operations with a temporary[filename_key]
#     def match_upload_to_operations ops, filename_key, job_id=nil, uploads=nil
#         def extract_basename filename
#             ext = File.extname(filename)
#             basename = File.basename(filename, ext)
#         end

#         op_to_upload_hash = Hash.new
#         uploads ||= Upload.where("job_id"=>job_id).to_a if job_id
#             if uploads
#                 ops.each do |op|
#                     upload = uploads.select do |u|
#                         basename = extract_basename(u[:upload_file_name])
#                         op.temporary[filename_key].strip == basename.strip
#                     end.first || nil
#                     op_to_upload_hash[op] = upload
#                 end
#             end
#         op_to_upload_hash
#     end
# end