class Protocol

  def main
    data_associations = []
    operations.each do |op|
        jobs = jobs_from_plan(op.plan)
        
        show do
          title "Access Network Drive"
          note "Open a connection to the samba share drive where the experimental results live"
          warning "smb://128.95.114.54"
        end
        
        jobs.each do |j|
          op_type = j.operations.first.operation_type.name 
          if op_type == 'Sort Yeast Display Library'
              data_associations.concat(lazy_associate_fcs_uploads(j, "fcs_measurement", get_fcs_uploads(j))) # gets uploads, makes new associations from uploads, concats these associations to complete association list
          end
        end
        
        show do
          title "Sorting Files"
          note "Next we will upload the sorting files for each job."
          note "You will need to manually inspect the contents of some files before uploading"
          note "To make this easier, open \"128.95.114.54/Data/Aria/dstrickland/Sort Reports\" in a seperate file window where you can click around and open files"
        end
        
        jobs.each do |j|
          op_type = j.operations.first.operation_type.name 
          if op_type == 'Sort Yeast Display Library'
              data_associations.concat(lazy_associate_sorting_uploads(j, "sort_report", get_sorting_uploads(j)))
          end
        end
    end
    DataAssociation.import data_associations, on_duplicate_key_update: [:object] unless data_associations.empty?
  end
  
  def get_fcs_uploads(j)
    id = j.id
    date = j.updated_at.strftime('%d%m%Y')
    resp = show do
      title "Locate FCS Files"
      note "On the Samba drive:"
      bullet "Navigate to the shared folder: 128.95.114.54/Data/Aria/dstrickland"
      bullet "Within that folder, navigate to the sub folder with name #{date}"
      bullet "Within that folder, ensure that the only folder inside has the filename: Job_#{id}, open up this innermost folder"
      check "Now upload all FCS measurement files related to job #{id}"
      upload var: "fcs_uploads"
    end
    
    resp.get_response(:fcs_uploads)
  end
  
  def get_sorting_uploads(j)
    id = j.id
    date = j.updated_at
    resp = show do
      title "Locate Sorting xml files"
      note "On the Samba drive, through a seperate file explorer window:"
      bullet "Navigate to the shared folder: 128.95.114.54/Data/Aria/dstrickland/Sort Reports"
      bullet "within that folder, navigate to the sub folder with the date accessed: #{date}"
      bullet "within that folder, open any of the .xml files, ensure that somewhere on one of the first few lines of the file it says: \"Job_#{id}\""
      check "Now open that same folder address with the upload selector and upload all XML files related to job #{id}"
      upload var: "sorting_uploads"
    end
    
    resp.get_response(:sorting_uploads)
  end
  
  def lazy_associate_fcs_uploads(j, key_prefix, data_uploads)
    das = []
    if data_uploads
      j.operations.each do |op|
        data_uploads.each_with_index do |up|
          tube_id = op.output("Labeled Yeast Library").item.get("software_tube_id")
          if (up.name.include? tube_id)
            (op.inputs).each do |fv|
              das << lazy_associate2(fv.item, key_prefix, {}, up) if fv.item
            end
            das << lazy_associate2(op, key_prefix, {}, up)
          end
        end
      end
    end
    das
  end
  
  def lazy_associate_sorting_uploads(j, key_prefix, data_uploads)
    das = []
    if data_uploads
      j.operations.each do |op|
        data_uploads.each_with_index do |up|
          tube_id = op.output("Labeled Yeast Library").item.get("software_tube_id")
          if (up.name.include? tube_id) || (open(up.url).read.include? tube_id)
            das << lazy_associate2(op, key_prefix, {}, up)
          end
        end
      end
    end
    das
  end
  
  def jobs_from_plan(plan)
    plan.operations.map { |op| op.jobs.last }.uniq
  end
  
  def lazy_associate2(op, key, value, upload = nil)
   da = DataAssociation.new(
    parent_id: op.id,
    parent_class: op.class.to_s,
    key: key.to_s,
    object: { key => value }.to_json,
    upload_id: upload ? upload.id : nil
  )
  end
end
