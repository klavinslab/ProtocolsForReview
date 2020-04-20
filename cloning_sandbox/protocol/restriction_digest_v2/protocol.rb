#Abe/Garrett 8-12-2017
#Edited by Garrett 8-13-17
#edited by ayesha 5-3-18 -- goodness, gracious, me, oh my; time seems to positively fly

needs "Cloning Libs/Cloning"

class Protocol

  include Cloning

  #IO
  OUTPUT = "Digest"
  INPUT = "Input DNA"
  INPUT_ENZYMES = "Enzymes"

#   # PARAMS
  QUANTITY_OF_DNA = 4000 #in ng
  VOL_OF_ENZYME = 1 #in uL
  VOL_OF_BUFFER = 4 #in uL
  TOTAL_VOL_RXN = 40 #in uL
  INCUBATION_TEMP = "37 C"
  INCUBATION_TIME = 60 #min
  MIN_CONC = 333 #in ng/uL
  ENZYME_BUFFER = "Cut Smart"
  MIN_PLASMID_CONCENTRATION = 333 # ng/ul
  HEAT_KILL_DURATION = 20

  def main
    buffer = Sample.find_by_name(ENZYME_BUFFER).in("Enzyme Buffer Stock").first
    take [buffer], interactive: true, method: "boxes"
    operations.retrieve only: [INPUT]
    check_concentration operations, INPUT

    # DEBUG associate a fake concentration
    debug = true
    if debug
      operations.each do |op|
        op.input(INPUT).item.associate :concentration, rand(400..500)
      end
    end

    # check concentration of plasmids
    check_concentration operations, INPUT

    # compute volumes
    operations.each do |op|
      stock = op.input(INPUT).item
      enzymes = op.input_array(INPUT_ENZYMES).items

      stock_conc = stock.get(:concentration).to_f
      if stock_conc < MIN_PLASMID_CONCENTRATION
        op.error :concentration, "The DNA stock #{stock.id} has too low of a concentration " +
            "(must be at least #{MIN_PLASMID_CONCENTRATION} ng/ul but found #{stock_conc} ng/ul)"
        next
      end

      stock_vol = QUANTITY_OF_DNA / stock.get(:concentration).to_f
      enzyme_vol = VOL_OF_ENZYME * enzymes.length.to_f
      water_vol = [(TOTAL_VOL_RXN - stock_vol - VOL_OF_BUFFER - enzyme_vol).to_f.round(1), 0].max
      op.temporary[:stock_vol] = stock_vol
      op.temporary[:water_vol] = water_vol
    end

    #end protocol if all operations have errored
    if operations.running.blank?
          show do
            title "All operations have errored"
          end
      return {}
    end

    # get enzymes
    show do
      title "Keep enzymes in a -20°C metal rack, on an ice block"
      warning "Restriction enzymes are very sensitive to repeated warming and their function will be impaired if they allowed to warm up during handling!"
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

    # put away ingredients, and place output stripwells in incubator
    operations.each {|op| op.output(OUTPUT).item.move "#{INCUBATION_TEMP} standing incubator"}
    operations.store io: "input", interactive: true, method: "boxes"
    release [buffer], interactive: true, method: "boxes"
    release operations.map {|op| op.output(OUTPUT).item}, interactive: true

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
        check "Set tabletop heatblock H1 from 50C to 65°C"
        check "Place all tubes of digest product into the heatblock"
        timer initial: { hours: 00, minutes: 20, seconds: 00}
    end
        
    show do 
        title "Remove from heat block"
        check "Reset heatblock H1 back to 50C"
        check "Have you reset the temperature of the heatblock?"
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

end