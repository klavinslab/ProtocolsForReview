needs 'SynAg/SynAg_Cytometry'
needs 'Tissue Culture Libs/CollectionDisplay'
needs 'SynAg/Container_methods'
needs 'SynAg/Media and Reagents'


class Protocol
    include Cytometers
    include CollectionDisplay
    include Stripwells
    include PBSF
    
    INPUT = "Overnight"
    ROLE = "Sample_role"
    ASSAY_PLATE = "96 well U-bottom assay plate, clear"
    ASSAY_PLATE_LOCATION = "Draw under the cytometer"
    INCUBATION_TIME = 60
    TECH_REPS = 2
    ANTIBODY = "FITC"
    
    def main
     
        intro
        
        pbs_vol = (operations.length * TECH_REPS * 1.1 * (150 + 200) / 1000).round(1)
        pbsf_vol = (operations.length * TECH_REPS *  1.1 * (150 + 15 + 150) / 1000).round(1)
        
        prepare_assay_buffers(pbs_vol, pbsf_vol)
        
        operations.retrieve
        
        add_antibody_incubate_read
        
        # upload_well_info
        
        clean_up
        
        return {}
    end

################################################################################################################
  
    def intro
      show do
          title "Summary of SynAg Yeast Display"
          note " In this protocol you will first measure the cell densities of a number of yeast overnights"
          note "Then you will spin down cells and incubate them with an antibody for 1 hour"
          note "The antibody is 'looking for' a surface expressed protein, and it has an attached fluorophore. After incubation you will run the samples in the flow cytometer to check for fluoresence as a measure of surface-expressed protein abundance. You will end the protocol by uploading the FCS files from the flow cytometer"
          note "This protocol will require roughly <b>2.5 hours</b>: 45 minutes set up time, then 1 hour incubation time, then 45 minutes for data collection"
        end
    end 

################################################################################################################
    
        
    def add_antibody_incubate_read
        
        #Work out volumes for antibody incubation
        pbsf = operations.length * TECH_REPS * 10 * 1.1 #10 µL per sample
        fitc = operations.length * TECH_REPS * 1.1 #1 µL antibody per sample
        prepare_antibody(pbsf, fitc)
        
        ## This whole subsection is simply working out how to assign samples to stripwells and plates, and return the right values to the Technician. 
        #################
            #Create an array and fill it with the sample ids with the input array
            sample_list = []
            operations.each do |op|
                sample_list.push(op.input(INPUT).sample.id)
            end
            #Create a new array where each of those sample ids is tripled
            sample_list_with_reps = sample_list.flat_map { |s| [s] * TECH_REPS }
            #Create new arrays of collections containing three of each sample.
            stripwells = Collection.spread(sample_list_with_reps, "Stripwell")
            read_plate = Collection.spread(sample_list_with_reps, "96 U-bottom Well Plate")
            
            stripwell_array = []
            stripwells.each do |st|
                n = 1
                (12 / TECH_REPS).times do
                    wells = []
                    TECH_REPS.times do
                        wells.push(n)
                        n = n + 1
                    end
                    stripwell_array.push([st.id,wells])
                end
            end

            
            n = 0
            operations.each do |op|
                op.associate :stripwell_id, stripwell_array[n][0]
                op.associate :stripwell_wells, stripwell_array[n][1]
                n = n + 1
            end
            
           rows = ['A','B','C','D','E','F','G','H']
           columns = [1,2,3,4,5,6,7,8,9,10,11,12]
           plate_array = []
           rows.each{|r| columns.each{|c| plate_array.push(r+c.to_s)}}
            
            n=0
            operations.each do |op|
                wells = []
                TECH_REPS.times do
                    wells.push(plate_array[n])
                    n = n + 1
                end
                op.associate :plate_wells, wells
            end
            
        #Here I am creating two lists, one of numbers and one of letters, and 'zipping' them together to create an array of 2-part arrays. Then I am adding all of these as key: value pairs into a hash called alpha_table.
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
            
        
        show do |op|
            title "Label stripwells"
            check "Take #{stripwells.length} stripwells"
            check "Cut each stripwell in half"
            note "Label both sides of each stripwell as follows"
            stripwells.each do |s|
                check "Two half stripwells labelled: #{s.id}"
            end
        end
        
        show do
            title "Dispense PBSF into stripwells"
            note "150 µl into each well. Consider using the multistepper pipette for this step"
               table operations.start_table
                    .custom_column(heading: "Stripwell ID"){|op| op.get(:stripwell_id)}
                    .custom_column(heading: "Wells"){|op| op.get(:stripwell_wells)}
                    .custom_column(heading: "PBSF"){"150 µl"}
                    .end_table
        end
                #Each strain should be divided into three technical replicates. 100,000 cells will be taken from each strain. 
        show do 
            title "Dispense yeast"
            note "Dispense from each yeast overnight into #{TECH_REPS} stripwell wells."
            check "First quickly vortex each overnight tube to resuspend the cells"
            table operations.start_table
                .input_item(INPUT, heading: "Overnight")
                .custom_column(heading: "Stripwell ID"){|op| op.get(:stripwell_id)}
                .custom_column(heading: "Wells"){|op| op.get(:stripwell_wells)}
                .custom_column(heading: "Add yeast", checkable: true){"50 µl"}
                .end_table
        end
 
        spin_down("Stripwell", 30) 

        #5. Remove supernatant. 
        sn_vol = 180
        
        show do 
            title "Remove supernatant"
            note "Remove #{sn_vol} µl of supernatant with a p1000 pipette. Use the same tip for all wells unless you disturb the pellet, in which case discard the tip."
            table operations.start_table
                .custom_column(heading: "Stripwell ID"){|op| op.get(:stripwell_id)}
                .custom_column(heading: "Wells"){|op| op.get(:stripwell_wells)}
                .custom_column(heading: "Remove Supernatant", checkable: true){"#{sn_vol} µl"}
                .end_table
        end
                
        #6. Add 1g FITC. # Incubate 1 hr. (Should test if this can be reduced to something like 30 minutes)
        show do 
            title "Add antibody"
            note "Add 10 µL of the the FITC antibody prepared in step 8 into every well of each stripwell. Consider using the multistepper pipette for this step"
            table operations.start_table
                .custom_column(heading: "Stripwell ID"){|op| op.get(:stripwell_id)}
                .custom_column(heading: "Wells"){|op| op.get(:stripwell_wells)}
                .custom_column(heading: "Antibody", checkable: true){"10µl FITC"}
                .end_table
            check "Vortex 2 seconds on high speed"
            check "Place stripwells in a draw or in aluminum foil"
        end
        
        show do 
            title "Incubate 1 hour"
            timer initial: { hours: 1, minutes: 00, seconds: 00}
            note "Clean up work bench while samples incubating"
            check "14 mL culture tubes to the rack by the sink"
            check "Discard empty antibody tube into Normal waste"
        end

        operations.each do |op|
            op.input(INPUT).item.mark_as_deleted
            op.input(INPUT).item.save
        end
          
      ##Wash the yeast 
        
        num = 1
        
        2.times do
            
            show do 
                title "Wash number #{num}"
                if num == 1
                    check "Add 150 µl of <b>PBSF</b> to each well. Consider using the multistepper pipette for this step"
                elsif num == 2
                    check "Add 150 µl of <b>PBS</b> to each well. Consider using the multistepper pipette for this step"
                    check "Vortex on low speed"
                end
            end
            
            spin_down("Stripwell", 30) 
            
            show do 
                title "Remove supernatant"  
                check "Remove 150 µl supernatant from each well"
            end
            
            num = num + 1
            
        end
        
        show do 
            title "Fill up tubes and vortex"
            check "Add 200 µl of PBS (Not PBSF) to each well"
            check "Close lids and vortex to thoroughly mix"
        end
        
        show do 
            title "Check that stripwells are in correct order"
            note "Stripwells might have gotten out of order during wash steps"
            note "Check that you have the stripwells in the correct order before proceeding"
                  table operations.start_table
                    .custom_column(heading:"Stripwell ID") {|op| op.get(:stripwell_id)}
                    .custom_column(heading:"Stripwell location") {|op| op.get(:stripwell_wells)}
                    .end_table
        end
            
        show do 
            title "Transfer samples into a 96 well plate for measurement at the cytometer"
            check "Grab 1 x clean #{ASSAY_PLATE} from #{ASSAY_PLATE_LOCATION}"
            note "Transfer 150 µl into each plate well according to the following scheme"
            table operations.start_table
                    .input_sample(INPUT, heading: "Sample ID")
                    .custom_column(heading:"Stripwell ID") {|op| op.get(:stripwell_id)}
                    .custom_column(heading:"Stripwell location") {|op| op.get(:stripwell_wells)}
                    .custom_column(heading:"Plate wells", checkable: true) {|op| op.get(:plate_wells)}
                    .end_table
        end
            
        cytometer = Cytometers::BDAccuri.instance
            
        show do
            title 'Flow cytometery - info'
            warning "The following should be run on a browser window on the #{cytometer.cytometer_name} computer!"
            check 'Run plate'
            note 'Speed: Medium, Limits: 10,000 events + 30 uL'
            upload var: "fcs"
            check "Run cleaning cycle"
         end
             
             
        operations.each do |op|
            wells = op.get(:plate_wells)
            op_array = [op.input(INPUT).sample.id, op.input(ROLE).val]
            wells.each do |w|
                op.associate w.to_sym, op_array
            end
        end

    end

    
    def clean_up
        
        show do 
            
            title "Clean up the work area"
            note "Make sure your work bench is as clean or cleaner than you found it"
        end
        
    end
    
end