# A quick cytometry measurement from a plate
# 2018-07-10
# Author: Justin Vrana

needs "Tissue Culture Libs/CollectionDisplay"

# used for debugging
needs "Standard Libs/Debug"

# used for exporting and uploading data
needs "Flow Cytometry/FlowHelper (old)"

# needs "Standard Libs/AssociationManagement"

class Protocol
  require 'date'
  include CollectionDisplay
  include Debug
  include ActionView::Helpers::NumberHelper
  include FlowHelper
#   include AssociationManagement

  INPUT = "Yeast Plate"
  OUTPUT = "Cytometry Plate"

  CYTOMETER_TYPE = "BD Accuri"
  PRE_SAMPLE = "SAMPLE_"

  def main

    now = DateTime.now

    operations.retrieve.make

    pick_colonies()

    colgroup = operations.group_by {|op| op.output(OUTPUT).collection}

    colgroup.each do |collection, ops|
      setup_flow_cytometer("24 deep well", collection)
      item = Item.find(collection.id)
      uploads_key = exportFCS(CYTOMETER_TYPE, item, ops.first, PRE_SAMPLE, operations.length)
      item.mark_as_deleted
    end

    cleaning_cycle(true)

    # setup flow cytometer

    # run flow cytometer

    # save data

    # run clean cycle

    show do
      title "Toss tubes #{operations.map {|op| op.temporary[:label]}}"
    end

    # operations.each do |op|
    #     op.input(INPUT).item.move("DFO") 
    # end
    operations.store

    return {}

  end


  def pick_colonies()
    operations.each.with_index do |op, i|
      op.temporary[:label] = i + 1
    end

    # get and label tubes
    show do
      title "Get and label tubes"

      check "Get <b>#{operations.length}</b> 1.5mL tube(s)"
      check "Add 200uL of 1X PBS to each tube"
      check "Label each tube according to the following:"
      table operations.start_table
                .custom_column(heading: "Tube Label") {|op| op.temporary[:label]}
                .end_table
    end

    # pick small amount of colony
    show do
      title "Resuspend yeast colonies in tubes"

      check "Using a 200uL pipette tip, pick a very small amount of yeast colony from the divided plate and inoculate it into the corresponding tube"
      warning "Be sure to leave some yeast colony on plate"

      table operations.start_table
                .custom_column(heading: "Item ID.section") {|op| "#{op.input(INPUT).item.id}.#{op.input(INPUT).column + 1}"}
                .custom_column(heading: "Output tube") {|op| op.temporary[:label]}
                .end_table
    end

    # vortex colony
    show do
      title "Vortex tubes to resuspend yeast cells"

      check "Vortex all #{operations.length} tube(s) at max speed"
    end
  end

  def collection_matrix_ops(collection, ops)
    matrix = nil
    ops.each do |op|
      output = op.output(OUTPUT)
      matrix ||= output.collection.matrix
      matrix[output.row][output.column] = op
    end
    matrix
  end

  def cleaning_cycle(cleaning = nil)
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
      if cleaning == nil
        warning "While clean cycle is running begin to prepare samples for measurements!"
      end
    end
  end

  def setup_flow_cytometer(plate_type, collection, outdir = "BIOFAB", limit_events = 30000, threshold = 400000, flow_rate = "Med")
    rows = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H']
    d = DateTime.now

    show do
      title "Setting up Workspace for Flow Cytometry Measurements"

      note "In the <b>'Auto Collect'</b> tab, select the Plate Type: <b>'#{plate_type}'</b>."
      note "Click and check the following wells."
      table highlight_non_empty(collection) {|r, c| rows[r] + (c + 1).to_s}
      # Proc.new()
      # table display_collection_matrix(operations.first.output_collection(OUTPTU))
      # tables = highligh_collection(operations, Proc.new { |op| op.temporary['label']}) { |op| op.output(OUTPUT) }
    end

    show do
      title "Setting up Workspace for Flow Cytometry Measurements"

      note "Set <b>'Run Limits'</b> to <b>#{number_with_delimiter(limit_events)} events</b>."
      note "Set <b>'Fluidics'</b> to <b>'#{flow_rate}'</b>" # Fast - Flow rate: 66ul/min, Core Sze : 22um
      note "Set  <b>'Set threshold'</b> to <b>FSC-H less than #{number_with_delimiter(threshold)}</b>."
      note "Click <b>'Apply Settings'</b>"
      check "Save as <b>Item_#{collection.id}_#{d.strftime("%m_%d_%Y")}</b> in <b>#{outdir}</b> folder."
    end

    matrix = collection_matrix_ops(collection, operations)

    show do
      title "Flow Cytometry Measurements"

      check "Obtain tubes #{operations.map {|op| op.temporary[:label]}}"
      note "Finally, click <b>Eject Plate</b>"
      note "Load rack with tubes according to the following:"
      table highlight_non_empty(collection) {|r, c| matrix[r][c].temporary[:label]}
      # warning "Load experimental plate with the <b>first well at the top left next to the red-dot sticker</b>."
      note "Click <b>Load Plate</b>."
      note "Click <b>OPEN RUN DISPLAY</b>."
      note "Click <b>AUTORUN</b> to begin measurements."
    end
  end

end