
needs "Cloning Libs/Cloning"

class Protocol

  include Cloning

  #IO
  OUTPUT = "Digest"
  INPUT = "Input DNA"
  INPUT_ENZYMES = "Enzymes"
  INPUT_AMOUNT = "Digest amount (micrograms)"

#   # PARAMS
  VOL_OF_ENZYME = 1 #in uL
  VOL_OF_BUFFER = 4 #in uL
  TOTAL_VOL_RXN = 40 #in uL
  INCUBATION_TEMP = "37 C"
  INCUBATION_TIME = 60 #min
#   MIN_CONC = 333 #in ng/uL
  ENZYME_BUFFER = "Cut Smart"
  MIN_PLASMID_CONCENTRATION = 333 # ng/ul
  HEAT_KILL_DURATION = 20

  def main
    buffer = Sample.find_by_name(ENZYME_BUFFER).in("Enzyme Buffer Stock").first
    take [buffer], interactive: true, method: "boxes"
    operations.retrieve only: [INPUT]
    check_concentration operations, INPUT

    # DEBUG associate a fake concentration

    if debug
      operations.each do |op|
        op.input(INPUT).item.associate :concentration, rand(200..300)
      end
    end

    # check concentration of plasmids
    check_concentration operations, INPUT

    # compute volumes
    operations.each do |op|
      stock = op.input(INPUT).item
      enzymes = op.input_array(INPUT_ENZYMES).items
      min_conc = op.input(INPUT_AMOUNT).val * 50
      stock_conc = stock.get(:concentration).to_f
      dna_ul_needed = (op.input(INPUT_AMOUNT).val * 1000) / stock_conc
      min_conc = (op.input(INPUT_AMOUNT).val * 1000) / 40
      
      if dna_ul_needed > 40
        op.error :concentration, "The DNA stock #{stock.id} has too low of a concentration " +
            "(must be at least #{min_conc} ng/ul but found #{stock_conc} ng/ul)"
        next
      end

      stock_vol =  (op.input(INPUT_AMOUNT).val * 1000) / stock.get(:concentration).to_f
      enzyme_vol = VOL_OF_ENZYME * enzymes.length.to_f
      water_vol = [(TOTAL_VOL_RXN - stock_vol - VOL_OF_BUFFER - enzyme_vol).to_f.round(1), 0].max
      
      
      op.temporary[:stock_vol] = stock_vol
      op.temporary[:water_vol] = water_vol
    end
    
    check_volumes

    #end protocol if all operations have errored
    if operations.running.blank?
          show do
            title "All operations have errored"
          end
      return {}
    end


    operations.make
    
    show do
    title "prepare digest tubes"
    note "Grab #{operations.running.length} 0.6 mL tubes and label with the following item ids: #{operations.running.map {|op| op.output(OUTPUT).item.id}.to_sentence}"
  end

    show do
      title "Load Tubes with Molecular Grade Water"

      table operations.start_table
                .output_item(OUTPUT, heading: "Tube")
                .custom_column(heading: "Molecular Grade Water (uL)", checkable: true) {|op| op.temporary[:water_vol].to_f.round(1)}
                .end_table
      warn = check_p2 operations, :water_vol
      note "#{warn}"
    end

    show do
      title "Load Tubes with #{ENZYME_BUFFER} Buffer"

      note "Add #{VOL_OF_BUFFER}uL of Buffer to the following stripwell(s):"
      table operations.running.start_table
                .output_item(OUTPUT)
                .custom_column(heading: ENZYME_BUFFER, checkable: true) {|op| VOL_OF_BUFFER}
                .end_table
    end
    
        # get enzymes

    
    # add plasmid stock to wells
    show do
      title "Load Tubes with Template"

      table operations.start_table
                .output_item(OUTPUT, heading: "Digest Tube")
                .input_item(INPUT, heading: "Input DNA")
                .custom_column(heading: "Volume to add (uL)", checkable: true) {|op| op.temporary[:stock_vol].to_f.round(1)}
                .end_table
      warn = check_p2 operations, :stock_vol
      warning "#{warn}"
    end
    
    show do
      title "Retrieve enzymes"
      warning "Keep enzymes in a -20C metal rack, on an ice block"
      note "Restriction enzymes are very sensitive to repeated warming and their function will be impaired if they allowed to warm up during handling!"
    end
    
    operations.retrieve only: [INPUT_ENZYMES]

    # add enzymes to wells
    show do
      title "Load Tubes with Enzymes"

      note "Load wells with #{VOL_OF_ENZYME} uL of each specified enzyme"

      table operations.running.start_table
                .output_item(OUTPUT, heading: "Tube")
                .custom_column(heading: "Enzymes (add #{VOL_OF_ENZYME} uL of each)", checkable: true) {|op| op.input_array(INPUT_ENZYMES).items.map {|e| e.id}.to_sentence} # .to_sentence is neat!
                .end_table
    end
    
    show do 
        title "Place the digests in incubator"
        note "Place the digests in the 37°C incubator"
        table operations.running.start_table
                .output_item(OUTPUT, checkable: true)
                .end_table
    end
        

    # put away ingredients, and place output stripwells in incubator
    operations.each {|op| op.output(OUTPUT).item.move "#{INCUBATION_TEMP} standing incubator"}
    operations.store io: "input", interactive: true, method: "boxes"
    release [buffer], interactive: true, method: "boxes"
    operations.store only: [INPUT_ENZYMES]
    # release operations.map {|op| op.output(OUTPUT).item}, interactive: true

    # start incubation timer for one hour
    show do
      title "Start incubation timer"
      timer initial: { hours: 1, minutes: 00, seconds: 00}
      note "After timer finishes, go on to the next steps."
    end

    #grab stripwells back from incubator, and transfer to fridge
    take operations.map {|op| op.output(OUTPUT).item}, interactive: true

    show do
        title "Heat kill the restriction enzymes"
        note "Now the digest is completed the enzymes are heat inactivated"
        check "Set tabletop heatblock H1 from 50C to 65C"
        check "Place all tubes of digest product into the heatblock"
        timer initial: { hours: 00, minutes: 20, seconds: 00}
    end
        
    show do 
        title "Remove from heat block"
        check "Reset heatblock H1 back to 50C"
        check "Have you reset the temperature of the heatblock?"
    end
    
    update_output_concentrations
    
    operations.each do |op|
        op.output(OUTPUT).item.store
    end
    
    operations.store io: "output", interactive: true
    
  return {}
end

# displays warning to use P2 pipette if necessary, for use in adding water and plasmid stock
    def check_p2 operations, vol
      operations.running.each do |op|
        if op.temporary[vol] < 0.4
          return "There are volumes smaller than 0.4; please use the P2!"
        end
      end
    end
    
    def update_output_concentrations
        operations.running.each do |op|
            op.output(OUTPUT).item.associate :concentration, ((op.input(INPUT_AMOUNT).val * 1000) / TOTAL_VOL_RXN)
            op.output(OUTPUT).item.associate :volume, TOTAL_VOL_RXN
        end
    end
   
   # asks the technician if there is enough plasmid and water volume.
   # errors the operation if there isn't of either volume
   def check_volumes
        
    # ask tech if there is enough volume
      vol_checking = show do 
        title "Checking Volumes"
        operations.each do |op|
           select ["Yes", "No"], var: "#{op.input(INPUT).item.id}_stockvol", label: "Does #{op.input(INPUT).item.id} have at least #{op.temporary[:stock_vol].round(2)} uL?", default: 0
           select ["Yes", "No"], var: "#{op.input(INPUT).item.id}_watervol", label: "Does #{op.input(INPUT).item.id} have at least #{op.temporary[:water_vol].round(2)} uL?", default: 0
        end
      end
      
      operations.each do |op|
        if vol_checking["#{op.input(INPUT).item.id}_stockvol".to_sym] == "No" || vol_checking["#{op.input(INPUT).item.id}_watervol".to_sym] == "No"
          op.error :not_enough_volume, "Not enough volume for this plasmid"
        end
      end
        
    end
    

        
        

end