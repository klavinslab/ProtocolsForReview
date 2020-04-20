# By: Eriberto Lopez 11/05/2017
# eribertolopez3@gmail.com

# Loads necessary libraries
category = "Flow Cytometry - Yeast Gates"
needs "#{category}/Multiwell_Module"
needs "#{category}/Upload_Data"
needs "Tissue Culture Libs/CollectionDisplay"
needs "Standard Libs/Debug" # Used for printing out objects for debugging purposes

class Protocol

#---------------Constants-&-Libraries----------------#
  require 'date'
  include Multiwell_Module
  include Upload_Data
  include CollectionDisplay
  include Debug

  INPUT = "24 Deep Well Plate"
  OUTPUT = "96 Well Flat Bottom Plate"
#   PARAMETER_WAVELENTH = "Wavelength (nm)"
  PARAMETER_TIMEPOINT = "Timepoint (hr)"
  SAVING_DIRECTORY = "_UWBIOFAB"
  TRANSFER_VOL = 30
  OPERATION_TYPE = "OD_Measurements"
#----------------------------------------------------#

  def main
    # Locate and obtain 24W plate(s)
    # operations.retrieve.make
    operations.make
    
    wavelength = 600 #operations.map {|op| op.input(PARAMETER_WAVELENTH).val.to_i}.first
    timepoint = operations.map {|op| op.input(PARAMETER_TIMEPOINT).val.to_i}.first
    
    intro(wavelength)
    
    # Group operations by collections - coll: ops
    grp_by_in_coll = operations.group_by {|op| op.input(INPUT).collection}
    grp_by_out_coll = operations.group_by {|op| op.output(OUTPUT).collection}

    in_colls = grp_by_in_coll.map {|coll, ops| coll}
    out_colls = grp_by_out_coll.map {|coll, ops| coll}
    
    in_rows = grp_by_in_coll.first[0].object_type.rows
    in_cols = grp_by_in_coll.first[0].object_type.columns
    out_rows = grp_by_out_coll.first[0].object_type.rows
    out_cols = grp_by_out_coll.first[0].object_type.columns
    
    in_dims = in_rows * in_cols
    out_dims = out_rows * out_cols

    # Will reformat multiple input to output collections, measure, and upload 
    while (!grp_by_out_coll.empty?)
    
        # Display grid showing which wells to fill with 270ul of media and give how much media to place in resivoir
        # Guides tech to reformat cultures to 96 wells by displaying a table - multiwell module lib
        grp_by_in_coll, grp_by_out_coll, out_coll = reformat_collection_table(grp_by_in_coll, grp_by_out_coll, in_dims, out_dims)
        
        # Output collection being filled
        # out_coll_filled = out_colls.shift
        
        # Input collections used to fill output collection
        used_to_fill = in_colls.shift(out_dims/in_dims)
        # used_to_fill.map {|in_coll| Item.find(in_coll.id).store} ### How do I store plate back in incubator and continue with the measurement
        
        # Describes how to set up plate reader to measure ODs
        od_filename = measure_OD(out_coll, wavelength, timepoint)
        
        # Show block upload button and retrieval of file uploaded
        up_show, up_sym = upload_show(od_filename)
        
        # Associates upload to item, plan, and input collections as a hash
        if (up_show[up_sym].nil?)
            show {note "No upload found for Time Point #{timepoint}hrs"}
        else
            upload = find_upload_from_show(up_show, up_sym)
            associate_OD_to_item(out_coll, upload) # 12/05/2017 - Upload_Data
            associate_OD_to_plan(upload) # 12/05/2017 - Upload_Data
            up_name = upload.name
            up_ext = up_name.split('.')[1]
            
            # If file is a csv then it will turn plate reader raw data to a 2D-matrix & associate parts to input collections as a hash
            if up_ext == 'csv'
                matrix = read_url(upload)
                hash = matrix_to_OD_hash(matrix) # Upload_Data Lib
                # show {note "matrix #{matrix}"}
                # take matrix and turn to hash
                # show {"hash #{hash}"}
                
                k = 'optical_density' # known beforehand, created in matrix_to_OD_hash(matrix)
                # take hash and slice up to associate to input collections
                slices = hash[k].flatten.each_slice(in_cols).map {|slice| slice}
                used_to_fill.each do |in_coll|
                    if timepoint > 0
                        od_hshs = Item.find(in_coll.id).get(k) # grabs hashes associated with item 'optical_density' - {'0_hr'=>[[final_od_mat]]}
                        if(!od_hshs.nil?)
                            od_hshs["#{timepoint}_hr"] = slices.shift(in_rows) # {'0_hr'=>[[final_od_mat]], "#{timepoint}_hr"=>[[slices.shift(in_rows)]]}
                            Item.find(in_coll.id).associate(k, od_hshs) # 'optical_density'=>{'0_hr'=>[[final_od_mat]], "#{timepoint}_hr"=>[[slices.shift(in_rows)]]}
                        else
                            od_hsh = Hash.new(0)
                            od_hsh["#{timepoint}_hr"] = slices.shift(in_rows)
                            Item.find(in_coll.id).associate(k, od_hsh)
                        end
                    else
                        od_hsh = Hash.new(0)
                        od_hsh["#{timepoint}_hr"] = slices.shift(in_rows)
                        Item.find(in_coll.id).associate(k, od_hsh)
                    end
                end
            end
        end
    end
    
    operations.store
    
    return {}
    
  end # Main
  
# outdated association
#   used_to_fill.each do |in_coll|
#         hsh = Hash.new(0)
#         hsh["#{wavelength}nm"] = slices.shift(in_rows)
#         Item.find(in_coll.id).associate(k, hsh)
#         # show {note "item associations #{Item.find(in_coll.id).associations}"}
#     end
  
    # Give an introduction to the measure OD protocol
    #
    # @param wavelength [integer] the type of light measured, 0 to 900
    def intro(wavelength)
        show do
            title "Optical Density Measurements"
            
            note "This protocol will instruct you on how to take ODs on the BioTek Plate Reader."
            note "ODs are a quick and easy way to measure the growth rate of your culture."
            note "First you will dilute & reformat your cultures to a 96 well format, then measure the OD at #{wavelength}nm."
        end
    end
    
    # Instructs tech on how to setup plate reader (BioTek) and take OD measurements
    #
    # @params collection [collection] the collection that will be placed on the plate reader, collection object 96 well
    # @return od_filename [string] the name of the od file that will be exported then uploaded later, is a string with collection id
    def measure_OD(collection, wavelength, timepoint)
        d = DateTime.now
        
        experiment_filename = "experiment_#{collection}_#{d.strftime("%m%d%Y")}"
        
        # Set up plate reader workspace and taking measurements
        show do
            title "Setting Up Plate Reader Workspace"
            
            note "Take reformatted 96 well plate to the plate reader computer, under cabinet <b>A10.530</b>."
            note "Click BioTek Gen5 Icon"
            note "Under Create a New Item click <b>'Experiment'</b> "
            if wavelength == 600
                note "From the list select <b>'Single_OD600.prt'</b>"
            end
            note "Next, click Read Plate icon and click <b>'READ'</b>"
            note "Name experiment file: <b>#{experiment_filename}</b>"
            note "Finally, save it under the <b>#{SAVING_DIRECTORY}</b> folder."
            note "Load plate and click <b>'OK'</b>"
        end
        
        #TODO:How to handle multiple 24DW plates
        # want to name OD_CSV file with the name of the incoming collection 24DW instead of the 96W being measured
        ##############
        # in_coll = operations.map {|op| op.input(INPUT).collection}.uniq
        
        # log_info "in_coll", in_coll
        od_filename = "item_#{collection}_#{timepoint}hr_#{d.strftime("%m%d%Y")}"
        
        # Exporting single file (csv)
        show do
            title "Exporting ODs from Plater Reader"
            
            note "After measurements have been taken, select the <b>'Matrix'</b> tab - SHOW ICON"
            note "Next, click the Excel sheet export button. The sheet will appear on the menu bar below - SHOW ICON"
            note "Go to sheet and 'Save as' <b>#{od_filename}</b> under the <b>#{SAVING_DIRECTORY}</b> folder."
            warning "Make sure to 'Save as' a CSV formatted file!"
        end
        return od_filename
    end
end # Class
