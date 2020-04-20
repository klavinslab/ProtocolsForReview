# Copied from rehydrate primer
# JV 2019-08-05
#   remove debug print step
#   does not make output items until calculations are finished
#   converts :ng data association to_f to handle strings as well
#   more clear titles
#   fixed a bug that displayed incorrect item table when preparing diluted fragment aliquot tubes
#   added precondition that blocks op from running if :ng is missing from item

class Protocol
  INPUT = "Lyophilized Fragment"
  STOCK = "Fragment Stock"
  DILUTED_STOCK = "Diluted Fragment"

  STOCK_CONCENTRATION = 20
  
  # This method tells the technician to pick up fragments from the EE office.
  def get_fragments
    show do
      title "Go the EE office to pick up fragments"

      note "Abort this protocol if no primer has shown up. It will automatically rescheduled."
    end
  end
  
  # This method tells the technician to quick spin down all fragment tubes.
  def quick_spin_fragment_tubes
    show do
      title "Quick spin down all the fragment tubes"

      check "Find the order with sales order (or supplier ref) number #{operations.first.input_data("Primer", :order_number)}"
      check "Put all the fragment tubes in a table top centrifuge to spin down for 3 seconds."

      warning "Make sure to balance!"
    end
  end
  
  # This method tells the technician to label and rehydrate fragments.
  def label_and_rehydrate
    show do
      title "Label and rehydrate"

      check "Label each fragment tube with the ids shown in the Fragment Stock  item ids column."
      check "Rehydrate each fragment with the volume of TE shown in the Rehydrate column."

      table operations.start_table
        .input_sample(INPUT)
        .custom_column(heading: 'Names of inputs') {|op| op.input("Lyophilized Fragment").sample.name}
        .output_item(STOCK)
        .custom_column(heading: "Rehydrate (uL of TE)", checkable: true) {|op| op.temporary[:water_vol]}
      .end_table
    end
  end
  
  # This method tells the technician to vortex and centrifuge fragments.
  def vortex_and_centrifuge
    show do
      title "Vortex and centrifuge"

      check "Wait one minute for the fragment to dissolve in TE." if operations.length < 7
      check "Vortex each tube on table top vortexer for 5 seconds and then quick spin for 2 seconds on table top centrifuge."
    end
  end
  
  # This method tells the technician to grab tubes and label them.
  def grab_tubes
    show do
      title "Grab #{operations.running.length} 1.5 mL tubes for diluted fragment aliquots"

      check "Grab #{operations.running.length} 1.5 mL tubes, label with following ids: #{operations.map {|op| "#{op.output(DILUTED_STOCK).item.id}"}.join(", ")}"
      check "Add water according to table."
      table operations.running.start_table
        .output_item(DILUTED_STOCK)
        .custom_column(heading: "H20 (uL)", checkable: true) {|op| op.temporary[:dilution_water_vol]}
      .end_table
    end
  end
  
  # This method tells the technician to make primer aliquots.
  def make_primer_aliquots
    show do
      title "Make fragment stock aliquots"

      check "Pipette #{operations.running.first.temporary[:dilution_vol] } uL #{STOCK} into each #{DILUTED_STOCK} tube using the following table."

      table operations.running.start_table
        .output_item(STOCK, heading: "#{STOCK} (#{operations.running.first.temporary[:dilution_vol]} uL)")
        .output_item(DILUTED_STOCK, checkable: true)
      .end_table
      
      check "Vortex each tube after the DNA has been added."
    end
  end  
  
  def main

    operations.retrieve interactive: false

    if debug
      operations.running.each do |op|
        op.set_input_data(INPUT, :ng, rand(250..1000))
      end
    end
    
    # Get fragment tubes from EE office
    get_fragments
    
    # Quick spin down all the fragment tubes
    quick_spin_fragment_tubes


    operations.running.each do |op|
      op.temporary[:conc] = STOCK_CONCENTRATION
      op.temporary[:water_vol] = op.input_data(INPUT, :ng).to_f / op.temporary[:conc]
      op.temporary[:dilution_vol] = 1.0
      op.temporary[:dilution_water_vol] = op.temporary[:dilution_vol] * op.temporary[:conc] - op.temporary[:dilution_vol]
    end
    
    operations.make
    
    # label and rehydrate fragments
    label_and_rehydrate

    # Vortex and centrifuge
    vortex_and_centrifuge

    # grab 1.5mL tubes
    grab_tubes
    
    # Make primer aliquots
    make_primer_aliquots


    operations.running.each do |op|
      stock = op.output(STOCK).item
      diluted_stock = op.output(DILUTED_STOCK).item
      stock.associate :concentration, op.temporary[:conc]
      stock.associate :volume, op.temporary[:water_vol] - op.temporary[:dilution_vol]
      diluted_stock.associate :concentration, 1.0
      diluted_stock.associate :volume, op.temporary[:dilution_water_vol]
    end

    operations.running.each {|op| op.input(INPUT).item.mark_as_deleted}

    operations.store

    return {}

  end

end
