# Extract Fragment Protocol
# V1.0.2; 2017-07-17 JV
# Written by Ayesha Saleem
# Revised by Justin Vrana 2017-07-13; corrected upload issue
# Revised by Justin Vrana 2017-07-17; unique upload table
# Revised by SG 05-2018; accepts general gel inputs, does not assume output sample property "Length" 
class Protocol
    
    # I/O
    FRAGMENT="Fragment"

    def main
        
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
        
        # ask tech to enter missing lengths
        length_unknown=operations.select{|op| op.temporary[:length].nil?}
        if(length_unknown.any?)
            # get lengths for all samples for which length is not defined - ideally this should not be needed!!!
            show do
                title "Enter the expected lengths in bp for these samples:"
                note "Ask a lab manager if you do not know"
                table length_unknown.start_table
                    .custom_column(heading: "Sample Name", checkable: true) { |op| op.input(FRAGMENT).sample.name }
                    .get(:length, type: 'number', heading: "Expected length (bp)", default: 1) 
                    .end_table
            end 
        end
        
        grouped_by_gel = operations.group_by { |op| op.input(FRAGMENT).item } 
        
        grouped_by_gel.each do |gel, grouped_ops|
            # gel image names
            grouped_ops.each do |op|
                op.temporary[:image_name] = "gel_#{gel.id}"
            end
            
            show do
                title "Image gel #{gel.id}"
                check "Clean the transilluminator with ethanol."
                check "Put the gel #{gel} on the transilluminator."
                check "Turn off the room lights before turning on the transilluminator."
                check "Put the camera hood on, turn on the transilluminator and take a picture using the camera control interface on computer."
                check "Check to see if the picture matches the gel before uploading."
                check "Rename the picture you just took exactly as <b>#{grouped_ops.first.temporary[:image_name]}</b>."
            end
            
            create_expected_length_table = Proc.new { |ops|
                t = ops.start_table
                    .custom_column(heading: "Gel ID") { |op| op.input(FRAGMENT).item.id }
                    .custom_column(heading: "Row") { |op| op.input(FRAGMENT).row + 1 }
                    .custom_column(heading: "Column", checkable: true) { |op| op.input(FRAGMENT).column + 1 }
                    .custom_column(heading: "Expected Length") { |op| op.temporary[:length] }
                    .custom_input(:correct, heading: "Does the band match the expected length (y/n)", type: "string") { |op| 
                        d = op.temporary[:correct] || "y"
                        d = ["y","n"].sample if debug
                        d
                    }
                    .validate(:correct) { |op, val| ["y","n"].include? val.downcase.strip[0] }
                    .validation_message(:correct) { |op, k, v| "Please include a choice (y/n) for fragment #{op.input(FRAGMENT).item}. \"#{op.temporary[:correct]}\" is invalid." }
                    .end_table
                t.all  
            }
            
            show_with_input_table(grouped_ops, create_expected_length_table) do
                title "Verify Fragment Lengths for gel #{gel.id}"
            end
        end
        
        ask_for_uploads
        
        # Whether fragment matched length
        operations.each do |op|
            if op.temporary[:correct].upcase.start_with?("N")
                op.error :incorrect_length, "The fragment did not match the expected length."
            end
        end
        ops_r=operations.running
        if ops_r.none?
            show do
                title "Happy day!"
                note "Since there are no more running protocols, your work is done here. Thanks!"
            end
            return {}
        end
        operations=ops_r
        
        operations.make
        
        qpcr1ops = operations.select do |op| 
            run_gel_op = get_ancestor(op, FRAGMENT)
            qpcr_op = get_ancestor(run_gel, FRAGMENT) if run_gel_op
            qpcr_op
            (qpcr_op && qpcr_op.input("qPCR program") && (qpcr_op.input("qPCR program").val == "lib_qPCR1")) || (debug && [true,false].sample)
        end.extend(OperationList)
        
        qpcr2ops = (operations - qpcr1ops).extend(OperationList)
        
        show do
            title "Cut Out Fragments (with extra gel)"
            note "Take out #{operations.length} 1.5 mL tubes and label accordingly: #{operations.collect { |op| op.output(FRAGMENT).item}.to_sentence}"
            note "Now, cut out the bands and place them into the 1.5 mL tubes according to the following table:"
            table qpcr1ops.start_table 
            .custom_column(heading: "Gel ID") { |op| op.input(FRAGMENT).item.id }
            .custom_column(heading: "Row") { |op| op.input(FRAGMENT).row + 1 }
            .custom_column(heading: "Column", checkable: true) { |op| op.input(FRAGMENT).column + 1 }
            .custom_column(heading: "1.5 mL Tube ID") { |op| op.output(FRAGMENT).item.id }
            .end_table
            note "Cut out a bit more of the gel than usual for these fragments. Refer to the diagram below."
            image "Actions/Gel/cut_extra_gel.jpg"
        end if qpcr1ops.any?
        
        show do
            title "Cut Out Fragments Normally"
            note "Take out #{operations.length} 1.5 mL tubes and label accordingly: #{operations.collect { |op| op.output(FRAGMENT).item}.to_sentence}"
            note "Now, cut out the bands and place them into the 1.5 mL tubes according to the following table:"
            table qpcr2ops.start_table 
            .custom_column(heading: "Gel ID") { |op| op.input(FRAGMENT).item.id }
            .custom_column(heading: "Row") { |op| op.input(FRAGMENT).row + 1 }
            .custom_column(heading: "Column", checkable: true) { |op| op.input(FRAGMENT).column + 1 }
            .custom_column(heading: "1.5 mL Tube ID") { |op| op.output(FRAGMENT).item.id }
            .end_table
        end if qpcr2ops.any?
        
        min_weight = 0.0
        max_weight = 10.0
        
        create_gel_slice_table = Proc.new { |ops|
            ops.start_table
            .custom_column(heading: "1.5 mL Tube ID") { |op| op.output(FRAGMENT).item.id }
            .custom_input(:weight, type: 'number', heading: "Weight (g)") { |op|
                w = -1.00
                w = rand(0.1..3.0) if debug
                w
            } 
            .validate(:weight) { |op, v| v.between?(min_weight, max_weight) }
            .validation_message(:weight) { |op, k, v| 
                "Weight of #{op.output(FRAGMENT).item} needs to be between #{min_weight} and #{max_weight}. Please re-enter weight." }
            .end_table.all
        }
        
        show_with_input_table(operations, create_gel_slice_table) do
            title "Weight Gel Slices"
            note "Perform this step using the scale inside the gel room."
            check "Zero the scale with an empty 1.5 mL tube."
            check "Weigh each slice and enter the weights in the following table:"
        end
        
        gels = operations.collect{ |op| op.input(FRAGMENT).item }.uniq
        choice = show do
            title "Clean Up"
            check "Turn off the transilluminator."
            check "Dispose of the gel and any gel parts by placing it in the waste container. Spray the surface of the transilluminator with ethanol and wipe until dry using a paper towel."
            check "Remove the blue light goggles, clean them, and put them back where you found them."
            check "Clean up the gel box and casting tray by rinsing with water. Return them to the gel station."
            check "Dispose gloves after leaving the room."
            gels.each do |g|
                g.mark_as_deleted
            end
            select ["Yes", "No"], var: "choice", label: "Would you like to purify the gel slices immediately?"
        end
        
        if choice[:choice] == "Yes"
            show do 
                title "Keep Gel Slices"
                note "Keep the gel slices on your bench to use in the next protocol."
            end
        else
            operations.store 
        end
        
        # associate gel image, fragment lane with fragment and weight with the gel slices
        operations.each { |op|
            # pass on NGS barcode 
            if(!(op.input(FRAGMENT).item.get(:barcodes).nil?))
                barcodes=op.input(FRAGMENT).item.get(:barcodes)
                op.output(FRAGMENT).item.associate :barcode, barcodes[op.input(FRAGMENT).row][op.input(FRAGMENT).column]
            end
            # pass on bin info
            if(!(op.input(FRAGMENT).item.get(:bins).nil?))
                bins=op.input(FRAGMENT).item.get(:bins)
                op.output(FRAGMENT).item.associate :bin, bins[op.input(FRAGMENT).row][op.input(FRAGMENT).column]
            end
            i = op.input(FRAGMENT)
            o = op.output(FRAGMENT).item
            o.associate(:gel_image, "Your fragment is in row #{i.row + 1} and column #{i.column + 1}", op.temporary[:upload]) if o
            o.associate(:weight, op.temporary[:weight]) if o
            op.associate(:gel_image, "Your fragment is in row #{i.row + 1} and column #{i.column + 1}", op.temporary[:upload])
            op.plan.associate :choice, choice[:choice]
        }
    
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
    
    def get_ancestor(op, input_name)
        input_wire = op.input(input_name).wires_as_dest.first
        if input_wire
            ancestor = FieldValue.find(input_wire.from_id).operation
            return ancestor
        else
            return nil
        end
    end
end
