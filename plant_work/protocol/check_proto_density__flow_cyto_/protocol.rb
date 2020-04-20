needs 'Tissue Culture Libs/CollectionDisplay'
# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol
    include CollectionDisplay
    INPUT = "Digesting Cells"
    OUTPUT = "TEMP OUTPUT"
    STAIN = "Live:Dead Stain"
    INSTRUMENT = "Instrument"
    FLOW_CYT = "Flow Cytometer"
    MICROSCOPE = "Microscope"
    DISCARD_ANS = "Discard tubes"
    PLATE_LOC =  "the yellow box over Eddie's old desk"
    
    DEBUG = true

  def main

    operations.retrieve.make
    
    stain_ops = select_ops(STAIN,"Yes")
  
    unless stain_ops.empty?
        stain_cells(stain_ops)
    end 
    
    plate, positions = set_plate_layout
    
    check_density(plate, positions) #Positions are the positions of the slow, medium and fast speed wells for each sample.
    
    discard_tubes

    {}

  end
  
    def select_ops(criterion, value)
      
      return operations.select{|op| op.input(criterion).val == value}
    
    end
    # ________________________________________________________________________________
        
    def stain_cells(ops)
    end
    
    # ________________________________________________________________________________
    
    def set_plate_layout 
        
        sample_list = []
        operations.each do |op|
            sample_list.push(op.input(INPUT).sample.id)
        end
        #Create a new array where each of those sample ids is tripled
        sample_list_with_reps = sample_list.flat_map { |s| [s] * 3 }
    
        
        read_plate = Collection.spread(sample_list_with_reps, "96 U-bottom Well Plate")
  
        
        alpha_table = {}
        ((0..7).zip('A'..'H')).each { |x| alpha_table[x[0]] = x[1] }
                    
        #Here I am making a new hash to fill with the well locations for each sample. 
        operations.each do |op|
            s = op.input(INPUT).sample.id
            #Find the matrix positions for each sample in the read_plate. The [0] is needed because read_plate is actually an array of collections
            plate_location = read_plate[0].find(s)
            #This mapping will create a new array where the row 'number' is converted to a letter via alpha_table defined above, and the column number is increased by 1 so it starts at 1 instead of 0. 
            plate_location_alpha = plate_location.flat_map{ |r,c| [[alpha_table[r], c + 1]]}
            #This line just consolidates this info into a single string for each well. 
            plate_location_simple = plate_location_alpha.flat_map{ |r,c| "#{r}#{c}"}
            #This line adds that info into the hash defined above. 
            op.associate :sample_plate_location, plate_location_simple
        end
        
        show do 
            title "Transfer protoplasts into cytometry plate"
            note "Use a 96 well U-bottom plate from #{PLATE_LOC}"
            note "Transfer 150 l into each plate well according to the following scheme"
            warning "Use a cut p1000 tip for the transfers"
            table operations.start_table
                    .input_item(INPUT, heading: "Protoplasts")
                    .custom_column(heading:"Plate wells", checkable: true) {|op| op.get(:sample_plate_location)}
                    .end_table
        end
       
       fast_wells = []
       med_wells = []
       slow_wells = []
        operations.each do |op|
            op.input(INPUT).item.associate :fast_well, op.get(:sample_plate_location)[0]
            op.input(INPUT).item.associate :med_well, op.get(:sample_plate_location)[1]
            op.input(INPUT).item.associate :slow_well, op.get(:sample_plate_location)[2]
            fast_wells.push(op.input(INPUT).item.get(:fast_well))
            med_wells.push(op.input(INPUT).item.get(:med_well))
            slow_wells.push(op.input(INPUT).item.get(:slow_well))
        end
        
        if debug
            show do 
                operations.each do |op|
                    note "#{op.get(:sample_plate_location)}"
                    note "#{op.input(INPUT).item.get(:slow_well)}"
                    note "#{op.input(INPUT).item.get(:med_well)}"
                    note "#{op.input(INPUT).item.get(:fast_well)}"
                end
            end
        end
        
        show do 
            note "#{read_plate}"
        end
        
        positions = {}
        positions[:fast_wells] =  fast_wells
        positions[:med_wells] = med_wells
        positions[:slow_wells] = slow_wells
        
        return read_plate, positions

    end
    
    def check_density(plate, positions)
        
        show do
            title "Check cytometer"
            check "Sufficient sheath fluid?"
            check "Waste no too high?"
        end
        
        show do 
            title "Set up the cytometer"
            check "Limits for each well: '30 uL and 10,000 events'"
            note "Set the speed differently for each well according to the scheme below"
            check "Fast: #{positions[:fast_wells]}"
            check "Med: #{positions[:med_wells]}"
            check "Slow: #{positions[:slow_wells]}"
            check "Save as 'Proto_check_DATE'"
        end
        
        run = show do 
            title "Run plate"
            check "Make sure you are on Autorun and then hit run"
            note "Upload all FCS files from the run"
            upload var: :fcs_files
        end
            
    end
        

    # ________________________________________________________________________________
    
    def discard_tubes
        
        show do 
            title "Discard tubes of protoplasts"
            note "Discard in the Biohazard waste"
            operations.each do |op|
                tube = op.input(INPUT).item
                if op.input(DISCARD_ANS).val == "Yes"
                    check "#{tube.id}"
                    tube.mark_as_deleted
                end
            end
        end
        
    end
    
end
