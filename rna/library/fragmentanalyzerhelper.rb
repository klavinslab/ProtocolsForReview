# SG
# helper functions for fragment analyzer  
module FragmentAnalyzerHelper
    
    MARKER_TYPES=["DNA",         "RNA"  ] # QX marker types
    # QX cutoffs, in bp. array order should correspond to MARKER_TYPES, ascending cutoff order
    CUTOFFS=     [[5000,10000],   [10000]    ] 
    # QX alignment markers - order should correspond to CUTOFFS
    MARKERS=     [["QX Alignment Marker (15bp/5kb)","QX Alignment Marker (15bp/10kb)"], ["QX RNA Alignment Marker (15bp)"]] 
    # constant names for calibration files for each of the alignment markers
    REF_MARKERS= [["15bp_5kb_022216","undefined ref-marker(long DNA)"],["undefined ref-marker(RNA)"]] # Need to create marker and place name here -EL 041118
    QIAXCEL_TEMPLATE = {'DNA'=>'PhusionPCR','RNA'=>'RNAQC_Template'}
    WELLS_PER_STRIPWELL=12
    EB_VOL=10 # uL
    
    #---------------------------------------------------------------------
    # intro for tech
    #---------------------------------------------------------------------
    def intro()
        show do
            title "Fragment analyzing info"
            note "In this protocol, you will do the following:"
            note "- gather stripwells of fragments"
            note "- organize them in the fragment analyzer machine"
            note "- set up and run the analyzer"
            note "- upload the analysis results to Aquarium"
        end
    end
    
    #---------------------------------------------------------------------
    # determine marker, cartridge base on a list of sampleTypes and expectedLengths
    # inputs: sampleTypes - array with "DNA" or "RNA" at each spot
    #         expectedLengths - array of same length as sampleTypes of expected fragment lengths
    # outputs: returnHash, with keys "type" and "marker"
    #---------------------------------------------------------------------
    def determineMarkerAndCartridge(sampleTypes, expectedLengths)
        # first check that all can use the same marker
        #if not, send informative message to lab managers and move operations back to pending
        type_ind=Array.new(1,-1)
        cutoff_ind=Array.new(1,-1)
        
        sampleTypes.each_with_index { |ss, ii|
            if(debug)
                show do
                    title "DEBUG"
                    note "sampleTypes #{ii}=#{sampleTypes[ii]}"
                    note "expectedLengths #{ii}=#{expectedLengths[ii]}"
                end
            end
            # choose marker type
            type_ind[ii] = MARKER_TYPES.index {|x| x == sampleTypes[ii] } # index of type
            # returns lowest index for which condition is satisfied
            cutoff_ind[ii] = CUTOFFS[type_ind[ii]].find_index {|x| x >= expectedLengths[ii] } # CUTOFFS row corresponds to DNA/RNA
        
            # DEBUG
            #if(debug)
            #    type_ind[ii]=0
            #    cutoff_ind[ii]=0
            #end
        }
        
        returnHash=Hash.new
        returnHash[:sampleTypes]=sampleTypes[0] # DNA or RNA
        returnHash[:type_ind]=type_ind[0] # all should be the same
        returnHash[:cutoff_ind]=cutoff_ind.max # longest marker is at largest index
        
        # return
        returnHash
        
    end # def 
        
    #---------------------------------------------------------------------
    # check if sampleTypes can be run with the same cartridge/marker
    # sampleTypes - array with "DNA" or "RNA" at each spot
    # expectedLengths - array of same length as sampleTypes of expected fragment lengths
    # 
    # returns 0 if not compatible, 1 if compatible
    #---------------------------------------------------------------------
    def checkCompatibility(sampleTypes, expectedLengths)    
        # can't run RNA and DNA together! error if attempted
        if(sampleTypes.uniq.length>1)
            return 0
        end
    end # def
    
    #---------------------------------------------------------------------
    # cartridge: prep, load. NOTE: if this is RNA, we will need to change cartridge!!!
    #---------------------------------------------------------------------
    def cartridgeLoad(cartridge_type)
        
        case cartridge_type
        when 'RNA'
            cartridge = find(:item, object_type: { name: "QX RNA Screening Cartridge Container" }).first#.first {|c| c.location == 'Fragment analyzer'} # .find { |c| c.location == "Fragment analyzer" }
        when 'DNA'
            cartridge = find(:item, object_type: { name: "QX DNA Screening Cartridge" }).first#.find { |c| c.location == "Fragment analyzer" }
        end
        
        if(cartridge) # already in
            take [cartridge]
        else # prep new cartridge
            # prep cartridge
            show do
                title "Prepare to insert QX #{cartridge_type} Screening Cartridge into the machine"
                warning "Please keep the cartridge vertical at all times!".upcase
                check "Take the cartridge labeled #{cartridge} from #{cartridge.location} and bring to fragment analyzer."
                check "Remove the cartridge from its packaging and CAREFULLY wipe off any soft tissue debris from the capillary tips using a soft tissue."
                check "Remove the purge cap seal from the back of the cartridge."
                #image "frag_an_cartridge_seal_off"
                warning "Do not set down the cartridge when you proceed to the next step."
            end
            # place in machine
            show do
                title "Insert QX #{cartridge_type} Screening Cartridge into the machine"
                check "Use a soft tissue to wipe off any gel that may have leaked from the purge port."
                check "Open the cartridge compartment by gently pressing on the door."
                check "Carefully place the cartridge into the fragment analyzer; cartridge description label should face the front and the purge port should face the back of the fragment analyzer."
                check "Insert the smart key into the smart key socket; key can be inserted in either direction."
                #image "frag_an_cartridge_and_key"
                check "Close the cartridge compartment door."
                check "Open the ScreenGel software and latch the cartridge by clicking on the <b>Latch</b> icon."
                check "Grab the purge port seal bag from the bottom drawer beneath the machine, put the seal back on its backing, and return it in the bag to the drawer."
            end
            # enter runs if not already associated
            unless(cartridge.get(:runs))
                runs = show do 
                      title "Enter number of runs"
                      get "number", var: "runs", label: "Please enter the number of <b>Remaining Runs</b> left in this cartridge.", default: 0
                end
                cartridge.associate :runs, runs[:runs]
            end
            
            # wait for equilibration  
            if cartridge_type == 'DNA' # wait for equilibration  
                show do
                    title "Wait for the cartridge to equilibrate"
                    check "Start a <b>30 min</b> timer, and do not run the fragment analyzer until it finishes."
                end
            end
            
            # set location
            take [cartridge]
            cartridge.location = "Fragment analyzer"
            cartridge.save
            
        end # if(cartridge)
        
        # return
        cartridge
    end # def
    
    #---------------------------------------------------------------------
    # alignment marker: prep/swap/load if needed 
    # input: inhash, holds indices into MARKERS defining sample and marker types
    #---------------------------------------------------------------------
    def alignmentMarkerLoad(inhash)
        
        log_info 'inhash', inhash # 1, 0
        if inhash[:sampleTypes] == 'DNA'
            alignment_markers = find(:item, sample: { name: MARKERS[inhash[:type_ind]][inhash[:cutoff_ind]] })
        elsif inhash[:sampleTypes] == 'RNA'
           alignment_markers = find(:item, { sample: { name: MARKERS[inhash[:type_ind]] } } )
        end
        log_info 'alignment marker ', alignment_markers
        alignment_marker=-1
        if(!(alignment_markers.nil?))
            alignment_marker=alignment_markers[0] 
        end
        log_info 'alignment_marker', alignment_marker
        # marker currently in machine (location)
        # marker_in_analyzer = find(:item, object_type: { name: "Stripwell" })
        #                         .find { |s| s.datum[:matrix][0][0] == alignment_marker.sample.id && s.location == "Fragment analyzer"} # old version
        
        # TODO: use check_alignment_marker function
        marker_in_analyzer = find(:item, object_type: {name: "Stripwell"}).find {|s| s.location == 'Fragment analyzer'}
        
        # is requested marker different from marker in machine?
        different_marker =! (alignment_markers.include?(marker_in_analyzer))
        
        # old marker?
        old_marker=( (marker_in_analyzer.get(:begin_date) ? (Date.today - (Date.parse marker_in_analyzer.get(:begin_date)) >= 7) : true) )
        
        # need to replace?                                   
        marker_needs_replacing = (old_marker) || (different_marker)
        
        # new alignment marker
        alignment_marker_stripwell = find(:item, object_type: { name: "Stripwell" })
                                      .find { |s| collection_from(s).matrix[0][0] == alignment_marker.sample.id &&
                                                  s != marker_in_analyzer }
                                                  
        if(debug)                                    
            show do
                title "DEBUG"
                note "marker_in_analyzer=#{marker_in_analyzer}"
                note "different marker = #{different_marker}"
                note "marker_needs_replacing = #{marker_needs_replacing}"
                note "looking for #{MARKERS[inhash[:type_ind]][inhash[:cutoff_ind]]}"
                note "alignment_marker_stripwell = #{alignment_marker_stripwell}"
            end
        end

        #  replace alignment marker
        if(marker_needs_replacing && alignment_marker_stripwell) 
            show do
                title "Place stripwell #{alignment_marker_stripwell} in buffer array"
                note "Move to the fragment analyzer."
                note "Open ScreenGel software."
                check "Click on the <b>Load Position</b> icon."
                check "Open the sample door and retrieve the buffer tray."
                warning "Be VERY careful while handling the buffer tray! Buffers can spill."
                if old_marker
                    check "Discard the current alignment marker stripwell (labeled #{marker_in_analyzer})."
                end
                check "Place the alignment marker stripwell labeled #{alignment_marker_stripwell} in the MARKER 1 position of the buffer array."
                image "make_marker_placement"
                check "Place the buffer tray in the buffer tray holder"
                image "make_marker_tray_holder"
                check "Close the sample door."
            end
            alignment_marker_stripwell.location = "Fragment analyzer"
            alignment_marker_stripwell.save
            if(old_marker) # replaced because old one was outdated
                alignment_marker_stripwell.associate :begin_date, Date.today.strftime 
                alignment_marker_stripwell.save
                release [alignment_marker_stripwell]  
                marker_in_analyzer.mark_as_deleted # trash outdated marker
            else # move current marker to SF2 (small fridge 2)
                marker_in_analyzer.location = "SF2"
                marker_in_analyzer.save
            end
        end
    end# def
    
    # checks to see if a marker in the fragment analyzer needs to be replaced. based on if there > 7 days or if theres no marker in there 
    # TODO: check for the different types of markers that go in the stripwell
    def check_alignment_marker(marker_name:)
        alignment_marker_sample = Sample.find_by(name: marker_name)
        stripwell_type = ObjectType.find_by(name: 'Stripwell')
        
        # all stripwells
        stripwells = Collection.where(object_type_id: stripwell_type.id).where.not(location: 'deleted')
        # all stripwells where the sample is the marker 
        marker_stripwells = stripwells.select { |s| s.part(0,0)&.sample_id == alignment_marker_sample.id }
        # all stripwells where the location is fragment analyzer 
        markers_in_analyzer = marker_stripwells.select { |s| s.location == "Fragment Analyzer" || s.location == "Fragment analyzer"}
        # check if the array of markers is > 
        raise "There can only be one Stripwell in the Fragment Analyzer" if markers_in_analyzer.length > 1
        # all stripwells where the location is not fragment analyzer 1
        stripwell_replacement = marker_stripwells.reject { |s| s.location == "Fragment Analyzer" || s.location == "Fragment analyzer"}
        
        stripwell_replacement = stripwell_replacement.first
        marker_in_analyzer = markers_in_analyzer.first
        
        raise "Stripwell - Fragment analyzer cannot be found" if marker_in_analyzer.nil?
        
        marker_needs_replacing = marker_in_analyzer.get(:begin_date) ? (Date.today - (Date.parse marker_in_analyzer.get(:begin_date)) >= 7) : true
        marker_needs_replacing = marker_needs_replacing && (markers_in_analyzer.length == 0)
        
        if marker_needs_replacing && stripwell_replacement
          show do
            title "Place stripwell #{stripwell_replacement} in buffer array"
            note "Move to the fragment analyzer."
            note "Open ScreenGel software."
            check "Click on the \"Load Position\" icon."
            check "Open the sample door and retrieve the buffer tray."
            warning "Be VERY careful while handling the buffer tray! Buffers can spill."
            check "Discard the current alignment marker stripwell (labeled #{marker_in_analyzer})."
            check "Place the alignment marker stripwell labeled #{stripwell_replacement} in the MARKER 1 position of the buffer array."
            image "make_marker_placement"
            check "Place the buffer tray in the buffer tray holder"
            image "make_marker_tray_holder"
            check "Close the sample door."
          end
          
          stripwell_replacement.location = "Fragment analyzer"
          stripwell_replacement.associate :begin_date, Date.today.strftime
          stripwell_replacement.save
          release [stripwell_replacement]
          marker_in_analyzer.mark_as_deleted
          
        end
    end
    
    #---------------------------------------------------------------------
    # upload raw data for the run
    # note - this data is NOT associated to any aquariom items
    #---------------------------------------------------------------------
    def rawDataUpload()
          # prepare raw data for upload
        show do
            title "Prepare to upload resulting analyzer data"
            check "Under <b>Analysis</b>. <b>Gel Image</b> tab, click <b>Select All</b>."
            check "Under the <b>View</b> tab, check <b>Show Analysis Parameters</b>."
            #image "frag_an_select_all"
        end
        # save run
        show do
            title "Save resulting analyzer data"
            check "Under the <b>Report</b> tab, click <b>Start Report/Export</b>."
            note "Wait while the files are generated."
            check "Under <b>File</b>-></b>Open Data Directory</b>, click <b>Export</b>."
            check "Copy the following files with today's date, and paste into <b>Documents/Raw Data</b>:"
            note "_Rw"
            note "_Rw.csv"
            note "_Go_150dpi_1"
            note "_Ex_PeakCalling.csv"
            #image "frag_an_files_to_upload"
        end
        # upload data 
        show do
            title "Upload resulting analyzer data"
            note "Upload the files ending in the following sequences:"
            note "_Rw"
            upload var: "Raw XML"
            note "_Rw.csv"
            upload var: "Raw CSV"
            note "_Go_150dpi_1"
            upload var: "Gel Image"
            note "_Ex_PeakCalling.csv"
            upload var: "Peak Calling CSV"
        end
    end # def
    
    #---------------------------------------------------------------------
    # check length of band(s) in each well, associate Y/N answer
    #---------------------------------------------------------------------
    def checkLengths(inputStr,lengthStr)
        ops_by_row = Hash.new { |hash, key| hash[key] = [] } # will hold Y/N length ok data
        operations.each do |op| # group by row
            ops_by_row["#{op.get(:qc_row)}"].push op
        end
        ops_by_row.each do |row, ops|
            data = show do
                title "Row #{row.to_i + 1}: verify that each lane matches expected size"
                note "Look at the gel image, and match bands with the lengths listed on the side of the gel image."
                note "For more accurate values, select each well under <b>analyze</b> -> <b>electropherogram</b> to see peaks for fragments found with labeled lengths."
                note "Select No if there is no band or band does not match expected size,
                select N/A if expected length is N/A and there is a band."
                ops.each do |op|
                    select ["Yes", "No","N/A"], 
                    var: "verify[#{op.get(:qc_row)}][#{op.get(:qc_column)}]", 
                    label: "Does gel lane in column #{op.get(:qc_column) + 1} match the expected length of #{op.input(lengthStr).val} bp?"
                end 
            end 
            # associate Y/N answers for row - to plan or to sample?
            ops.each do |op|
                item_id = op.input(inputStr).item.id
                op.plan.associate "qc_result_#{item_id}_row_#{op.get(:qc_row)}column_#{op.get(:qc_column)}", data["verify[#{op.get(:qc_row)}][#{op.get(:qc_column)}]".to_sym]
              op.input(inputStr).item.associate "qc_result_#{item_id}_row_#{op.get(:qc_row)}column_#{op.get(:qc_column)}", data["verify[#{op.get(:qc_row)}][#{op.get(:qc_column)}]".to_sym]
            end
        end
    end # def
    
    #---------------------------------------------------------------------
    # check length of band(s) in each well, associate Y/N answer
    # input: ops, operations list
    # jid - job id (for filenames)
    #---------------------------------------------------------------------
    def saveReportAndGelImages(inputStr, num_samples)
        
        # number of rows in striwell plate
        rows = (num_samples/WELLS_PER_STRIPWELL.to_f).ceil
        
        show do 
            title "Save PDF and gel images"
            note "If an error message occurs after the reports were generated, click <b>okay</b>"
            note "A PDF report is generated. Note that a separate gel image is generated for each stripwell row."
            check "For each gel image in the PDF, right-click on the image, copy it, and paste it into Paint. Then save to <b>Documents/Gel Images</b> for each row, with the filenames below:" 
            rows.times do |i|
                note "For Row #{i + 1}: stripwell_from_#{Time.now.strftime("%Y-%m-%d")}_#{jid}_row_#{i + 1}.JPG" # jid is JOB id
            end
            note "On the PDF, select <b>File -> Save As</b>, navigate to <b>Documents/PDF Report</b>, and save the PDF as <b>#{Time.now.strftime("%Y-%m-%d")}_#{jid}</b>"
            note "Close the PDF"
            note "You will now upload the PDFs and gel files"
        end
        
        # upload PDFs
        pdf_uploads=uploadData("Documents/PDF Report/#{Time.now.strftime("%Y-%m-%d")}_#{jid}.pdf",1,3)  # 1 file for whole plate
        gel_uploads=uploadData("Documents/Gel Images/#{Time.now.strftime("%Y-%m-%d")}_#{jid}_row_*.jpg",rows,3) # 1 image per row
        # associate gel,PDF images      
        operations.each do |op|
            if(!gel_uploads.nil?)
                rr=op.get(:qc_row) # position in gel_uploads, 0-based 
                if(!(gel_uploads[rr].nil?))
                    op.input(inputStr).item.associate "qc_image", gel_uploads[rr]
                    op.plan.associate "qc_image_#{op.input(inputStr).sample.id}", "QC Image", gel_uploads[rr]
                end
            end
            if(!pdf_uploads.nil?)
                op.input(inputStr).item.associate "qc_report", pdf_uploads[rr]
                op.plan.associate "qc_report_#{op.input(inputStr).sample.id}", "QC Report", pdf_uploads[0]
            end
        end
    end # def
    
    #---------------------------------------------------------------------
    # prepare and load the samples, including blank samples to complete row
    #---------------------------------------------------------------------
    def prepLoadSamples(inputStr, sampleTypes)
        
        # reformat input stripwells, associate positions on analyzer 96-well tray
        stripwells = operations.map { |op| op.input(inputStr).collection }.uniq
        
        case sampleTypes
        when 'DNA'
            # associate row, col for each sample
            operations.each_with_index do |op, i|
                op.associate :qc_row, (i/WELLS_PER_STRIPWELL.to_f).floor
                op.associate :qc_column, i % WELLS_PER_STRIPWELL
                #op.plan.associate "qc_row_and_column_#{op.input(inputStr).sample.id}", "Your QC result for #{op.input(inputStr).sample.id} is in row #{op.get(:qc_row)} and column #{op.get(:qc_column)}"
            end
            num_samples = 0
         
            show do 
                title "Relabel stripwells for stripwell rack arrangement"
                note "Place the stripwells in a green stripwell rack."
                note "To wipe off old labels, use ethanol on a Kimwipe."
                warning "Please follow each step carefully."
                # new label for each well
                stripwells.each_with_index do |s, i|
                    num_samples = num_samples + s.num_samples
                    note "Grab stripwell #{s} (#{s.num_samples} wells). Wipe off the current ID. Label the first well <b>#{i+1}</b>"
                end
            end
            
            rows = (num_samples/WELLS_PER_STRIPWELL.to_f).ceil
            # samples are sucked up as entire strips, so need to fill empty wells in last row with EB (techs have aliquots)
            eb_wells = rows*WELLS_PER_STRIPWELL - num_samples
            
            show do 
                title "Prepare EB stripwells"
                note "Make a stripwell of #{eb_wells} wells, pipette <b>10 uL</b> of <b>EB buffer</b> into each of its wells"
                note "Label the 1st well <b>#{stripwells.size+1}</b>"
            end
        
            show do 
                title "Uncap stripwells"
                note "Uncap the stripwells and make sure there are no air bubbles"
            end
        
            show do 
                title "Remove empty wells"
                note "Remove all empty wells from the stripwells"
                note "The size(s) of the stripwell(s) should be: "
                stripwells.each_with_index do |s, i|
                    note "<b>Stripwell #{i+1}:</b> #{s.num_samples} well(s)"
                end
                note "<b>EB:</b> #{eb_wells} well(s)"
            end
            # arrange stripwells before loading
            show do 
                title "Arrange stripwells in holder"
                note "Arrange the stripwells in the green tube rack so that there is a well in each column and row."
                note "Make sure to mantain the order of the stripwells, as labeled (1,2,3, etc.)"
            end 
        when 'RNA'
            # RNA QIAXcel prep before hand has empty wells filled with buffer; Make sure to direct tech to align stripwells correctly
            stripwell_to_row = Hash.new(0)
            tab = [['Stripwell ID','Row #']]
            
            stripwells.each_with_index do |s, idx| 
                tab.push([s.id, idx + 1])
                stripwell_to_row[s.id] = idx
            end
            
            groupby_stripwell = operations.group_by {|op| op.input(inputStr).item.id}
            groupby_stripwell.each do |stripwell, ops|
                ops.each_with_index do |op, i| 
                    op.associate :qc_row, stripwell_to_row[stripwell]
                    op.associate :qc_column, op.input(inputStr).column
                end
            end

            # Associate row, col for each sample - TODO: account for ladder in the first stripwell ie: if ladder sample type in stripwell.matrix add 1 to each column
            # operations.each_with_index do |op, i|
            #     op.associate :qc_row, (op.input(inputStr).row + 1 /WELLS_PER_STRIPWELL.to_f).floor
            #     op.associate :qc_column, op.input(inputStr).column % WELLS_PER_STRIPWELL
            # end

            show do 
                title 'Aligning RNA Samples for the Fragment Analyzer'
                separator
                note "<b>Follow the table below to align the stripwells correctly on the green tube rack.</b>"
                table tab
            end
            num_samples = 0
            stripwells.each do |s|
                s.matrix.each do |row|
                    row.each do |well| 
                        if well != -1
                            num_samples + 1
                        end
                    end
                end
            end
                
        end
        # log_info 'num_samples', num_samples
        # load samples
        show do 
            title "Arrange stripwells in fragment analyzer"
            note "Arrange the stripwells in the fragment analyzer in the EXACT SAME ORDER as they are arranged in the green tube rack."
            note "Close the lid on the machine."
        end
        
        #return 
        num_samples
        
    end # def
    
    #---------------------------------------------------------------------
    # run analyzer
    # inputs: num_samples - number of samples being run
    #         type_ind 
    #         cutoff_ind
    # returns: runs_left - number of remaining runs for cartridge
    #---------------------------------------------------------------------
    def runAnalyzer(num_samples,inhash)
        # select profile for run
        show do 
            title "Select #{QIAXCEL_TEMPLATE[inhash[:sampleTypes]]}" # this is just a profile name, should be ok for other polymerases
            note "Click <b>Back to Wizard</b> if previous data is displayed."
            check "Under <b>Process -> Process Profile</b>, make sure <b>#{QIAXCEL_TEMPLATE[inhash[:sampleTypes]]}</b> is selected."
        end
    
        # select alignment marker
        ref_marker = (inhash[:sampleTypes] == 'DNA') ? REF_MARKERS[inhash[:type_ind]][inhash[:cutoff_ind]] : REF_MARKERS[inhash[:type_ind] ]
        show do 
            title "Select alignment marker"
            check "Under  <b>Marker</b>, in the <b>Reference Marker </b> drop-down, select <b>#{ref_marker}</b>. A green dot should appear to the right of the drop-down."
        end
    
        # empty rows
        if inhash[:sampleTypes] == 'RNA'
            num_samples = num_samples + 1 # Include the ladder in the first well of the first stripwell
            nonempty_rows = (num_samples/WELLS_PER_STRIPWELL.to_f).ceil
            (num_samples % WELLS_PER_STRIPWELL) > 0 ? nonempty_rows + 1 : nonempty_rows
        else
            nonempty_rows = (num_samples/WELLS_PER_STRIPWELL.to_f).ceil
        end
        show do 
            title "Deselect empty rows"
            check "Under <b>Sample selection</b>, deselect all rows but the first #{nonempty_rows}."
        end
    
        # check 
        show do 
            title "Perform final check before running analysis"
            note "Under <b>Run Check</b>, manually confirm the following:"
            check "Selected rows contain samples."
            check "Alignment marker is loaded (changed every few weeks)."
        end
        
         # run and ask tech for remaining number of runs
        run_data = show do 
            title "Run analysis"
            note "If you can't click  <b>Run</b>, and there is an error that reads <b>The pressure is too low. Replace the nitrogen cylinder or check the external nitrogen source</b>, close the software, and reopen it. Then restart at title - <b>Select #{QIAXCEL_TEMPLATE[inhash[:sampleTypes]]} </b>"
            check "Otherwise, click <b>Run</b>"
            note "Estimated time of experiment is given at the bottom of the screen"
            get "number", var: "runs_left", label: "Enter the number of <b>Remaining Runs</b> left in this cartridge", default: 0
            #image "frag_an_run"
        end
        
        # return
        run_data[:runs_left]
        
    end # def
    
    #---------------------------------------------------------------------
    # For RNA QC - ELopez
    #---------------------------------------------------------------------
    def checkRIS(inputStr)
        
        img1 = 'Actions/RNA/RIS_QC_image.JPG'
        show do 
            title "Verfying mRNA Bands & RNA Integrity"
            separator
            note "The image below is an example of different levels of RNA integrity."
            bullet "The more prominent the two mRNA peaks are the higher the RNA integrity."
            image img1
            note "<b>Continue on to the next step to evaluate samples for RNA Integrity</b>"
        end
        
        ops_by_row = operations.group_by {|op| op.get(:qc_row) }
        log_info 'ops_by_row', ops_by_row
        
        rows = ('A'..'H').to_a
        ops_by_row.each do |row, ops|
            
            data = show do
                title "Row #{row.to_i + 1}: Verify mRNA Bands & RNA Integrity"
                separator
                note "Select each well under <b>analyze</b> -> <b>electropherogram</b> to see mRNA peaks."
                bullet "There should be two bands that correspond to yeast mRNA at ~<b>1800bp</b> (18S) and ~<b>3500bp</b> (28S)."
                ops.each do |op|
                    select ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'],
                    var: "[#{op.get(:qc_row)}, #{op.get(:qc_column)}]",
                    label: "What is the RNA Integrity Score of the electropherogram at position #{rows[row.to_i] + (op.get(:qc_column) + 1).to_s}"# "What is the RNA integrity number based on the electropherogram?"
                end
            end
            
            # Associate RIN to plan and to item that the sample in the well orginally came from - should be able to pull the matrix associate to stripwell
            ops.each do |op|
                stripwell = op.input(inputStr).item
                ris_val = data["[#{op.get(:qc_row)}, #{op.get(:qc_column)}]".to_sym]
                
                op.plan.associate("RNA Integrity Score for #{stripwell.id} Well #{op.get(:qc_column) + 1}", ris_val)
                stripwell.associate("RNA Integrity Score for Well #{op.get(:qc_column)}", ris_val)
                
                # Associate RNA Integrity Number to RNA Stock item
                well_to_item_hash = stripwell.get('well_to_item') # [row, col] => RNA Stock item id
                if !well_to_item_hash.nil?
                    rna_stock_item_id = well_to_item_hash["[0, #{op.get(:qc_column)}]"]
                    rna_stock_item = Item.find(rna_stock_item_id)
                    rna_stock_item.associate("RNA_Integrity_Score", ris_val)
                    # rna_stock_item.set_output_data("RNA_Integrity_Score".to_sym, ris_val)
                end
            end
        end
    end
    
    #---------------------------------------------------------------------
    # check cartridge
    # inputs: cartridge
    #         runs_left
    #---------------------------------------------------------------------
    def checkCartridge(cartridge,runs_left)
        if(cartridge.get(:runs_left) && (runs_left.to_f < 50) && (cartridge.get(:runs_left).to_f > runs_left.to_f ) )
            show do
                title "This cartridge is running low"
                warning "Please notify the lab manager that there are only <b>#{runs_left}</b> runs left in the current cartridge."
                cartridge.save
            end 
        end
        # update number of runs
        cartridge.associate(:runs_left, runs_left).save if cartridge
    end # def
    
    #--------------------------------------------------------------------- 
    # cleanup
    #---------------------------------------------------------------------
    def cleanup()
        show do
            title "Cleanup"
            check "Discard all stripwells" 
            check  "Click <b>Processes -> Parked</b> icon"
            warning "Make sure machine is in parked position"
            #image "frag_an_parked"
        end
    end # def
    
end # module
