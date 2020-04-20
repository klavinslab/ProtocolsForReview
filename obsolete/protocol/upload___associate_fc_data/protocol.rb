
needs 'Standard Libs/AssociationManagement'
needs 'Standard Libs/MatrixTools'
needs 'Standard Libs/Debug'

class Protocol
  include AssociationManagement
  include MatrixTools
  include Debug
  
  # DEF
  INPUT = "Culture Plate"
  DIRECTORY = "Name of Data Directory"

  KEY_SAMPLE = 'SAMPLE_UPLOAD'.freeze

  def intro
    show do
      title "Upload & Associate Flow Cytometry Data"
      separator
      note "The following operation will guide you through uploading and associating previously acquired flow cytometry data."
      note "<b>1.</b> Determine where your data is on the local machine."
      note "<b>2.</b> Upload all files via Aq."
    end
  end
  
  def main
    intro
    return_hash = {} # collection_id : [[upload_id matrix]]
    operations.each do |op|
      directory_name = '/' + op.input(DIRECTORY).val.to_s
      in_collection = op.input(INPUT).collection
      num_cultures = in_collection.get_non_empty.length
      upload_list = gather_uploads(expected_num_uploads: num_cultures, dirname: directory_name)
      associate_uploads(KEY_SAMPLE, op, upload_list) # associate each upload individually to operation
      well_uploads = associate_uploads_to_plate(KEY_SAMPLE.pluralize, in_collection, upload_list) if !debug # associate a matrix of uploads to the plate
      return_hash[in_collection.id] = well_uploads
    end
    return_hash
  end # Main
  
  # Upload and check that have expected number of files
  # Give user 3 attempts to get all files. Return an Array of upload objects.
  # @param [Integer] expected_num_uploads  the number of expected files
  # @param [String]  dirname  the name of the directory where the files reside
  # @return [Array<Upload>]  an array of uploads for the exported files, or nil if nothing was uploaded
  def gather_uploads(expected_num_uploads:, dirname:)
    num_uploads = -1
    attempt = 0
    while (attempt < 3) && (num_uploads != expected_num_uploads)
    #   log_info 'attempt', attempt, 'num_uploads', num_uploads, 'expected_num_uploads', expected_num_uploads
      attempt += 1
      if attempt > 1
        show { 
            warning 'Number of uploaded files was incorrect, please try again!'
            note "You uploaded #{num_uploads} files, but the collection has #{expected_num_uploads} cultures."
        }
      end
      uploads_from_show = show do
        title "Select and highlight all .fcs files in directory <b>#{dirname}</b>"
        upload var: 'fcs_files'
      end
      if !uploads_from_show[:fcs_files].nil?
        num_uploads = uploads_from_show[:fcs_files].length
      end
      
    end
    upload_list = uploads_from_show_to_array(uploads_from_show, :fcs_files)
    return upload_list
  end
  
  # Converts the output of a show block that recieves uploads into a
  # list of uploads.
  #
  # @param [Hash] uploads_from_show  the hash return by a show block which accepts user input
  # @param [Symbol] upload_var  the symbol key which the target uploads are stored under in uploads_from_show
  # @return [Array<Upload>]  an array of uploads contained in the uploads_From_show at the given key
  def uploads_from_show_to_array(uploads_from_show, upload_var)
    return spoof_uploads if debug
    upload_list = []
    if uploads_from_show[upload_var].nil?
      return upload_list
    else
      uploads_from_show[upload_var].each_with_index do |upload_hash, ii|
        up = Upload.find(upload_hash[:id])
        upload_list.push(up)
      end
    end
    upload_list
  end

  # Ignore, this is for debugging only
  def spoof_uploads
    [Upload.find(1), Upload.find(2)]
  end

  # Associate all `uploads` to the `target` DataAssociator. The keys of each upload will be
  # the concatenation of `key_name` and that upload's id.
  # Associating fcs files to the plan and operation makes fcs data of any specific well
  # easily accessible to users
  #
  # @param [String] key_name  the name which describes this upload set
  # @param [Plan] plan  the plan that the uploads will be associated to
  # @param [Array<Upload>] uploads  An Array containing several Uploads
  # @effects  associates all the given uploads to `plan`, each with a
  #         unique key generated from the combining `keyname` and upload id
  def associate_uploads(key_name, target, uploads)
    if target
      associations = AssociationMap.new(target)
      uploads.each do |up|
        associations.put("U#{up.id}_#{key_name}", up)
      end
      associations.save
    end
  end

  def flow_cytometry_upload_matrix(collection:, upload_list:)
    # figure out size of collection (24 or 96)
    dims = collection.dimensions
    size = dims[0] * dims[1]
    well_uploads = WellMatrix.create_empty(size, -1)
    uploads.each do |up|
      # the first 3 letters of the upload filename will be the
      # alphanumeric well coordinate
      alpha_coord = up.name[0..2]
      well_uploads.set(alpha_coord, up.id)
    end
    return well_uploads
  end
  
  # Associate a matrix containing all `uploads` to `collection`.
  # The upload matrix will map exactly to the sample matrix of
  # `collection`, and it will be associated to `collection` as a value
  # of `key_name`
  #
  # @param [String] key_name  the key that the upload matrix will
  #           be associated under
  # @param [Collection] collection  what the upload matrix will be
  #           associated to
  # @param [Array<Upload>] uploads  An Array containing several Uploads
  # @effects  associates all the given uploads to `collection` as a 2D array inside a singleton hash
  def associate_uploads_to_plate(key_name, coll, uploads)
    well_uploads = flow_cytometry_upload_matrix(collection: coll, upload_list: uploads)
    coll_associations = AssociationMap.new(coll)
    # ensure we aren't overwriting an existing association
    unless coll_associations.get(key_name).nil?
      i = 0
      i += 1 until coll_associations.get("#{key_name}_#{i}").nil?
      key_name = "#{key_name}_#{i}"
    end
    coll_associations.put(key_name, {'upload_matrix' => well_uploads.to_a})
    coll_associations.save
    return well_uploads.to_a
  end

end # Class
