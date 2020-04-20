class Protocol 
    
    def parse_csv csv
        x = csv.strip.split(/[\s,]+/)
    end

 
  def main
    
    debug = true 
    operations.retrieve(interactive: false)
    
    operations.each do |op|
        csv_str = op.input("Band Sizes").val
        csv = parse_csv csv_str
        op.associate :bands, csv
    end
        
    show do
      title "Fragment analyzing info"
      note "In this protocol, you will gather stripwells of digested plasmid, organize them in the fragment analyzer machine, and upload the analysis results to Aquarium."
    end

    # get cartridge 
    cartridge = find(:item, object_type: { name: "QX DNA Screening Cartridge" }).find { |c| c.location == "Fragment analyzer" }
    if cartridge
      take [cartridge]
    else
      cartridge = find(:item, object_type: { name: "QX DNA Screening Cartridge" })[0]

      show do
        title "Prepare to insert QX DNA Screening Cartridge into the machine"
        warning "Please keep the cartridge vertical at all times!".upcase
        check "Take the cartridge labeled #{cartridge} from #{cartridge.location} and bring to fragment analyzer."
        check "Remove the cartridge from its packaging and CAREFULLY wipe off any soft tissue debris from the capillary tips using a soft tissue."
        check "Remove the purge cap seal from the back of the cartridge."
        image "frag_an_cartridge_seal_off"
        warning "Do not set down the cartridge when you proceed to the next step."
      end

      show do
        title "Insert QX DNA Screening Cartridge into the machine"
        check "Use a soft tissue to wipe off any gel that may have leaked from the purge port."
        check "Open the cartridge compartment by gently pressing on the door."
        check "Carefully place the cartridge into the fragment analyzer; cartridge description label should face the front and the purge port should face the back of the fragment analyzer."
        check "Insert the smart key into the smart key socket; key can be inserted in either direction."
        image "frag_an_cartridge_and_key"
        check "Close the cartridge compartment door."
        check "Open the ScreenGel software and latch the cartridge by clicking on the \"Latch\" icon."
        check "Grab the purge port seal bag from the bottom drawer beneath the machine, put the seal back on its backing, and return it in the bag to the drawer."
      end
      
      unless cartridge.get(:runs)
       runs = show do 
              title "Enter number of runs"
              get "number", var: "runs", label: "Please enter the number of \"Remaining Runs\" left in this cartridge.", default: 0
          end
          
        cartridge.associate :runs, runs[:runs]
      end
          

      show do
        title "Wait 30 minutes for the cartridge to equilibrate"
        check "Start a <a href='https://www.google.com/search?q=30+minute+timer&oq=30+minute+timer&aqs=chrome..69i57j69i60.2120j0j7&sourceid=chrome&ie=UTF-8' target='_blank'>30-minute timer on Google</a>, and do not run the fragment analyzer until it finishes."
      end

      take [cartridge]
      cartridge.location = "Fragment analyzer"
      cartridge.save
    end

    alignment_marker = find(:item, sample: { name: "QX Alignment Marker (15bp/5kb)" })[0]
    marker_in_analyzer = find(:item, object_type: { name: "Stripwell" })
                            .find { |s| collection_from(s).matrix[0][0] == alignment_marker.sample.id &&
                                        s.location == "Fragment analyzer" }
    marker_needs_replacing = marker_in_analyzer.get(:begin_date) ? (Date.today - (Date.parse marker_in_analyzer.get(:begin_date)) >= 7) : true
    alignment_marker_stripwell = find(:item, object_type: { name: "Stripwell" })
                                  .find { |s| collection_from(s).matrix[0][0] == alignment_marker.sample.id &&
                                              s != marker_in_analyzer }
    if marker_needs_replacing && alignment_marker_stripwell
        
      show do
        title "Place stripwell #{alignment_marker_stripwell} in buffer array"
        note "Move to the fragment analyzer."
        note "Open ScreenGel software."
        check "Click on the \"Load Position\" icon."
        check "Open the sample door and retrieve the buffer tray."
        warning "Be VERY careful while handling the buffer tray! Buffers can spill."
        check "Discard the current alignment marker stripwell (labeled #{marker_in_analyzer})."
        check "Place the alignment marker stripwell labeled #{alignment_marker_stripwell} in the MARKER 1 position of the buffer array."
        image "make_marker_placement"
        check "Place the buffer tray in the buffer tray holder"
        image "make_marker_tray_holder"
        check "Close the sample door."
      end
      
      alignment_marker_stripwell.location = "Fragment analyzer"
      alignment_marker_stripwell.associate :begin_date, Date.today.strftime
      alignment_marker_stripwell.save
      release [alignment_marker_stripwell]
      delete marker_in_analyzer
      
    end

    num_samples = 0
    stripwells = operations.map { |op| op.input("Cut DNA").collection }.uniq


    show do 
        title "Uncap stripwells and fill empty wells"
        note "Uncap the stripwells and make sure there are no air bubbles"
        stripwells.each do |sp|
           check "Fill any empty wells of stripwell #{sp.id} with 10 µl of Miniprep Elution Buffer"
        end
    end

    show do 
      title "Arrange stripwells in fragment analyzer"
      note "Arrange the stripwells in the fragment analyzer in the following order starting from the top row (1):"
        stripwells.each do |sp|
           check "#{sp.id}"
        end
      note "Close the lid on the machine."
    end

    show do 
      title "Select PhusionPCR"
      note "Click \"Back to Wizard\" if previous data is displayed."
      check "Under \"Process\" -> \"Process Profile\", make sure \"PhusionPCR\" is selected."
    end

    show do 
      title "Select alignment marker"
      check "Under \"Marker\", in the \"Reference Marker\" drop-down, select \"15bp_5kb_022216\". A green dot should appear to the right of the drop-down."
    end

    show do 
      title "Deselect empty rows"
      check "Under \"Sample selection\", deselect all rows but the first #{stripwells.length}."
    end

    show do 
      title "Perform final check before running analysis"
      note "Under \"Run Check\", manually confirm the following:"
      check "Selected rows contain samples."
      check "Alignment marker is loaded (changed every few weeks)."
    end

    run_data = show do 
      title "Run analysis"
      note "If you can't click \"run\", and there is an error that reads, \"The pressure is too low. Replace the nitrogen cylinder or check the external nitrogen source,\" 
        close the software, and reopen it. Then repeat steps 9-13."
      check "Otherwise, click run"
      note "Estimated time is given at the bottom of the screen"
      get "number", var: "runs_left", label: "Enter the number of \"Remaining Runs\" left in this cartridge.", default: 0
      image "frag_an_run"
    end

    while run_data[:runs_left].nil? && !debug
      run_data = show do 
        title "Enter remaining runs"
        warning "Please enter the number of remaining runs left in this cartridge."
        get "number", var: "runs_left", label: "Enter the number of \"Remaining Runs\" left in this cartridge.", default: 0
      end
    end
    
    show do
      title "This cartridge is running low"
      warning "Please notify the lab manager that there are #{run_data[:runs_left]} runs left in the current cartridge."
      note "Thanks! :)"
      cartridge.save
    end if cartridge.get(:runs_left) && run_data[:runs_left] < 50 && (cartridge.get(:runs_left) / 10 > run_data[:runs_left] / 10)
    
    # make sure that when first using cartridge, the number of runs is entered
    cartridge.associate(:runs_left, run_data[:runs_left]).save if cartridge

    show do 
      title "Save PDF and gel images and upload PDF"
      note "If an error message occurs after the reports were generated, click \"okay.\""
      note "A PDF report is generated. Note that a separate \"gel image\" is generated for each stripwell row."
      check "For each gel image in the PDF, right-click on the image, copy it, and paste it into Paint. Then save to \"Documents/Gel Images\" for each row:"
      stripwells.length.times do |i|
        note "Row #{i + 1}: \"#{Time.now.strftime("%Y-%m-%d")}_#{jid}_row_#{i + 1}.JPG\" "
      end
      note "On the PDF, select \"File\" -> \"Save As\", navigate to \"Documents/PDF Report\", and save the PDF as \"#{Time.now.strftime("%Y-%m-%d")}_#{jid}\"."
      note "Upload the PDF"
      upload var: "Fragment Analysis Report"
      note "Close the PDF."
    end
    
    stripwells.each do |sp|
        i = 1
        gel_upload = show do 
          title "Upload resulting gel image for row #{i}"
          note "Upload \"stripwell_from_#{Time.now.strftime("%Y-%m-%d")}_row_#{i}.JPG\"."
          upload var: "row"
          image "frag_an_gel_image"
        end
    
        stripwell_ops = operations.select {|op| op.input("Cut DNA").collection.id == sp.id}

        stripwell_ops.each do |sops|
            sops.associate :frag_analyzer_result, gel_upload["row"]
        end
        i = 1 +1

    end

    verify_bands = show do
        note "Look at the gel image, and match bands with the lengths listed on the side of the gel image."
        note "For more accurate values, select each well under \"analyze\" -> \"electropherogram\" to see peaks for fragments found with labeled lengths."
        operations.each do |op|
            note "Expected band sizes #{op.get(:bands)}"
            select ["Correct" , "Incorrect"], var: "band_lengths_#{op.id}", label: "Are the results correct?", default: 0
        end
    end

        
        operations.each do |op|
            # These three lines find the plasmid stock used to prepare this restriction digest
            unless debug
                this_plan = op.plan.id
                digest_op_from_this_plan = Operation.where(operation_type_id: 466).select {|op| op.plan.id == this_plan}.first
                predecessor_plasmid_stock = digest_op_from_this_plan.input("DNA").item
            end
            
            if verify_bands["band_lengths_#{op.id}"] == "Correct"
                op.plan.associate :digest_result, "Your digest result was correct. Woohoo!"
                predecessor_plasmid_stock.associate :digest_result, "Digest results as expected"
            elsif verify_bands["band_lengths_#{op.id}"] == "Incorrect"
                op.plan.associate :digest_result, "Your digest result was incorrect"
                predecessor_plasmid_stock.associate :digest_result, "Digest results not as expected"
            end
        end

        
    # Upload raw data
    show do
      title "Prepare to upload resulting analyzer data"
      check "Under \"Analysis\". \"Gel Image\" tab, click \"Select All\"."
      check "Under the \"View\" tab, check \"Show Analysis Parameters\"."
      image "frag_an_select_all"
    end

    show do
      title "Save resulting analyzer data"
      check "Under the \"Report\" tab, click \"Start Report/Export\"."
      note "Wait while the files are generated."
      check "Under \"File\"->\"Open Data Directory\", click \"Export\"."
      check "Copy the following files with today's date, and paste into \"Documents/Raw Data\":"
      note "_Rw"
      note "_Rw.csv"
      note "_Go_150dpi_1"
      note "_Ex_PeakCalling.csv"
      image "frag_an_files_to_upload"
    end

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
    
    show do
      title "Discard stripwells"
      note "Please discard all stripwells."
    end
    
    show do
      title "Make sure machine in parked position"
      check "Click \"Processes\" -> \"Parked\" icon."
      image "frag_an_parked"
    end

    show do
      title "Move QX DNA Screening Cartridge to the fridge for the weekend"
      check "Go to R2, and retrieve the blister package labeled #{cartridge}."
      check "Grab the purge port seal from the bottom drawer beneath the fragment analyzer."
      check "Open ScreenGel software and unlatch the cartridge by clicking on the Unlatch icon."
      #image "frag_an_unlatch"
      check "Open the cartridge compartment on the fragment analyzer by gently pressing on the door."
      check "Remove the smart key."
      warning "Keep the cartridge vertical at all times!".upcase
      check "Close the purge port with the purge port seal."
      image "frag_an_cartridge_seal_on"
      check "Return the cartridge to the blister package by CAREFULLY inserting the capillary tips into the soft gel."
      check "Close the cartridge compartment door."
      check "Return the purge port seal backing to its plastic bag and place it back in the drawer."
      check "Store the cartridge upright in the door of R2 (B13.120)."
      cartridge.location = "R2 (B13.120)"
      cartridge.save
    end if Time.now.friday?
    release [cartridge] if cartridge
    
    operations.store io: "input"

  end

end