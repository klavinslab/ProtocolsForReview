needs "Tissue Culture Libs/CollectionDisplay"


INPUT = "Test strain"
REPS  = 2
FCS_EXPORTS_DIRECTORY = 'Desktop/FCS_exports'
SAVE_FOLDER = "Choose a folder name"
PLANT_AGE_KEY = "plant_age_in_days"
INDUCER_KEY = "inducer"
CYT_NAME = "Miltenyi Cytometer"
CYT_LOCATION = "Seelig lab. Lab 340, SW corner"

class Protocol
    
    include CollectionDisplay

  def main
      
    if CYT_NAME == "Miltenyi Cytometer" then @@miltenyi = true end
    
    plate = define_plate_layout
    
    operations.retrieve
    
    add_cells_to_plate(plate)
    
    if @@miltenyi 
        move_to_cytometer(plate)
        
        if first_run == 'Yes' then initiation_protocol end
    end
    
    setup_plate_on_cytometer(plate)
    
    run_cytometer(plate)
    
    wash_cytometer

    discard_items

    {}

  end
  
    def initiation_protocol
        
        show do 
            title "Start up the machine"
            note "<b> Touch the screen </b>. If necessary turn on the machine, switch on the lower right side"
            check "Log in with your full name. Or 'Jason Fontana'. No password"
            check "Set the software to 'Acquisition Mode' - On/Off button on the upper right of the screen on the machine"
            check "Get a falcon tube of hot, dilute bleach from the bead bath in the Carothers lab, by the window, in the opposite side of the lab"
            note "If the tube of bleach is empty refill it with 9 mL Clorox and 41 mL of 1 x PBS"
            check "Fill a 1.5 mL epi with hot bleach and place into the sample holder"
            check "Run a wash cycle (<right click</b> the water droplet icon on the bottom right)"
            note "This takes 10 minutes"
            check "Run a flush cycle. No sample input needed. This takes roughly 18 minutes and (also initiated with a right click on the waterdroplet icon)"
        end
        
    end
    
    def first_run
        ans = show do 
            title "Is this the first run of the day?"
            note "If the machine is off, and no one has signed the log book for today then it is the first run"
            select ["Yes","No"], var: :x, label: "First run?", default: 0
        end
        return ans[:x]
    end
    
    def move_to_cytometer(plate)
                
        show do
            title "Transfer to cytometer #{CYT_NAME}"
            check "Take Plate #{plate.id} to #{CYT_LOCATION}"
            if @@miltenyi == true then check "Bring a USB pen" end
        end
        
        if @@miltenyi == true
            
            show do 
                title "Enter name and details into log book"
                note "Log book located next to cytometer"
            end
            
            show do 
                title 'Take 96 well block from freezer'
                note 'Freezer has sliding doors, next to fume hood, along Southern wall'
            end
        end
    end
    
    
    
    def wash_cytometer
        
        if @@miltenyi
            show do
              title "Wash machine fluidics"
              note "Set acquisition settings to:"
              check "No event gate. Settings > Events > Untick the box"
              check "Sample Volume: 700 uL"
              check "Uptake volume: 450 uL"
              check "Mix Sample: Off"
              check "Flow rate: High"
              check "Rack: Single tube rack"
              3.times do 
                check "Fill a 1.5 mL tube with roughly 1 mL of hot bleach solution (or just hold falcon to SIP?)"
                check "Hit run"
              end
              check "Return hot bleach"
              check "Record /A in the logbook column 'First/After run?'"
              check "Once done initiate shutdown using the on-screen button"
              note "You can leave once shutdown has been initiated"
            end
        end
        
        
    end
  
    def define_plate_layout
        
        plate = Collection.new_collection("96 U-bottom Well Plate")
        
        plate_rows = ["A","B","C","D", "E", "F", "G", "H"]
        plate_columns = ["01","02","03","04","05","06","07","08","09","10","11","12"]
        plate_wells = []
        plate_rows.each do |r|
            plate_columns.each do |c|
                plate_wells.push("#{r}#{c}")
            end
        end
        
        #Add file keys that will be in the Miltenyi records
       
        n = 0
        operations.each do |op|
            
            op.associate :plate_id, plate.id
            
            ##Add samples to plate
            sample_ids = [op.input(INPUT).sample.id] * REPS
            plate.add_samples(sample_ids)
            
            ## Associate the input item ids, transfection plasmid ids as part associations
            sample_parts = plate.select{|p| p == op.input(INPUT).sample.id}
            item_id = op.input(INPUT).item.id
            incubation_hrs = ((Time.zone.now - op.input(INPUT).item.created_at) / (60*60)).round(2)
            if debug then incubation_hrs = 17 end
            inducer_conditions = op.input(INPUT).item.get(INDUCER_KEY)
            
            sample_parts.each do |p| #Note each part has a row and column position, accessed as part[0] and part[1]
               #Associate item id of transfection mix
                unless plate.get_part_data(:item_id, p[0], p[1]) #This unless clause is necessary to avoid parts with the same sample ID having their data overwritten. 
                    plate.set_part_data(:item_id, p[0], p[1], item_id)
                end
                
                #Associate mating incubation time
                unless plate.get_part_data(:incubation_hrs, p[0], p[1])
                    plate.set_part_data(:incubation_hrs, p[0], p[1], incubation_hrs)
                end
                
                #Associate plate well
                unless plate.get_part_data(:plate_well, p[0], p[1])
                    plate.set_part_data(:plate_well, p[0], p[1], plate_wells[n])
                    n = n + 1
                end
                
                #Associate inducer conditions
                if inducer_conditions
                    if plate.get_part_data(:item_id, p[0], p[1]) == item_id
                        plate.set_part_data(INDUCER_KEY, p[0], p[1], inducer_conditions)
                    end
                end

            end
            
        end
        
        if debug
                keys = [:item_id, :incubation_hrs, INDUCER_KEY]
                keys.each do |k|
                    show do 
                        title "Data check"
                        note "#{k.to_s}"
                        note "#{plate.data_matrix_values(k)}"
                    end
                end
        end
        
        return plate

    end
    
    def setup_plate_on_cytometer(plate)
        
        rcx_list = []
        plate.get_non_empty.each do |r,c|
            rcx_list.push([r,c, plate.get_part_data(:plate_well, r, c)])
        end
        
        if CYT_NAME == "BD Accuri"
            show do 
                title "Create a new file on the cytometer"
                check "Plate type: 96 well u-bottom"
                check "Speed: slow"
                check "Limits: 20,000 events and 30 uL"
                check "Select following wells:"
                table highlight_rcx plate, rcx_list
                check "Save in folder #{SAVE_FOLDER} as '#{Time.zone.now.strftime("%m-%d-%Y")} - SynAg Pairwise Mating'  <b> Do not use '/' in the file name </b>"
            end
        end
        
        if @@miltenyi
            show do
                title "Run set up"
                check "Load the voltage adjustment settings 'DY Yeast' ([A] on the toolbar along the top), then log out and log back in"
                note "These adjustments on the gates will tune their sensitivity, essentially shifting the absolute values recorded so that cells of interest are 'hitting' the channel filter within the optimal range, giving you good resolution of results"
                check "Load Rack Type: Chill 96 rack"
                check "Flow rate - Low."
                check "Mix sample - Medium." 
                check "Uptake - 20 uL, Sample volume - 80 uL.<Hit return </b> after setting each volume"
                check "Settings > Events > 10,000"
                check "Select all channels"
                check "Select sample wells. Check that sample wells get an orange ring"
                table highlight_rcx plate, rcx_list
            end
        end
        
        show do
            title "Load plate"
            note "Single tube reagent reservoir can be stored on side of the machine. Near on/off switch."
            note "Ensure nothing is to the left of the SIP (sample needle) or this will interfere with the sample collection arm's movements"
        end
        
    end
    
    def add_cells_to_plate(plate)
        
        rcx_list_item_ids = []
        plate.get_non_empty.each do |r,c|
            rcx_list_item_ids.push([r,c, plate.get_part_data(:item_id, r, c)])
        end
        
        rcx_list_wells = []
        plate.get_non_empty.each do |r,c|
            rcx_list_wells.push([r,c, plate.get_part_data(:plate_well, r, c)])
        end
        
        show do
            title "Add water to plate"
            note "Add <b> 98 µL </b> of distilled water to each of the highlighted wells"
            table highlight_rcx plate, rcx_list_wells
        end
        
        show do 
            title "Add cells to plate"
            note "Briefly vortex overnight culture tube before use"
            note "Transfer <b> 2 µL </b> from each onvernight culture, #{REPS} times, as indicated below"
            check "2 uL into each well"
            table highlight_rcx plate, rcx_list_item_ids
        end
        
        show do 
            title "Seal plate and vortex"
            check "Seal the plate with a plastic plate seal"
            check "Lightly vortex to ensure contents of each well are mixed"
            warning "Vortexing on high power could lead to cross-contamination between wells"
        end
    end
    
    def  run_cytometer(plate)
        show do
            title "Place plate in cytometer"
            check "Unseal plate"
            check "Run plate"
        end
        
        if @@miltenyi == true
            show do
                title "Transfer files to USB pen"
                check "Export all files as .fcs, by selecting them from the panel on the left of the screen"
                check "Insert USB pen into MACSQuant"
                check "On the top toolbar hit File > Copy > Data Files > Private > Select the relevant date"
            end
            
            show do 
                title "Insert USB pen into relevant computer"
                check "Enter the USB pen into a computer that you are running this Job on"
                note "If necessary move computer"
            end
            
            prefix = show do 
                title "Associate file names with the wells of the sample plate"
                note "Enter the prefix of the file names from the Milentyi. Everything up to the last 2 digits and .fcs"
                note "This is likely to be 'O2019-10-01.00'"
                get "text", var: :x, label: "Prefix", default: "O2019-10-01.00"
            end
            
            prefix = prefix[:x]
            
            total_wells = plate.get_non_empty.length
            
            show do 
                last_well = 0
                plate.get_non_empty.each do |w|
                    r = w[0]
                    c = w[1]
                    base = r + 1
                    current_well = (r * 12) + c
                    remaining_rows = ((total_wells - current_well) / 12).floor #Number of complete rows (sets of 12) succeeding this well
                    preceding_rows = (current_well / 12).floor #Number of complete rows (sets of 12) preceding this well
                    ## Needs to be fixed to also take account of the rows above you. 
                    if w == [0,0]
                        n = 1 #The very first well should always be 1
                    else 
                        n = (last_well + 1 + remaining_rows + preceding_rows) #Otherwise you just go up by 1 plus an extra 1 for each preceding or succedding complete row
                    end
                    last_well = n
                    if current_well == (11||23||35||47||59) then last_well = 0 end #Resets count at the end of each row
                    if n < 10
                        plate.set_part_data(:miltenyi_file_name, w[0], w[1], "#{prefix}0#{n}.fcs")
                    else 
                        plate.set_part_data(:miltenyi_file_name, w[0], w[1], "#{prefix}#{n}.fcs")
                    end
                end
            end

            
        end
        
        show do 
            title "Upload data"
            check "Export all files as FCS"
            check "Open up the folder containing all exported FCS files (found in directory: #{FCS_EXPORTS_DIRECTORY})"
            upload 
        end
        
    end
    
    def discard_items
        
        show do 
            title "Discard mating tubes"
            note "Discard mating tubes into cleaning sink"
            operations.each do |op|
                check "#{op.input(INPUT).item.id}"
            end
            check "Place assay plate into cleaning tub by the sink"
        end
        
        operations.each do |op|
            op.input(INPUT).item.mark_as_deleted
        end
    end

end
