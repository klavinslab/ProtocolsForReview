#QUESTIONS: 
  #qc length is a precondition for colony pcr, right? so we shouldn't need "N/A" as an option?
  #is it okay if, instead of saying "stripwell A" i say "row 1"?
#TO DO: 
  #table!! make things nice and pretty. 
  # data associates get overwritten in the plan, 
 #NOTES: 
    # strain is only changed to "QC'd" = "Yes" if fragment analyzing is correct; if incorrect, goes unchanged

# UPDTAED: 10/23/18

needs 'Standard Libs/SortHelper'
needs "Standard Libs/AssociationManagement"
needs "Standard Libs/Feedback"
needs "Standard Libs/Units"
class Protocol 
  include SortHelper, AssociationManagement, Units
  include Feedback
  ANALYZER_COLUMNS = 12
  EXPECTED_LENGTH = "Expected Length"  
 
  def main
    debug = false 
    operations.retrieve
    # operations.each { |op| op.pass "Plate", "Plate" }

    # ensure that less than 96 wells have been submitted, error job otherwise - also returns total sample amount
    num_samples = check_max_samples_exceeded

    # explain protocol to tech
    introduction

    # get cartridge 
    cartridge = get_and_prep_cartridge

    # make sure the alignment marker in the analyzer is ready to go
    check_alignment_marker

    # array of stripwells for this job
    stripwells = operations.map { |op| op.input("PCR").collection }.uniq.sort { |a, b| a.id <=> b.id }

    # give stripwells a nickname id for this protocol
    relabel_stripwells stripwells
    
    # assign each sample a row col coord of their to-be location in the analyzer, and sort operationslist accordingly
    operations = assign_qc_row_col

    rows = (num_samples / ANALYZER_COLUMNS.to_f).ceil
    
    # add blank wells full of eb buffer to get to a multiple of ANALYZER_COLUMNS on last row. Returns size of eb stripwell.
    eb_wells = create_eb_filler_stripwell rows, num_samples, stripwells

    # uncap stripwells, remove empty wells, put in analyzer
    prepare_stripwells_for_analysis stripwells, num_samples, eb_wells
    
    # continue protocol from the fragment analyzer station
    change_station
    
    # put stripwells in machine
    put_stripwells_in_analyzer

    # enter settings into analyzer
    prepare_analyzer num_samples

    # run analyzer and collect data
    run_data = analyze_samples
    
    # update the runs left in this cartridge and make note if low
    update_cartridge cartridge, run_data

    # upload pdf and gel image, return a hash of ops as values of which row they are in
    ops_by_row = upload_images rows

    # decide whether Fragments are correct or incorrect and associate result to operations
    verify_band_match ops_by_row
    
    # At this point, all ops that haven't errored correspond to correct colony picks on the original plate
    # update the associations on the original plate to reflect this
    update_origin_plates
    
    #Debugging only
    log_qc_answers if debug

    # save and upload analyzer data
    upload_raw_data
    
    # clean up bench
    cleanup

    # release cartridge and store it for the weekend if necessary
    store_cartridge cartridge
    
    operations.store io: "input"
    
    get_protocol_feedback
  end
  
  # This method calculates the total number of samples and if the value is 
  # greater than 96, the operation will error and abort. Otherwise, this function 
  # returns the total number of samples calculated.
  def check_max_samples_exceeded
    # loop over each stripwell and sum the num samples in each to find total num samples
    num_samples = 0
    operations.map { |op| op.input("PCR").collection }.uniq.each do |stripwell|
      num_samples = num_samples + stripwell.num_samples
    end
    if  num_samples > 96
      operations.store io: "input", interactive: false
      raise "The fragment analyzer can only hold 96 samples at once. This job has #{num_samples} total samples"
    end
    num_samples
  end
  
  # This method displays an introduction to this protocol.
  def introduction
    show do
      title "Fragment analyzing info"
      note "In this protocol, you will gather stripwells of fragments, organize them in the fragment analyzer machine, and upload the analysis results to Aquarium."
    end
  end
  
  # This finds the QX DNA Screening Cartridge and tells the technician how to
  # properly prepare the cartridge. The function then returns this cartridge.
  def get_and_prep_cartridge
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
        image "Actions/Fragment Analyzer/frag_an_cartridge_seal_off.jpg"
        warning "Do not set down the cartridge when you proceed to the next step."
      end

      show do
        title "Insert QX DNA Screening Cartridge into the machine"
        check "Use a soft tissue to wipe off any gel that may have leaked from the purge port."
        check "Open the cartridge compartment by gently pressing on the door."
        check "Carefully place the cartridge into the fragment analyzer; cartridge description label should face the front and the purge port should face the back of the fragment analyzer."
        check "Insert the smart key into the smart key socket; key can be inserted in either direction."
        image "Actions/Fragment Analyzer/frag_an_cartridge_and_key.jpg"
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
    cartridge
  end
  
  # This method tells the technician to relabel stripwells.
  def relabel_stripwells stripwells
    show do 
      title "Relabel stripwells for stripwell rack arrangement"
      note "Place the stripwells in a green stripwell rack."
      note "To wipe off old labels, use ethanol on a Kimwipe."
      warning "Please follow each step carefully."
      stripwells.each_with_index do |s, i|
        note "Grab stripwell #{s.id} (#{s.num_samples} wells). Wipe off the current ID. Label the first well #{i + 1}"
      end
    end
  end
  
  # Directs tech to replace the alignment marker if it has been in the analyzer for 7 days or more.
  def check_alignment_marker
    alignment_marker = find(:item, sample: { name: "QX Alignment Marker (15bp/5kb)" })[0]
    marker_in_analyzer = find(:item, object_type: { name: "Stripwell" })
                            .find { |s| collection_from(s).matrix[0][0] == alignment_marker.sample.id &&
                                        s.location == "Fragment analyzer" }
    marker_needs_replacing = (!marker_in_analyzer.nil? && marker_in_analyzer.get(:begin_date)) ? (Date.today - (Date.parse marker_in_analyzer.get(:begin_date)) >= 7) : true
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
        check "Discard the current alignment marker stripwell (labeled #{marker_in_analyzer})." if marker_in_analyzer
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
      marker_in_analyzer.mark_as_deleted
    end
  end
  
  # First sort operations first by collection id, next by column of part (well index)
  # Then assign a qc_column and qc_row value to each op in op.temp[qc_row] and op.temp[qc_col] 
  # in the order of the new sorted operations list
  def assign_qc_row_col
    temp = sortByMultipleIO(operations, ["in", "in"], ["PCR", "PCR"], ["id", "column"], ["collection", "io"])
    operarations = temp
    
    # TODO account for ridealong samples which are not actually operations but are in the stripwell and count towards num_sample total
    operations.each_with_index do |op, i|
      op.associate :qc_row, (i / ANALYZER_COLUMNS.to_f).floor
      op.associate :qc_column, i % ANALYZER_COLUMNS
      rep = 1;
      existing_rc_assoc = op.plan.get "qc_row_and_column_#{op.input("PCR").sample.id}"
      while (existing_rc_assoc) do
        rep += 1
        existing_rc_assoc = op.plan.get "qc_row_and_column_#{op.input("PCR").sample.id}_rep#{rep}"
      end
      key = if rep > 1
        "qc_row_and_column_#{op.input("PCR").sample.id}_rep#{rep}"
      else
        "qc_row_and_column_#{op.input("PCR").sample.id}"
      end
      
      op.plan.associate key, "Your QC result for #{op.input("PCR").sample.id} is in row #{op.get(:qc_row) + 1} and column #{op.get(:qc_column) + 1}"
    end
    operations
  end
  
  # This method tells the technician to fill stripwells with EB buffer.
  def create_eb_filler_stripwell rows, num_samples, stripwells
    eb_wells = rows * ANALYZER_COLUMNS - num_samples

    show do 
      title "Fill blank wells"
      note "Make a stripwell of #{eb_wells} wells, pipette 10 #{MICROLITERS}L of EB buffer into each of its wells."
      note "Label the 1st well of this new stripwell #{stripwells.size + 1}"
    end
    eb_wells
  end
  
  # This method tells the technician to prepare stripwells by uncapping them,
  # removing empty wells, and arranging stripwells in the holder.
  def prepare_stripwells_for_analysis stripwells, num_samples, eb_wells
    show do 
      title "Uncap stripwells"
      note "Uncap the stripwells and make sure there are no air bubbles"
    end

    show do 
      title "Remove empty wells"
      note "Remove all empty wells from the stripwells"
      note "The size of the stripwells should be as follows: "
      stripwells.each_with_index do |s, i|
        note "Stripwell #{i + 1}: #{s.num_samples} wells"
      end
      note "Stripwell #{stripwells.size + 1}: #{eb_wells}" if !eb_wells.zero?
    end

    show do 
      title "Arrange stripwells in holder"
      note "Arrange the stripwells in the green tube rack so that there is a well in each column and row."
      note "Make sure to mantain the order of the stripwells, as labelled."
    end 
  end
  
  # This method tells the technician to continue the protocol from the Fragment Analyzer station.
  def change_station
      show do
        title "Changing Places!"
        note "We will continue this protocol from the Fragment Analyzer station."
        note "You will have to open this current running job (#{self.jid}) through the manager page on the computer at that station."
    end
  end
  
  # This method tells the technician to arrange the stripwells in the
  # fragment analyzer in the same order as they are arranged in the green tube rack.
  def put_stripwells_in_analyzer
    show do 
      title "Arrange stripwells in fragment analyzer"
      note "Arrange the stripwells in the fragment analyzer in the EXACT SAME ORDER as they are arranged in the green tube rack."
      note "Close the lid on the machine."
    end
  end
  
  # This method tells the technician how to prepare the fragment analyzer.
  def prepare_analyzer num_samples
    show do
        title "Open QiAxcel"
        note "Once you are running this job on the Fragment Analyzer computer, open the QiAxcel software from the windows dockbar."
        note "The next steps are to be performed in the QiAxcel software."
    end
    
    show do 
      title "Prepare Fragment Analyzer"
      note "Click \"Back to Wizard\" if previous data is displayed."
      check "Under \"Process\" -> \"Process Profile\", make sure \"PhusionPCR\" is selected."
      
      check "Under \"Marker\", in the \"Reference Marker\" drop-down, select \"15bp_5kb_022216\". A green dot should appear to the right of the drop-down."
      
      check "Under \"Sample selection\", deselect all rows but the first #{(num_samples / ANALYZER_COLUMNS.to_f).ceil}."
      
      note "Perform final check before running analysis"
      note "Under \"Run Check\", manually confirm the following:"
      check "Selected rows contain samples."
      check "Alignment marker is loaded (changed every few weeks)."
    end
  end
  
  # This method allows the technician to run analysis on samples. It prompts the technician
  # to keep running the samples until all runs are done. It then returns the run data.
  def analyze_samples
    run_data = show do 
      title "Run analysis"
      note "If you can't click \"run\", and there is an error that reads, \"The pressure is too low. Replace the nitrogen cylinder or check the external nitrogen source,\" 
        close the software, and reopen it. Then repeat steps 9-13."
      check "Otherwise, click run"
      note "Estimated time is given at the bottom of the screen"
      get "number", var: "runs_left", label: "Enter the number of \"Remaining Runs\" left in this cartridge.", default: 0
      image "Actions/Fragment Analyzer/frag_an_run.jpg"
    end

    while run_data[:runs_left].nil? && !debug
      run_data = show do 
        title "Enter remaining runs"
        warning "Please enter the number of remaining runs left in this cartridge."
        get "number", var: "runs_left", label: "Enter the number of \"Remaining Runs\" left in this cartridge.", default: 0
      end
    end
    run_data
  end
  
  # This method tells the technician to replace the cartridge if its remaining uses is low.
  # It also associates the number of runs left to the cartridge.
  def update_cartridge cartridge, run_data
    if cartridge.get(:runs_left) && run_data[:runs_left] < 50 && (cartridge.get(:runs_left) / 10 > run_data[:runs_left] / 10)
      show do
        title "This cartridge is running low"
        warning "Please notify the lab manager that there are #{run_data[:runs_left]} runs left in the current cartridge."
        note "Thanks! :)"
        cartridge.save
      end 
    end
    # make sure that when first using cartridge, the number of runs is entered
    cartridge.associate(:runs_left, run_data[:runs_left]).save if cartridge
  end
  
  # This method prompts the technican to upload gel images. It also associates
  # QC images to the correct plan.
  def upload_images rows
    show do
        title "Analysis in Progress"
        note "Wait ~9 min for the fragment analyzer to finish analyzing the samples, then move on to the next steps."
    end
    
    show do 
      title "Save PDF and gel images and upload PDF"
      note "If an error message occurs after the reports were generated, click \"okay.\""
      note "A PDF report is generated. Note that a separate \"gel image\" is generated for each stripwell row."
      check "For each gel image in the PDF, right-click on the image, copy it, and paste it into Paint. Then save to \"Documents/Gel Images\" for each row:"
      rows.times do |i|
        note "Row #{i + 1}: \"#{Time.now.strftime("%Y-%m-%d")}_#{jid}_row_#{i + 1}.JPG\" "
      end
      note "On the PDF, select \"File\" -> \"Save As\", navigate to \"Documents/PDF Report\", and save the PDF as \"#{Time.now.strftime("%Y-%m-%d")}_#{jid}\"."
      note "Upload the PDF"
      upload var: "Fragment Analysis Report"
      note "Close the PDF."
    end
    gel_uploads = []
    rows.times do |i|
      n = 0
      while n == 0 || (gel_uploads[i][:row].blank? && n <= 5)
        gel_uploads[i] = show do 
          title "Upload resulting gel image for row #{i+1}"
          note "Upload \"#{Time.now.strftime("%Y-%m-%d")}_#{jid}_row_#{i+1}.JPG\"."
          upload var: "row"
          image "Actions/Fragment Analyzer/frag_an_gel_image.JPG"
        end
        
        n = n + 1

        show do 
          title "Alright then"
          note "It seems you're having trouble uploading the gel image--if this is due to an error in the protocol, please report this to a BIOFAB lab manager."
        end if n > 5
      end
    end

    ops_by_row = Hash.new { |hash, key| hash[key] = [] }

    operations.each do |op|
      #   show { title "thing"; note gel_uploads[op.get(:qc_row)].to_s; note op.get(:qc_row).to_s }
        if gel_uploads[op.get(:qc_row)][:row].present?
          uid = gel_uploads[op.get(:qc_row)][:row][0][:id]
      end
      #   show { title "DEBUGGIN'"; note op.get(:qc_row).to_s; note gel_uploads[op.get(:qc_row)][:row].to_s }
      op.plan.associate "qc_image_#{op.input("PCR").sample.id}_#{jid}", "QC Image", Upload.find(uid) if uid 
      
      ops_by_row["#{op.get(:qc_row)}"].push op
    end
    ops_by_row
  end
  
  # This method first asks the technician to verify that each gel lane matches
  # the expected size. If it does match, then the correct qc result will be associated
  # with the plan. If it doesn't match, an incorrect qc result will be associated with
  # the plan. The method will finally make items for operations that have good results.
  def verify_band_match ops_by_row
    verify_data = {}

    ops_by_row.each do |row, ops|
      verify_row = show do
        title "Row #{row.to_i + 1}: verify that each lane matches expected size"
        note "Bring up the relevant gel image on QiAxcel by navigating to \"analyze\" and dragging the correctly named file from the left sidebar into the center."
        note "Look at the gel image, and match bands with the lengths listed on the side of the gel image."
        note "For more accurate values, select each well under \"analyze\" -> \"electropherogram\" to see peaks for fragments found with labeled lengths."
        note "Select No if there is no band or band does not match expected size,
        select N/A if expected length is N/A and there is a band."
        
        ops.each do |op|
          if op.get(EXPECTED_LENGTH).nil?
            (op.input('PCR').sample_type.name == 'Fragment') ? expected_length = op.input("PCR").sample.properties['Length'] : expected_length = op.input("PCR").sample.properties["QC_length"]
          else
            expected_length = op.get(EXPECTED_LENGTH)
          end
          select ["Yes", "No","N/A"], 
          var: "verify[#{row.to_i}][#{op.get(:qc_column)}]", 
          label: "Does gel lane in column #{op.get(:qc_column) + 1} match the expected length of #{expected_length} bp?"
        end
      end
      verify_data[row.to_i] = verify_row
    end

    #associate results with operations.
    operations.select { |op| op.input("PCR").sample_type.name != 'Plasmid' }.select {|op| op.input("PCR").sample_type.name != 'Fragment'}.each do |op|
      plate = Item.find_by_id(op.plan.get(:plate).to_i) if op.plan.get(:plate)
      col = op.get(:qc_column)
      row = op.get(:qc_row)
      band_match = verify_data[row]["verify[#{row}][#{col}]".to_sym]
      sample_id = op.input("PCR").sample.id
      qc_answer =  FieldValue.where(parent_id: sample_id, parent_class: "Sample", name: "Has this strain passed QC?").first
      
      if !debug # testing mode fails for this section
        if qc_answer.nil?
          raise "invalid qc answer for sample #{sample_id} of operation #{op.id}"
        end
        
        if band_match == "Yes"
          op.plan.associate "qc_result_#{sample_id}_column_#{col + 1}", "Your QC result was correct. Woohoo!"
          qc_answer.value = "Yes"
          qc_answer.save 
        elsif band_match == "N/A"
          op.error :qc_result, "Your QC result was inconclusive. Please input a QC length."
        elsif band_match == "No"
          op.plan.associate "qc_result_#{sample_id}_column_#{col + 1}", "Your QC result was incorrect. Oh no."
          if qc_answer.value != "Yes" 
              qc_answer.value = "No"
              qc_answer.save
          end
          op.error :bad_qc, "Sorry, you don't want to use this colony."
        else
          # probably verify_data hash is not getting built up correctly. Should never enter this branch
          raise "invalid band match answer for #{sample_id} of operation #{op.id} in column #{col}"
        end
      end
    end

    # Confirm operations with good results
    operations.select { |op| verify_data[op.get(:qc_row)]["verify[#{op.get(:qc_row)}][#{op.get(:qc_column)}]".to_sym] == "Yes" }.make
  end
  
  # This prompts the technician to upload resulting analyzer data.
  def upload_raw_data
    show do
      title "Prepare to upload resulting analyzer data"
      check "Under \"Analysis\". \"Gel Image\" tab, click \"Select All\"."
      check "Under the \"View\" tab, check \"Show Analysis Parameters\"."
      image "Actions/Fragment Analyzer/frag_an_select_all.JPG"
    end

    show do
      title "Save resulting analyzer data"
      warning "Ensure that \"RawCSVAndGelImage\" is selected under the \"Report/Export Profile\" dropdown menu"
      check "Under the \"Report\" tab, click \"Start Report/Export\"."
      note "Wait while the files are generated."
      check "Under \"File\"->\"Open Data Directory\", click \"Export\"."
      check "Copy the following files with today's date, and paste into \"Documents/Raw Data\":"
      note "_Rw"
      note "_Rw.csv"
      note "_Go_150dpi_1"
      note "_Ex_PeakCalling.csv"
      image "Actions/Fragment Analyzer/frag_an_files_to_upload.JPG"
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
  end
  
  # This method tells the technician to clean up.
  def cleanup
    show do
      title "Discard stripwells"
      note "Please discard all stripwells."
      operations.each do |op|
          op.input("PCR").collection.mark_as_deleted
      end
    end
    
    show do
      title "Make sure machine in parked position"
      check "Click \"Processes\" -> \"Parked\" icon."
      image "Actions/Fragment Analyzer/frag_an_parked.JPG"
    end
  end
  
  # This method tells the technician to store cartridges.
  def store_cartridge cartridge
    show do
      title "Move QX DNA Screening Cartridge to the fridge for the weekend"
      check "Go to R2, and retrieve the blister package labeled #{cartridge}."
      check "Grab the purge port seal from the bottom drawer beneath the fragment analyzer."
      check "Open ScreenGel software and unlatch the cartridge by clicking on the Unlatch icon."
    #   image "Actions/Fragment Analyzer/frag_an_unlatch.jpg" # image does not exist
      check "Open the cartridge compartment on the fragment analyzer by gently pressing on the door."
      check "Remove the smart key."
      warning "Keep the cartridge vertical at all times!".upcase
      check "Close the purge port with the purge port seal."
      image "Actions/Fragment Analyzer/frag_an_cartridge_seal_on.jpg"
      check "Return the cartridge to the blister package by CAREFULLY inserting the capillary tips into the soft gel."
      check "Close the cartridge compartment door."
      check "Return the purge port seal backing to its plastic bag and place it back in the drawer."
      check "Store the cartridge upright in the door of R2 (B13.120)."
      cartridge.location = "R2 (B13.120)"
      cartridge.save
    end if Time.now.friday?
    release [cartridge] if cartridge
  end
  
  # This method will associate correct colonies to the origin plates in order to update origin plates.
  def update_origin_plates
      # operations that have not yet errored are guarenteed to correspond to correct colonies on the original plates.
      # we will update the associations of the origin plate for each op to reflect this new verified colony
      operations.running.select { |op| op.input("PCR").sample_type.name != 'Plasmid' }.each do |op|
          # Use association map to cleanly deal with data associated to parts of a collection
          colony_pick = op.input("PCR").part.get(:colony_pick).to_i
          origin_plate_id = op.input("PCR").part.get(:origin_plate_id).to_i
          
          if origin_plate_id && Item.exists?(origin_plate_id) && colony_pick
              origin_plate = Item.find(origin_plate_id)
              correct_colonies = origin_plate.get(:correct_colonies) ? origin_plate.get(:correct_colonies) : []
              
              # rely on idempotence of .to_s to normalize correct 
              # colony association into an array regardless
              # of whether it started in array or string format.
              correct_colonies.to_s.chomp(']').chomp!('[') #convert Array to string representation if Array and remove brackets (if string: stays the same)
              correct_colonies = correct_colonies.split(",") #string array back to array
              
              correct_colonies.push "c#{colony_pick}"
              origin_plate.associate(:correct_colonies, correct_colonies)
          end
      end
  end
  
  # This method will display whether this strain pased QC.
  def log_qc_answers
    show do 
      operations.each do |op|
        sample_id = op.input("PCR").sample.id
        qc_answer =  FieldValue.where(parent_id: sample_id, parent_class: "Sample", name: "Has this strain passed QC?").first
        note "#{qc_answer.value}"
      end
    end
  end
end