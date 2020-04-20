needs "Tissue Culture Libs/TissueCulture"

# TODO: Add specific media
# TODO: Add explicit message about items that have been deleted due to "Missing" status, confirm Missing as well
# TODO: Change file name so that you can easily double click
# TODO: Create an ordering by item number method so everything is in order on the table
# TODO: Display images in final table...
class Protocol
  include TissueCulture

  TEST_CONTAMINATION = false
  TEST_MISSING = false

  DEBUG_EXPERT_MODE = false

  STATUS_MISSING = "Missing"
  STATUS_CONTAMINATED = "Contaminated"
  STATUS_OK = "OK"

  BUFFER_CHOICES = ["yellow", "orange", "red", "magenta", "purple"]
  CONFLUENCY_CHOICES = (0..100).step(10).map { |x| "#{x}%" } + [STATUS_MISSING, STATUS_CONTAMINATED]
  
  def main

    now = get_time_now
    folder_name = "Desktop/MicroscopeImages/<b>#{now.year}#{now.month}#{now.day}</b>"

    # Gather Plates
    vops = get_plates_as_vop
    plates = vops.map { |op| op.temporary[:plate] }

    # Save potential image_name
    vops.each do |op|
      p = op.temporary[:plate]
      op.temporary[:image_name] = "10X__#{get_timestamp_now}_#{p.id}"
    end

    required_ppe(STANDARD_PPE)

    prepare_camera_and_computer(now)

    skip_yes = "Yes, I know what I'm doing"
    skip_no = "No, I need instruction on how to record confluencies."
    skip = show do
      title "Skip to quick table?"

      select [skip_no, skip_yes], var: :skip, label: "Would you like to continue in <i>expert</i> mode?", default: 3
    end

    if debug
      skip[:skip] = skip_yes if DEBUG_EXPERT_MODE
    end

    if skip[:skip] != skip_yes
      return_table = nil
      vops.each_slice(3).each do |op_list|
        op_list.extend(OperationList)

        show do
          if return_table
            title "Return checked plates and gather unchecked plates"
            check "Return the following plates to the #{INCUBATOR}"
            table return_table
            separator
          else
            title "Gather unchecked plates"
          end
          check "Move the following plates from the #{INCUBATOR} to an area near the microscope"
          table op_list.start_table
                    .custom_column(heading: "Plate") { |op| "#{op.temporary[:plate].id} (#{op.temporary[:plate].object_type.name})" }
                    .custom_column(heading: "Move From") { |op| "#{op.temporary[:plate].location}" }
                    .custom_column(heading: "Move To") { |op| "Microscope area" }
                    .end_table
        end

        op_list.each do |op|

          confluency_input = show do
            title "Record confluency and note buffer color"
            check "Place plate #{op.temporary[:plate]} on the microscope stage"
            check "While observing in the Video tab of the ToupView software, focus on cells using dial on the right of the microscope."
            check "With the cells in focus, click <b>Snap</b> in the ToupView software"
            check "Click <b>Save As</b> and name the file #{op.temporary[:image_name].bold} and save it in #{folder_name.ital}"
            select BUFFER_CHOICES, var: :buffer_color, label: "Select the color of the buffer", default: 2
            select CONFLUENCY_CHOICES, var: CONFLUENCY, label: "Estimate the confluency of the plate", default: 0

            note display_image("Actions/MammalianCellImages/confluency2.jpg", width: "50%", height: "50%")
          end

          op.temporary[CONFLUENCY] = confluency_input[CONFLUENCY]
          op.temporary[:buffer_color] = confluency_input[:buffer_color]

          if debug
            if TEST_CONTAMINATION
              op.temporary[CONFLUENCY] = STATUS_CONTAMINATED
            elsif TEST_MISSING
              op.temporary[CONFLUENCY] = STATUS_MISSING
            end
          end

          op.temporary[:status] = op.temporary[CONFLUENCY]
          op.temporary[:status] = STATUS_OK if not [STATUS_MISSING, STATUS_CONTAMINATED].include?(op.temporary[:status])
          interpret_status(op) #case

          if op.temporary[:status] == STATUS_CONTAMINATED
            show do
              title "Remove plate #{op.temporary[:plate]} from microscope"
              warning "You designated plate #{op.temporary[:plate]} as being contaminated. It will be sterilized and deleted."
              check "Place plate in sink area for future disposal"
              check "Ethanol you gloves after handling plate."
            end
          end
        end

        if op_list.running.empty?
          return_table = nil
        else
          return_table = op_list.running.start_table
                             .custom_column(heading: "Plate") { |op| op.temporary[:plate].id }
                             .custom_column(heading: "Location") { |op| op.temporary[:plate].location }
                             .end_table
        end
      end

      if return_table
        show do
          title "Return plates"
          check "Return the following plates"
          table return_table
        end
      end
    end #if

    ask_for_image_uploads(vops.running, folder_name, job_id = self.jid)

    display_full_table(vops)

    show do
      title "Turn OFF the microscope"
      check "Turn OFF the microscope by uplugging in the cable"
    end

    non_missing_ops = vops.select { |op| op.temporary[:status] == STATUS_CONTAMINATED }
    release_tc_plates(non_missing_ops.map { |op| op.temporary[:plate] }) # Return any plates that had an error that are not missing

    if non_missing_ops.any?
      show do
        title "Notify users of contamination"
        note "This feature is not yet implemented."
        check "Please notify the owners of the following plates that their plates were contaminated:".bold
        non_missing_ops.each do |op|
          check "#{op.temporary[:plate]} #{op.temporary[:plate].sample.user.name}"
        end
      end
    end #if
    
    non_missing_ops.each { |op| op.output(OUTPUT).item = op.input(INPUT).item }

    return {}
  end

  def prepare_camera_and_computer(now)
    show do
      title "Prepare computer"
      note "<b>Create a new folder for images</b>"
      check "If necessary, turn on computer near the small microscope"
      check "On the Desktop, double click on the folder MicroscopeImages"
      check "Create a new folder in MicroscopeImages named <b>#{now.year}#{now.month}#{now.day}</b>"
    end

    show do
      title "Open ToupView imaging software"
      check "Using 70% ethanol, wipe down the stage of the microscope"
      check "Turn ON the microscope by plugging in the cable"
      note "<b>Connect camera to computer</b>"
      note "There is a camera attached to the microscope near the computer"
      check "Make sure camera is connected to the computer via USB"
      separator
      note "<b>Open imaging software</b>"
      check "Open <b>ToupView</b> on the computer by clicking the ToupView icon"
      check "Click the \"Video [...]\" tab in the ToupView software"
      check "Verify camera is functional"
      check "Click \"White Balance\" on the left hand size to color correct"
      check "In the ToupView software, click \"White Balance\" on the left hand size to color correct"
    end

    show do
      title "Ethanol your gloves before proceeding"
    end
  end

  def interpret_status(op)
    case op.temporary[:status]
      when STATUS_MISSING
        op.temporary[:plate].mark_as_deleted
        op.temporary[:plate].associate op.temporary[:status], "This plate was not found on #{Time.now} and was marked as deleted."
      # op.error :missing, ""
      when STATUS_CONTAMINATED
        op.temporary[:plate].mark_as_deleted
        op.temporary[:plate].associate op.temporary[:status], "This plate was found to be contaminated on #{Time.now}."
      # op.error :contaminated, ""
      when STATUS_OK
        op.temporary[CONFLUENCY] = op.temporary[CONFLUENCY].to_s.split("%").first.to_f
    end
  end

  def ask_for_image_uploads(myops, folder_name, job_id = nil)
    if myops.empty?
      return
    end
    # Upload images
    continue_upload = true
    counter = -1
    msg = ""
    while counter < 5 and continue_upload
      counter += 1
      create_image_table = Proc.new { |ops|
        ops.start_table
            .custom_column(heading: "Plate") { |op|
          "#{op.temporary[:plate].id} (#{op.temporary[:plate].object_type.name})" }
            .custom_column(heading: "Image Name") { |op| op.temporary[:image_name] }
            .custom_column(heading: "Image") { |op|
          upload_file = op.temporary[:upload]
          val = {content: "Missing", check: false}
          val.merge!({content: "Uploaded!"}) if upload_file
          val
        }.end_table.all
      }

      upload_input = show do
        title "Upload images"
        if not msg.empty?
          warning msg
        end
        check "Upload all images located in #{folder_name.ital}"
        note "You can <b>Shift+Select</b> to select multiple images at once."
        upload var: :confluency_images

        table create_image_table.call(myops)
      end

      # TODO: Fix when uploads are associated with show block hash
      uploads = upload_input[:confluency_images] || []
      uploads = Upload.where("job_id" => job_id).to_a if job_id
      uploads ||= []
      if debug
        u = myops.first.temporary[:upload]
        uploads << {upload_file_name: myops.first.temporary[:image_name], id: 1} if u.nil?
      end
      image_hash = match_upload_to_operations(myops, :image_name, job_id, uploads)
      image_hash.each { |op, u| op.temporary[:upload] = u if u }
      msg = ""
      if myops.all? { |op| op.temporary[:upload] }
        continue_upload = false
      else
        continue_upload = true
        msg = "Some image files are missing. Make sure you named your uploaded image correctly."
      end #if

      # Allow technician to force early exit
      if continue_upload
        continue = show do
          title "Continue without finishing uploads?"
          select ["No", "Yes"], var: :continue, label: "Are you sure you want to continue without uploading missing images?", default: 0
          table create_image_table.call(myops)
        end
        continue[:continue] = "Yes" if debug
        continue_upload = false if not continue[:upload] or continue[:continue] == "Yes"
      end #if
    end #while

    #   if uploads.any?
    #     myops.each do |op|
    #       # Save upload results
    #       upload = uploads.select {|u|
    #         extension = File.extname(u[:upload_file_name])
    #         basename = File.basename(u[:upload_file_name], extension)
    #         basename == op.temporary[:image_name]
    #       }.first || nil
    #       if upload
    #         upload_file = Upload.find_by_id(upload[:id])
    #         op.temporary[:upload] = upload_file
    #       end
    #     end
  end

  def match_upload_to_operations ops, filename_key, job_id=nil, uploads=nil
    def extract_basename filename
      ext = File.extname(filename)
      basename = File.basename(filename, ext)
    end

    op_to_upload_hash = Hash.new
    uploads ||= Upload.where("job_id" => job_id).to_a if job_id
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

  def display_full_table(myops)
    # CSS and HTML like elements

    greencell = {style: {color: "white", "background-color" => "green"}, check: false}
    redcell = {style: {color: "white", "background-color" => "red"}, check: false}
    color_table_matrix = \
                '<table style="width:100%">
                    <tr>
                        <th colspan="4">Buffer Color</th>
                    </tr>
    	            <tr>
    		            <th bgcolor="yellow"> y </th>
    		            <th bgcolor="orange"> o </th>
    		            <th bgcolor="red"><font color="white"> r </font></th>
    		            <th bgcolor="purple"><font color="white"> p </font></th>
    	            </tr>
                </table>'
    create_table = Proc.new { |ops|
      ops.start_table
          .custom_column(heading: "Plate id") { |op|
        x = {content: op.temporary[:plate].id, check: true}
      }
          .custom_input(CONFLUENCY, heading: "Confluency (%)", type: "number") { |op|
        c = op.temporary[CONFLUENCY] || op.temporary[:plate].confluency
        c = rand(50..100) if debug
        c
      }
          .validate(CONFLUENCY) { |op, val| valid_confluency?(val) }
          .validation_message(CONFLUENCY) { |op, k, v|
        "Confluency for plate #{op.temporary[:plate]} is invalid. Should be between 0 and #{MAX_CONFLUENCY}" }
          .custom_input(:buffer_color, heading: color_table_matrix, type: "string") { |op| op.temporary[:buffer_color] || 'red' }
          .custom_selection(:status, [STATUS_OK, STATUS_MISSING, STATUS_CONTAMINATED], heading: "Status") { |op| op.temporary[:status] || STATUS_OK }
          .custom_column(heading: "Image Name") { |op| op.temporary[:image_name] }
          .custom_column(heading: "Image Uploaded?") { |op|
        upload_file = op.temporary[:upload]
        val = {content: "Missing", check: false}
        # val.merge!({content: image_tag_from_upload(upload_file)}) if upload_file
        val.merge!({content: "Uploaded!"}) if upload_file
        val
      }
          .end_table.all
    }

    show_with_input_table(myops, create_table) do
      title "Review"
      note "The full results of your selections are displayed below"
      check "Make any necessary edits."
    end

    myops.each { |op| interpret_status(op) }

    myops.each do |op|
      upload = op.temporary[:upload]
      upload = nil if not upload.is_a? Upload
      op.temporary[:plate].update_confluency(op.temporary[CONFLUENCY],
                                             upload: upload,
                                             buffer_color: op.temporary[:buffer_color])
    end
  end # display_full_table

end # Protocol