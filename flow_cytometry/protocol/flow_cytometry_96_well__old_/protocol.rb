# Eriberto Lopez
# modified by SG
needs "Standard Libs/Debug" 
needs "Flow Cytometry/FlowHelper"                        
needs "Induction - High Throughput/HighThroughputHelper" # for data association to collection

class Protocol

  include Debug
  include FlowHelper
  include HighThroughputHelper 
  
  INPUT_NAME="96 well plate"
  WELL_VOL="well volume (µL)" # not really used
  BEAD_STOCK="calibration beads"
  
  CYTOMETER_TYPE="BD Accuri" # must match one of allowed CYTOMETER_NAMES in Flow Cytometry/FlowHelper 
  SAMPLE_TYPE="sample type" # list on Protocol Def page must match the allowed SAMPLE_TYPES in Flow Cytometry/FlowHelper 

  def main
      
    # make is not needed, we have no new items   
    # operations.retrieve # should be in loop!!!

    operations.each { |op|
        
        # message to user: run this operation on the browser on the flow cytometer 
        show do
            title "Flow cytometery - info"
            warning "The following should be run on a browser window on the #{CYTOMETER_TYPE} computer!"
        end 
        
        # Standard cleaning cycle for the flow cytometer
        cleanCytometer(CYTOMETER_TYPE)
        
        # run calibration beads - a new aquqrium sample bead_sample is created
        bead_item = beadCalibration(CYTOMETER_TYPE, op.input(BEAD_STOCK), op) 
        
        # op.input(SAMPLE_TYPE).val seems to pick one of the parameters (E coli or Yeast) at random
        
        log_info CYTOMETER_TYPE, op.input(SAMPLE_TYPE).val, op.input(WELL_VOL).val, op.input(INPUT_NAME).collection, op
        # My Params - EL 01272018
        # log_info CYTOMETER_TYPE, "Yeast", 300, op.input("96 well plate").collection, op
        
        take([op.input(INPUT_NAME).item], interactive: true)
        
        # run plate - uses collection to determine number of samples and their positions
        uploads_key=runSample96(CYTOMETER_TYPE, op.input(SAMPLE_TYPE).val, op.input(WELL_VOL).val, op.input(INPUT_NAME).collection, op)
        # uploads_key=runSample96(CYTOMETER_TYPE, "Yeast", 300, op.input("96 well plate").collection, op)
        
        # add hash associations - will create new hash if none exists
        associatePlateFSCuploads(op.input(INPUT_NAME).collection, uploads_key)
        
        # run final clean
        cleanCytometer(CYTOMETER_TYPE)
        log_info 'end of main'
    } # operations.each
    
    # Add cleaning up of input plates
    input_collections = operations.map {|op| op.input(INPUT_NAME).item.id}
    show do 
        title "Cleaning Up After Experiment"
        separator
        note "Please clean up the following 96 Well plates by rinsing out with DI water and 70% EtOH"
        check "Clean up <b>#{input_collections}</b>"
    end
    
    # dispose plates
    operations.each {|op| op.input(INPUT_NAME).item.mark_as_deleted}
    return {}
    
  end # main
  
end # class