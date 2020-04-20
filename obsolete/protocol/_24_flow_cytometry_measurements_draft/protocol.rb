# Eriberto Lopez Sept 2017
# eribertolopez3@gmail.com 

# Loads necessary libraries from mammlian cell protocols
category = "Tissue Culture Libs"
needs "#{category}/CollectionDisplay"
needs "Standard Libs/Debug" # Used for printing out objects for debugging purposes

# Uses module to upload data and associate the files to the job and item
needs "Flow Cytometry - Yeast Gates/Upload_FC_Data"

class Protocol
    
#---------------Constants-&-Libraries----------------#
  require 'date'  
  include CollectionDisplay
  include Debug
  include Upload_FC_Data
  
  INPUT = "24 Deep Well Plate"
  OUTPUT = "Data"

#----------------------------------------------------#

  def main

    operations.retrieve.make
    
    # Information about what the protocol will do
    intro()
    
    # Standard cleaning cycle for the flow cytometer
    cleaning_cycle()
    
    # retrieve plate, resuspend, and transfer culture to a 96 well U-bottom plate
    flow_measurements(INPUT, OUTPUT)
    
    finishing_up()
    
    # For after the data associations have been made
    # deletes input collection but retains output collection data and stuffs - virtually
    operations.each do |op|
      op.input(INPUT).collection.mark_as_deleted
    end
    
    cleaning = show do 
        title "Finishing Up"
        
        note "Get 24 Well ready clean and ready to be autoclaved."
        note "Run clean cycle one more time."
        note "Need instructions? (Yes or No)"
        get "text", var: "cleaning", label: "Finishing...", default: "Yes"
    end
    
    # log_info "CLEANING", cleaning, cleaning[:cleaning]
    
    cleaning = cleaning[:cleaning]
    if cleaning == "Yes"
        cleaning_cycle(cleaning)
    end
    operations.store
    
    return {}
    
  end # main
  
  # TODO - Add functionality to loop through multiple outputPlates (96 wells)
  def flow_measurements(input, output)
      
      operations.output_collections[output].each do |outputPlate|
          log_info outputPlate
          # Creates a table that directs tech to reformat collection into a 96 Well format
          
          # Displays the transferring of cultures from 24W to 96W format
          transfer_to_96(input, output, outputPlate)
          
          # Instructs on how to apply settings in workspace for fluorescence measurements
          measuring_fluorescence(outputPlate)
          
          # From Upload_FC_Data Module - Gathers uploads and associates files to job and 96 file matrix
          upload_results(input, output, outputPlate)
      end
  end
  
  
  def transfer_to_96(input, output, outputPlate)
        
      rows = ["A","B","C","D","E","F","G","H"]
      
      # Creates arrays of the input collections collections from all the operations
      inputCollections = operations.map { |op| op.input(input).collection }.uniq 
      
      # Creates a hash that groups all the running operations to the input_collection_id it corresponds to
      grouped_by_inputCollectionID = operations.running.group_by { |op| op.input(input).collection.id }
      

      
      grouped_by_inputCollectionID.each do |inputCollectionID, ops|
          # outputCollection = ops.first.output(output).collection
          1.times do
              show do
                  title "Using Expandable Pipette"
                  
                  check "Grab a clean Black Costar 96 Well Clear Flat Bottom Plate and label with Item #<b>#{outputPlate.id}</b>"
                  note "Next, using a multichannel pipette take the following volume from the wells shown below."
                  check "Set an expandable 6 channel P1000 pipette to <b>300ul</b>."
                  note "Set the light grey wheel setting to <b>18</b>."
                  note "Using the dark grey wheel expand pipettes until you feel resistance and pipette desired volume."
                  note "To transfer, turn the dark grey wheel to contract the pipette tips and dispense volume."
              end
          end
          
          show do 
              title "Reformatting Cultures to 96 Well Format"
              
              note "Follow table to reformat cultures for the Flow Cytometer:"
              table ops.start_table
              .custom_column(heading: "Well from Item ##{inputCollectionID}") { |op| rows[op.input(input).row] + (op.input(input).column + 1).to_s }
              .custom_column(heading: "Transfer 300ul to") { |op| "===>"}
              .custom_column(heading: "Well in Item ##{outputPlate.id}") { |op| rows[op.output(output).row] + (op.output(output).column + 1).to_s }
              .end_table
          end
      end
  end


  def transfer_cults(grouped_by_collection, outputPlate, inputPlateID)
    inputPlateID = grouped_by_collection.shift.first
    
    show do
      title "Transferring 24 Deep Well Item ##{inputPlateID} Cultures" 
      
      check "Obtain a <b>Costar 96 Well Black, Flat Bottom plate</b>"    
      note "Observe from underneath to check for resuspension of cultures."
      note "Next, using a multichannel pipette take the following volume from the wells shown below from Item ##{inputPlateID}."
      check "Set an expandable 6 channel pipette to <b>300ul</b>."
      note "Set the light grey wheel setting to <b>18</b>."
      note "Using the dark grey wheel expand pipettes until you feel resistance and pipette desired volume."
      note "To transfer, turn the dark grey wheel to contract the pipette tips and dispense volume."
      # CollectionDisplay library
    #   table highlight_non_empty(outputPlate) { |r,c| "300 uL" } 
      note "Transfer volume to a clean, clear 24-well U-bottom plate."
    end 
  end

  # Sets up workspace to measure fluorescence on flow cytometer
  def measuring_fluorescence(outputPlate)
    
    rows = ['A','B','C','D','E','F','G','H']
    d = DateTime.now
    
    show do
      title "Setting Up Workspace for GFP Measurements"
      
      note "Click <b>Close Run Display</b> to continue."
      note "In the <b>'Auto Collect'</b> tab, select the Plate Type: <b>'96 well: flat bottom'</b>."
      note "Click and check the following wells."
      table highlight_non_empty(outputPlate) { |r, c| rows[r] + (c + 1).to_s}
    end
    
    show do
      title "Setting Up Workspace for GFP Measurements"
      
      note "Set <b>'Run Limits'</b> to <b>10,000 events</b>."
      note "Set <b>'Fluidics'</b> to <b>'Med'</b>" # Fast - Flow rate: 66ul/min, Core Sze : 22um
      note "Set  <b>'Set threshold'</b> to <b>FSC-H less than 400,000</b>."
      note "Click <b>'Apply Settings'</b>"
      check "Save as <b>Item_#{outputPlate}_#{d.strftime("%m_%d_%Y")}</b> in <b>Q0_YeastGates</b> folder." # do I need to associate
      note "Finally, click <b>Eject Plate</b>"
      warning "Load experimental plate with the <b>first well at the top left next to the red-dot sticker</b>."
      note "Click <b>Load Plate</b>."
      note "Click <b>OPEN RUN DISPLAY</b>."
      note "Click <b>AUTORUN</b> to begin measurements."
    end
  end


  def intro()
     show do
        title "Taking Flow Cytometery Measurements"
        
        note "This protocol will guide you to setup the workspace to take measurements on the BD Accuri C6 Flow Cytometer."
     end
  end
  
  def cleaning_cycle(cleaning=nil)
    show do
        
      if cleaning == "Yes"
        title "Cleaning Flow Cytometer"
      else
        title "Prepare the Flow Cytometer for Measurements"
      end
      
      note "Prepare the BD Accuri C6 Flow Cytometer by cleaning it with the  CleanRegular template."
      note "If necessary click <b>Close Run Display</b> to continue."
      note "Go to <b>File</b> => Select <b>Open workspace or template</b>"
      note "Do not save changes to workspace."
      note "Under <b>Documents</b> find and open the <b>CleanRegular</b> template"
      warning "Check to see if the three eppendorf tubes in the 24 tube rack have fluid to run the cleaning cycle by clicking <b>Eject Plate</b>."
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
      if cleaning == nil
        warning "While clean cycle is running begin to prepare samples for measurements!"
      end
    end
  end

  def finishing_up()
      plates_to_clean = operations.map {|op| op.input(INPUT).collection.id}.uniq
      
      show do 
          title "Finishing Up..."
         
          note "Before finishing up, prepare 24 Deep Well plate(s) for autoclaving."
          plates_to_clean.each {|plt| note "Clean item #{plt}"} 
          note "Place plate(s) at cleaning station and soak with bleach solution."
      end
  end

end # class