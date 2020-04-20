# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  ORDER = "Plasmid"

  def main

    # debuggin'
    if debug
      operations.first.set_input_data ORDER, :tracking_num, 12345
    end
    
    operations.retrieve interactive: false

    tracking_num = operations.first.input_data(ORDER, :tracking_num)
    
    results_info = show do
      title "Check if Sequencing results arrived?"
      
      check "Go the Genewiz website, log in with lab account (Username: biofab@uw.edu, password is glabuer1)."
      note "In Recent Results table, click Tracking Number #{tracking_num}, and check if the sequencing results have shown up yet."
      
      select ["Yes", "No"], var: "results_back_or_not", label: "Do the sequencing results show up?"
    end

    raise "The sequencing results have not shown up yet." if results_info[:results_back_or_not] == "No"

    sequencing_uploads_zip = show do
      title "Upload Genewiz Sequencing Results zip file"
      
      note "Click the button 'Download All Selected Trace Files' (Not Download All Sequence Files), which should download a zip file named #{tracking_num}-some-random-number.zip."
      note "Upload the #{tracking_num}_ab1.zip file here."
      
      upload var: "sequencing_results"
    end
    
    # TODO remove hacky way and replace with correct way
    operations.each { |op| op.temporary[:zip_name] = "#{tracking_num}_ab1" }
    op_to_file_hash = match_upload_to_operations operations, :zip_name, job_id=self.jid
    op_to_file_hash.each do |op, u|
        op.plan.associate "Order #{tracking_num} batched sequencing results", "Fresh out of the oven!", u
        op.input("Plasmid").item.associate "Order #{tracking_num} batched sequencing results", "Fresh out of the oven!", u
    end
    
    sequencing_uploads = show do
      title "Upload individual sequencing results"
      
      note "Unzip the downloaded zip file named #{tracking_num}_ab1.zip."
      note "If you are on a Windows machine, right click the #{tracking_num}-some-random-number.zip file, click Extract All, then click Extract."
      note "Upload all the unzipped ab1 file below by navigating to the upzipped folder."
      note "You can click Command + A on Mac or Ctrl + A on Windows to select all files."
      note "Wait until all the uploads finished (a number appears at the end of file name). "
      
      upload var: "sequencing_results"
    end
    
    # TODO remove hacky way and replace with correct way
    operations.each { |op| op.temporary[:seq_name] = "#{op.input(ORDER).item.id}" }
    op_to_file_hash = match_upload_to_operations operations, :seq_name, job_id=self.jid
    op_to_file_hash.each do |op, u|
        op.plan.associate "Item #{op.input(ORDER).item.id} sequencing results", "How do they look?", u
    end

    operations.each do |op|
      # find batched sequencing result
      #batched_sequencing_result_url = ""
    #   upload_zip_results = sequencing_uploads_zip[:sequencing_results]
    #   if upload_zip_results
    #     upload_zip = Upload.find(upload_zip_results[0][:id])
    #     op.plan.associate "Order #{tracking_num} batched sequencing results", "Fresh out of the oven!", upload_zip
    #   end
      
      # find sequencing result for op
      #sequencing_result_url = ""
      upload_results = sequencing_uploads[:sequencing_results] || []
      sequencing_upload_id = upload_results.find { |result| result[:name].include? op.input(ORDER).item.id.to_s }
      if sequencing_upload_id
        upload = Upload.find(sequencing_upload_id[:id])
        op.plan.associate "Item #{op.input(ORDER).item.id} sequencing results", "How do they look?", upload
        op.input("Plasmid").item.associate "Item #{op.input(ORDER).item.id}, primer #{op.input("Plasmid").item.get(:primer_id)} sequencing results", "How do they look?", upload
      end
        
      # Query user for next step
      op.plan.associate "Item #{op.input('Plasmid').item.id} sequencing ok?", "yes - discard plate and make glycerol stock, resequence - keep plate, plasmid stock, and overnight, no - discard plasmid stock and overnight"
      
      #pass through plasmid 
      op.pass("Plasmid","Plasmid")
    end

    return {}
    
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
                        basename.strip.include? op.temporary[filename_key].strip
                    end.first || nil
                    op_to_upload_hash[op] = upload
                end
            end
        op_to_upload_hash
    end

end