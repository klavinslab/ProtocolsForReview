# Eriberto Lopez Nov 2017
# eribertolopez3@gmail.com 

# Loads necessary libraries from mammlian cell protocols
needs "Tissue Culture Libs/CollectionDisplay"
# Used for printing out objects for debugging purposes
needs "Standard Libs/Debug" 
# Used for Flow cytometry protocol
# needs "Induction - High Throughput/FlowHelper"
needs "Induction - High Throughput/HighThroughputHelper"
needs "Flow Cytometry/FlowHelper"

# Uses module to upload data and associate the files to the job and item
# needs "YeastGates/Upload_FC_Data"

class Protocol
    
#---------------Constants-&-Libraries----------------#
  require 'date'  
  include CollectionDisplay
  include Debug
  include FlowHelper
  include HighThroughputHelper
  
  INPUT = "96 Well Flat Bottom Plate"
  CYTOMETER_TYPE ="BD Accuri"
  SAMPLE_TYPE="Yeast"
  PRE_SAMPLE="SAMPLE_"
  BEAD_STOCK="calibration beads"
  WELL_VOL = 300 #(ul)

#----------------------------------------------------#

  def main

    operations.retrieve.make
    
    # Information about what the protocol will do
    intro(CYTOMETER_TYPE)
    
    # Standard cleaning cycle for the BD Accuri flow cytometer
    cleaning_cycle()
    
    # Directs tech to run bead calib, setup flow for measurements, uploads data, and associates
    flow_measurements(INPUT)
    
    # For after the data associations have been made
    # deletes input collection but retains output collection data and stuffs - virtually
    operations.each do |op|
      op.input(INPUT).collection.mark_as_deleted
    end
    
    cleaning = show do 
        title "Finishing Up..."
        
        # note "Get 24 Well clean and ready to be autoclaved."
        note "Run clean cycle one more time."
        note "Need instructions? (Yes or No)"
        # get "text", var: "cleaning", label: "Finishing...", default: "Yes" 
        select ["Yes", "No"], var: "cleaning", label: "Finishing...", default: 0
    end
    
    log_info "CLEANING", cleaning, cleaning[:cleaning]
    if cleaning[:cleaning] == "Yes"
        cleaning_cycle(cleaning)
    end
    
    operations.store
    return {}
    
  end # main
  
  def flow_measurements(input)
      
      in_colls = operations.map { |op| op.input(input).collection}.uniq
      # Used in exportFCS to associate files to the plan and item the op is from
      op = operations.map {|op| op}.first 
      expUploadNum = operations.length
      
      in_colls.each do |in_coll|
          
          # run calibration beads - a new aquqrium sample bead_sample is created
          bead_item = beadCalibration(CYTOMETER_TYPE, op.input(BEAD_STOCK), op) 
          
          # Instructs on how to apply settings in workspace for fluorescence measurements
          measuring_fluorescence(in_coll)
          
          input_item = Item.find(in_coll.id)

        #   log_info CYTOMETER_TYPE, input_item, op, PRE_SAMPLE, expUploadNum
          # Used to export, upload, & associate - from FlowHelper_v2 - exportFCS(cytstr, input(item), op, prefix="", expUploadNum=1)
          uploads_key = exportFCS(CYTOMETER_TYPE, input_item, op, PRE_SAMPLE, expUploadNum)
          
          # add hash associtions - from HighThroughputHelper
          associatePlateFSCuploads(in_coll, uploads_key)
      end
  end

  # Sets up workspace to measure fluorescence on flow cytometer
  def measuring_fluorescence(in_coll)
    
    rows = ['A','B','C','D','E','F','G','H']
    d = DateTime.now
    
    show do
      title "Setting Up Workspace for Flow Cytometry Measurements"
  
      note "In the <b>'Auto Collect'</b> tab, select the Plate Type: <b>'96 well: flat bottom'</b>."
      note "Click and check the following wells."
      table highlight_non_empty(in_coll) { |r, c| rows[r] + (c + 1).to_s}
    end
    
    show do
      title "Setting Up Workspace for Flow Cytometry Measurements"
      
      note "Set <b>'Run Limits'</b> to <b>30,000 events</b>."
      note "Set <b>'Fluidics'</b> to <b>'Med'</b>" # Fast - Flow rate: 66ul/min, Core Sze : 22um
      note "Set  <b>'Set threshold'</b> to <b>FSC-H less than 400,000</b>."
      note "Click <b>'Apply Settings'</b>"
      check "Save as <b>Item_#{in_coll}_#{d.strftime("%m_%d_%Y")}</b> in <b>Q0_YeastGates</b> folder." 
    end
    
    show do
        title "Flow Cytometry Measurements"
        
        check "Obtain Item #{in_coll}"
        note "Finally, click <b>Eject Plate</b>"
        warning "Load experimental plate with the <b>first well at the top left next to the red-dot sticker</b>."
        note "Click <b>Load Plate</b>."
        note "Click <b>OPEN RUN DISPLAY</b>."
        note "Click <b>AUTORUN</b> to begin measurements."
    end
  end


  def intro(flow_type)
     show do
        title "Taking Flow Cytometery Measurements"
        
        note "This protocol will guide you to setup the workspace to take measurements on the #{flow_type} Flow Cytometer."
     end
  end
  
  def cleaning_cycle(cleaning="")
    show do
        
      if cleaning == "Yes"
        title "Cleaning Flow Cytometer"
      else
        title "Prepare the Flow Cytometer for Measurements"
      end
      
      note "Prepare the BD Accuri C6 Flow Cytometer by cleaning it with the  CleanRegular template."
      note "Go to <b>File</b> => Select <b>Open workspace or template</b>"
      note "Do not save changes to workspace."
      note "Under <b>Documents</b> find and open the <b>CleanRegular</b> template"
      warning "Check to see if the three eppendorf tubes in the 24 tube rack have fluid to run the cleaning cycle."
      # TODO - If cleaning fluids are out or if the instrument waste needs to be removed - create function
      note "Select the <b>'Manual Collect'</b> tab towards the top of the window."
      check "If there are any events saved in wells <b>D4, D5, D6</b> from the last run, select the well and click <b>Delete Events</b> towards the bottom of the window."
    end
    
    show do
      title "Apply Cleaning Settings to Flow Cytometer Workspace"
      
      note "Next, select the <b>Auto Collect</b> tab towards the top of the window."
      note "Click and check wells that will be used in the cleaning cycle <b>D4, D5, D6</b>."
      note "Set <b>Run Limits</b> to <b>2 Min</b>."
      note "Set <b>Fluidics</b> to <b>Slow</b>."
      note "Set <b>Set Threshold</b> to <b>FSC-H less than 80,000</b>."
      note "Click <b>Apply Settings</b>."
      note "Click <b>OPEN RUN DISPLAY</b>."
      note "Click <b>AUTORUN</b> to begin clean cycle :D"
      if cleaning == ""
        warning "While clean cycle is running begin to prepare samples for measurements!"
      end
    end
  end
  
end # class