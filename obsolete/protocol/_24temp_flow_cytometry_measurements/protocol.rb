# Eriberto Lopez
# eribertolopez3@gmail.com Sept 2017

# Loads necessary libraries from mammlian cell protocols
category = "Tissue Culture Libs"
needs "#{category}/CollectionDisplay"
needs "Standard Libs/Debug" # Used for printing out objects for debugging purposes

class Protocol
    
#---------------Constants-&-Libraries----------------#
  require 'date' 
  include CollectionDisplay
  include Debug
  INPUT = "96_deep_well"
  OUTPUT = "Data"
  CONTAINER = "96-well TC Dish"
   
#----------------------------------------------------#

  def main

    operations.retrieve.make
    
    tin  = operations.io_table "input"
    tout = operations.io_table "output"
    
    show do 
      title "Input Table"
      table tin.all.render
    end
    # key = :plan_measurements
    # files = Plan.find(6759).get(key)
    # log_info 'files', files # plan_6759
    
    # # pass upload into function
    # upload = Plan.find(6759).upload(key)
    # log_info 'uploads', upload # 17477 item_111552_16hr_12032017.csv
    # # log_info upload.name
    # def upload_plate_reader_ODs(upload)
    #     # iterate through upload name to determine what timepoint it is
    #     name = upload.name
    #     # log_info 'name', name
    #     # log_info 'timepoint', name.split('_')[2]
    #     item_id = name.split('_')[1]
    #     timepoint = name.split('_')[2]
    #     # create new key based on timepoint
    #     new_key = "1:10_#{timepoint}_ODs".to_sym
    #     # log_info new_key
    #     # associate new upload with new timepoint key
    #     plan = Plan.find(6759)
    #     log_info plan
    #     plan.associate new_key, "plan_#{plan.id}", upload
    # end
    
    


    # asso = Plan.find(6759).associations
    # log_info 'plan associations', asso
    
    # keys = asso.keys
    # log_info 'asso keys', keys
    
    # ups = keys.map {|key| Plan.find(6759).upload(key)}
    # log_info 'ups', ups
    
    # log_info asso[files]
    # if (!uploads.nil?)
    #     #
    # end
    # raise uploads.inspect
        
    # Information about what the protocol will do
    # intro()
    
    # # Standard cleaning cycle for the flow cytometer
    # cleaning_cycle()
    
    # # retrieve plate, resuspend, and transfer culture to a 96 well U-bottom plate
    # flow_measurements(INPUT, OUTPUT)
    
    # # For after the data associations have been made
    # # deletes input collection but retains output collection data and stuffs - virtually
    # operations.each do |op|
    #     op.input(INPUT).collection.mark_as_deleted
    # end


    # show do 
    #   title "Output Table"
    #   table tout.all.render
    # end
    
    # operations.store
    
    return {}
    
  end # main

    # def associate_to_plan(upload)
    #     plan = operations.map {|op| op.plan}.first
    #     key = :plan_measurements
    #     files = Plan.find(plan.id).get(key)
    #     if (!files.nil?)
    #         files["plan_#{plan.id}"] = upload
    #         plan.associate key, 
    #     plan.associate :plan_measurements, "plan_#{plan.id}", upload
    # end



  def intro()
     show do
        title "Taking Flow Cytometery Measurements"
        
        note "This protocol will guide you to setup the workspace to take measurements on the BD Accuri C6 Flow Cytometer."
     end
  end
  
  def cleaning_cycle()
      show do
        title "Prepare the Flow Cytometer for Measurements"
        
        note "Prepare the BD Accuri C6 Flow Cytometer by cleaning it with the  CleanRegular template."
        note "Go to <b>File</b> => Select <b>Open workspace or template</b>"
        note "Do not save changes to workspace"
        note "Under <b>Documents</b> find and open the <b>CleanRegular</b> template"
        warning "Check to see if the three eppendorf tubes in the 24 tube rack have fluid to run the cleaning cycle."
        # TODO - If cleaning fluids are out or if the instrument waste needs to be removed - create function
        note "Select the <b>'Manual Collect</b> tab towards the top of the window."
        check "If there are any events saved in wells <b>D4, D5, D6</b> from the last run, select the well and click <b>Delete Events</b> towards the bottom of the window."
      end
      
      show do
        title "Applying Settings to Flow Cytometer Workspace"
        
        note "Next, select the <b>Auto Collect</b> tab towards the top of the window."
        note "Click and check wells that will be used in the cleaning cycle <b>D4, D5, D6</b>."
        note "Set <b>Run Limits</b> to <b>2 Min</b>."
        note "Set <b>Fluidics</b> to <b>Slow</b>."
        note "Set <b>Set Threshold</b> to <b>FSC-H less than 80,000</b>."
        note "Click <b>Apply Settings</b>."
        note "Click <b>OPEN RUN DISPLAY</b>."
        note "Click <b>'AUTORUN</b> to begin clean cycle :D"
        warning "While clean cycle is running begin to prepare samples for measurements!"
      end
  end

  # Displays 96 well plate collection in order to guide technician on how to prepare samples and apply flow cytometery settings 
  def flow_measurements(input, output)
      
    # Creates a hash that groups all the running operations to the input_collection_id it corresponds to
    grouped_by_collection = operations.running.group_by { |op| op.input(input).collection.id }
    
    log_info grouped_by_collection
    
    # takes output container/collection and iterates through the incoming collections
    operations.output_collections[output].each do |outputPlate|
      
      # Removes the first object and takes the first index of that object - input_item_id
      inputPlateID = grouped_by_collection.shift.first
      
      # Transfering culture from input 96 well plate to clear 96 well U-bottom plate for measurements   
      transfer_cults(grouped_by_collection, outputPlate, inputPlateID)
        
      # Instruct on how to apply settings in workspace for fluorescence measurements
      measuring_fluorescence(outputPlate, inputPlateID)
      
      # Instruct on saving data and associating the data with collection
      exporting_FCS(outputPlate, input, output)
      
    end 
  end
  
  def exporting_FCS(outputPlate, input, output)
    show do
      title "Saving Data from Flow Cytometer"
      
      note "When flow cytometer is <b>DONE!</b>."
      check "Save data by selecting <b>File</b> => <b>Export ALL Samples as FCS...</b> write down and record the name of the file created."
      warning "This will create a file in the <b>FCS Exports</b> file."
    end
    
    uploads = show do
      title "Uploading .fcs files"
      
      note "Upload .fcs files from Flow cytometer measurements"
      note "Select and highlight all the files from the experimental Flow Cytometry run."
      upload var: "fcs" # Uploads and saves all files that are highlighted by tech will then be able to access when uploads is given the "fcs" key
    end
    
    log_info uploads[:fcs]
    
    # Tests to determine whether to use Dummy array or the acutal files being uploaded by tech
    if uploads[:fcs] == nil
        # Dummy test array
        uploads[:fcs] = ["A1","A2","A3","A4"]
    end
    
    # Casting collection to item
    output_item = Item.find(outputPlate.id) 
    
    # Creates an empty maxtrix with the dimensions of the collection
    results_matrix = Array.new(outputPlate.object_type.rows) { Array.new(outputPlate.object_type.columns) } 
    
    # associates temp :file with uploaded files 
    operations.each_with_index do |op, idx|
        op.temporary[:file] = uploads[:fcs][idx]
    end

    log_info output_item.associations # Takes a peak of objects associated with output_item
    
    # Fills results_matrix with upload file that was previously associated
    operations.each do |op|
        results_matrix[op.output(output).row][op.output(output).column] = op.temporary[:file]
    end
    
    # Associates output_item wthe the :files and the results_matrix - should save upload files as an association
    output_item.associate(:files, results_matrix)
    
    log_info output_item.associations
  end

  # Sets up workspace to measure fluorescence on flow cytometer
  def measuring_fluorescence(outputPlate, inputPlateID)
    rows = ['A','B','C','D','E','F','G','H']
    d = DateTime.now
    
    show do
      title "Setting up workspace for GFP measurements"
  
      note "In the <b>'Auto Collect'</b> tab, select the plate type <b>'96 well U-bottom'</b>."
      note "Click and check the following wells."
      table highlight_non_empty(outputPlate) { |r, c| rows[r] + (c + 1).to_s}
    end
    
    show do
      title "Setting up workspace for GFP measurements"
      
      note "Set <b>'Run Limits'</b> to <b>10,000 events</b>."
      note "Set <b>'Fluidics'</b> to <b>'Fast'</b>" # Flow rate: 66ul/min, Core Sze : 22um
      note "Set  <b>'Set threshold'</b> to <b>FSC-H less than 400,000</b>."
      check "Click <b>'Apply Settings'</b> and save as <b>#{inputPlateID}_#{d.strftime("%m_%d_%Y")}</b>"
      note "Finally, click <b>Eject Plate</b>"
      warning "Load experimental plate with the <b>first well at the top left next to the red-dot sticker</b>."
      note "Click <b>Load Plate</b>."
      note "Click <b>OPEN RUN DISPLAY</b>."
      note "Click <b>AUTORUN</b> to begin measurements."
    end
  end

  def transfer_cults(grouped_by_collection, outputPlate, inputPlateID)
    show do
      title "Transferring 96-deep well Item ##{inputPlateID} cultures" 
      
      check "Obtain a <b>96 Well Greiner Microplate, Clear, U-Bottom plate</b>"    
      note "Before transferring cultures, place Item ##{inputPlateID} on bench top vortexer at a setting of 6 and pulse carefully."
      note "Observe from underneath to check for resuspension of cultures."
      note "Next, using a multichannel pipette take the following volume from the wells shown below from Item ##{inputPlateID}."
      # CollectionDisplay library
      table highlight_non_empty(outputPlate) { |r,c| "280uL" } 
      note "Transfer volume to a clean, clear 96-well U-bottom plate."
    end 
  end
  
end # class