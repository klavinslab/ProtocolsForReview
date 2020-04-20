needs "Yeast/StripwellMethods"
needs "Standard Libs/AssociationManagement"
needs "Standard Libs/InputOutput"
needs "Standard Libs/Feedback"
class Protocol
  include StripwellMethods, AssociationManagement, InputOutput, Feedback

  def main
    operations.retrieve
        
    # debuggin'
    # debug = false;
    debuggin

    # choose how many colonies are available
    colony_count
        
    # pick colony and find tanneal 
    pick_colony_find_tanneal

    # build a ops_by_temp hash that group operations by T Anneal
    ops_by_temp = build_ops_by_temp
    

    # produce stripwells
    sws = produce_stripwells ops_by_temp

    prepare_stripwell sws, 25, "NaOH"

    # add colonies to stripwells
    add_colonies_to_stripwells

    # Run the thermocycler
    thermocycler = run_thermocycler ops_by_temp

    # putting the plates away
    operations.store io: "input", interactive: true
    
    # Wait ten minutes
    wait_ten_min
    
    # This is unnecessary.
    #operations.retrieve io: "output", interactive: true
    
    # Retrieve and keep stripwells
    retrieve_keep_stripwells thermocycler, ops_by_temp

    # Set the location of the stripwells to be bench
    ops_by_temp.each do |t, ops| 
        ops.first.output("Lysate").collection.move "Bench"
    end
    
    # associate which colony was picked and from which plate it was picked
    # to the output part, so that fragment analyzing can know which colony it is qcing
    pass_down_colony_pick
    
    operations.store io: "output", interactive: false
    return {}
    
  end
  
  # This method is used for debugging purposes.
  def debuggin
    if debug
        operations.each do |op|
            plate = Item.where(object_type_id: ObjectType.find_by_name("Yeast Plate").id).sample
            op.plan.associate :yeast_plate, plate.id
            # newfv = FieldValue.new({
            #   name: "Plate",
            #   child_sample_id: plate.sample.id,
            #   value: plate,
            #   role: "input",
            #   parent_class: "Operation",
            #   parent_id: op.id
            # })
            # newfv.save
            # op.set_input("Plate", newfv)
            plate.associate :QC_result, ["No", "Yes", "Yes"] if [0, 1].sample == 0
        end
    end
  end

# asks technician what operations to kick out based on my how many colonies they can use
  def colony_count
    num_colonies = {}
    uniq_strains = operations.group_by { |op| op.input('Plate').item}
    # colony count
    data = show do
                title "Check Colony Count"
                uniq_strains.each do |item, op_arr|
                    table [['Plate Item Number', 'Number of colonies needed'], [item.to_s, op_arr.length]]
                    get "number", var: item.to_s, label: "How many colonies can be used?", default: op_arr.length
                end
            end
            
    uniq_strains.keys.each do |item|
        num_colonies[item] = data[item.to_s.to_sym]
    end
    
    kicked_ops = Hash.new{ |item,op_arr| item[op_arr] = [] }
    uniq_strains.each do |item, op_arr|
        ops_to_kick = op_arr.length - num_colonies[item]
        for i in 0..-1+ops_to_kick
            op_arr[i].change_status('error')
            op_arr[i].associate(:bad_colonies, 'This operation was errored because we didn\'t have enough colonies')
            kicked_ops[item].push(op_arr[i])
        end
    end
    
    if !kicked_ops.empty?
    operations.select! { |op| op.status == 'running' }
        show do
            title "Kicked out operations"
            warning "Please inform a lab manager that operations were kicked out because we didn't have enough colonies"
            note "The following operations were sent to error"
            kicked_table = [['Item', 'Yeast Strain', '# Kicked out']]
            kicked_ops.each do |item, op_arr|
                kicked_table.push([item.to_s, item.sample.name, op_arr.length])
            end
            table kicked_table
        end    
    end
  end
  
  # This method creates various associations and sets value in the temporary array.
  def pick_colony_find_tanneal
    operations.each do |op|
      plate = op.input("Plate").item
      op.plan.associate :plate, plate.id
      legacy_qc_num = (plate.get(:QC_result) || []).length
      plate.associate :num_qc_colonies, legacy_qc_num if plate.get(:num_qc_colonies).nil? 
      plate.associate :num_qc_colonies, plate.get(:num_qc_colonies).to_i + 1 if (plate.created_at < Time.utc(2018, "jan", 11, 19, 15))

      new_num_qc_col = plate.get(:num_qc_colonies).to_i + 1 
      op.temporary[:colony] = new_num_qc_col
      plate.associate :num_qc_colonies, new_num_qc_col
      
      
      if !plate.sample.properties["QC Primer1"]
          fwd = Sample.find_by_id(16749).properties["QC Primer1"]
          rev = Sample.find_by_id(16749).properties["QC Primer2"]
      else
          fwd = plate.sample.properties["QC Primer1"] 
          rev = plate.sample.properties["QC Primer2"]
      end
      op.temporary[:tanneal] = (fwd.properties["T Anneal"] + rev.properties["T Anneal"])/2
    end
  end
  
#   def get_items
#      show do
#          title "Gather the following item(s)"
         
#          operations.each do |op|
#              check "#{op.input("Plate").item.id}: #{op.input("Plate").sample.name}"
#          end
#      end
#   end
  
  # This method returns a hash of operations corresponding to several temperatures.
  def build_ops_by_temp
    ops_by_temp = {
      "70" => operations.select { |op| op.temporary[:tanneal] >= 70 },
      "67" => operations.select { |op| op.temporary[:tanneal] >= 67 && op.temporary[:tanneal] < 70 },
      "64" => operations.select { |op| op.temporary[:tanneal] < 67 }
    }.delete_if { |t, ops| ops.empty? }
    ops_by_temp
  end
  
  # This method produces and returns stripwells for given operations.
  def produce_stripwells ops_by_temp
    sw = []
    ops_by_temp.each do |t, ops|
      ops.make
      sw.push ops.output_collections["Lysate"]
      sw.flatten!
      ops.output_collections["Lysate"].each do |sw|
        # calling 'associate' from DataAssociator, not Collection
        Item.instance_method(:associate).bind(sw).call(:tanneal, t.to_i)
      end
    end
    sw
  end
  
  # This method tells the technician to add colonies to stripwells.
  def add_colonies_to_stripwells
    operations.map { |op| op.output("Lysate").collection }.uniq.sort { |x,y| x.id <=> y.id }.each do |sw|
      ops = operations.select { |op| op.output("Lysate").collection == sw }
      show do
        title "Load Stripwell #{sw.id}"
        
        table ops.start_table
          .custom_column(heading: "Location") { |op| op.output("Lysate").column + 1 }
          .custom_column(heading: "Colony cx from plate, 1/3 size", checkable: true) { |op| "#{op.input("Plate").item.id}.c#{op.temporary[:colony]}" }
        .end_table
        
        note "For each plate id.cx (x = 1,2,3,...), if a colony cx is not marked on the plate, mark it with a circle and write done cx (x = 1,2,3,...) nearby. If a colony cx is alread marked on the plate, scrape that colony."
        note "Use a sterile 10 L tip to scrape about 1/3 of the marked colony, swirl tip inside the well until mixed."
      end
    end
  end
  
  # This method tells the technician to start the lysate reaction and returns
  # the thermocycler that the technician used.
  def run_thermocycler ops_by_temp
    thermocycler = show do
      title "Start the lysate reactions"
      
      check "Put the cap on each stripwell #{ops_by_temp.map { |t, ops| ops.output_collections["Lysate"].uniq.map { |c| c.id } }.flatten }. Press each one very hard to make sure it is sealed."
      check "Vortex all the stripwells on a green tube holder on a vortexer."
      check "Place the stripwells into an available thermal cycler and close the lid."
      
      ops_by_temp.each do |temp, ops|
        get "text", var: temp.to_sym, label: "Enter the name of the thermocycler used", default: "TC1"
      end
      
      check "Click 'Home' then click 'Saved Protocol'. Choose 'YY' and then 'LYSATE'."
      check "Press 'run' and select 25 uL."
    end
    thermocycler #return
  end
  
  # This method tells the technician to wait 10 minutes.
  def wait_ten_min
    show do
      title "Wait for 10 minutes"
      
      timer initial: { hours: 0, minutes: 10, seconds: 0}
    end
  end
  
  # This method tells the technician to retrive and keep stripwells.
  def retrieve_keep_stripwells thermocycler, ops_by_temp
    show do
      title "Retrieve and keep stripwells"
      
      ops_by_temp.each do |temp, ops|
        check "Retrieve stripwells from #{thermocycler[temp.to_sym]}"
      end
      check "Keep the new stripwell(s) on the bench for the next protocol to use."
      warning "DO NOT SPIN DOWN STRIPWELLS."
    end
  end
  
  # This method passes down the colony of choice for following protocols.
  def pass_down_colony_pick
    operations.each do |op|
      # Use association map to cleanly associate data to the parts of a collection
      AssociationMap.associate_data(op.output("Lysate"), :colony_pick, op.temporary[:colony])
      AssociationMap.associate_data(op.output("Lysate"), :origin_plate_id, op.input("Plate").item.id)
    end
  end  
end