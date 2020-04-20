module Dilutions
    
    BE_SAMPLE = 12205
    COR_SAMPLE = 29671
    INDUCER_STOCK_100uM_CONTAINER = 475
    INDUCER_STOCK_10uM_CONTAINER = 476
    INDUCER_STOCK_1uM_CONTAINER = 487
    INDUCER_STOCK_0mM_CONTAINER = 840
    INDUCER_STOCK_1mM_CONTAINER = 482
    INDUCER_STOCK_30mM_CONTAINER = 841
    INDUCER_STOCK_5mM_CONTAINER = 842
    
    def inducer_series(inducer, strain_no)
        
        #To make sure there is enough for each strain with a little left over
        end_vol = (strain_no.to_f/10)* 1.1
        
        if inducer == "be"
            stock_no_conc = Item.where(sample: Sample.find(BE_SAMPLE), object_type_id: INDUCER_STOCK_0mM_CONTAINER).reject{|i| i.location == "deleted"}[0]
            stock_hi_conc = Item.where(sample: Sample.find(BE_SAMPLE), object_type_id: INDUCER_STOCK_100uM_CONTAINER).reject{|i| i.location == "deleted"}[0]
            stock_mid_conc = Item.where(sample: Sample.find(BE_SAMPLE), object_type_id: INDUCER_STOCK_10uM_CONTAINER).reject{|i| i.location == "deleted"}[0]
            stock_lo_conc = Item.where(sample: Sample.find(BE_SAMPLE), object_type_id: INDUCER_STOCK_1uM_CONTAINER).reject{|i| i.location == "deleted"}[0]
            inducer_box_location = "TI1, located in the second -20C freezer, second shelf from the top"
            inducer_name = "Beta-estradiol"
            end_concs = [0.05, 0.1, 0.5, 1, 2, 5, 10, 50]
            wells = [1,2,3,4,5,6,7,8]
            solvent_vol = [ 9.5, 9, 5, 9,8,5,9, 5] 
            solvent_vol = solvent_vol.map{ |i| (i * end_vol).round(1)}
            stock = [stock_lo_conc.id, stock_lo_conc.id, stock_lo_conc.id, stock_lo_conc.id, stock_mid_conc.id, stock_mid_conc.id, stock_mid_conc.id,stock_hi_conc.id,stock_hi_conc.id,stock_hi_conc.id]
            stock_vol = [0.5, 1, 5, 1, 2, 5, 1, 5]
            stock_vol = stock_vol.map{ |i|(i * end_vol).round(1)}
        elsif inducer == "coronatine"
            stock_no_conc = Item.where(sample: Sample.find(COR_SAMPLE), object_type_id: INDUCER_STOCK_0mM_CONTAINER).reject{|i| i.location == "deleted"}[0]
            stock_lo_conc = Item.where(sample: Sample.find(COR_SAMPLE), object_type_id: INDUCER_STOCK_1mM_CONTAINER).reject{|i| i.location == "deleted"}[0]
            stock_hi_conc = Item.where(sample: Sample.find(COR_SAMPLE), object_type_id: INDUCER_STOCK_30mM_CONTAINER).reject{|i| i.location == "deleted"}[0]
            stock_med_conc = Item.where(sample: Sample.find(COR_SAMPLE), object_type_id: INDUCER_STOCK_5mM_CONTAINER).reject{|i| i.location == "deleted"}[0]
            inducer_box_location =  "TI1, located in the second -20C freezer, second shelf from the top"
            inducer_name = "Coronatine"
            end_concs = [0,0.1,0.25,0.5,1,2, 2.5,5,7.5,15]
            stock_vol = [0,0.2,0.5,1,2,4,5,10,5,10]
            wells = [1,2,3,4,5,6,7,8,9,10]
            stock = [stock_lo_conc.id, stock_lo_conc.id, stock_lo_conc.id, stock_lo_conc.id, stock_lo_conc.id, stock_lo_conc.id, stock_lo_conc.id,stock_lo_conc.id,stock_hi_conc.id,stock_hi_conc.id]
            solvent_vol = stock_vol.map{ |i| 10 - i }
            solvent_vol = solvent_vol.map{ |i| (i * end_vol).round(1)}
            stock_vol = stock_vol.map{ |i| (i * end_vol).round(1)}
        end
        
        inducer_series_set_up_table = Table.new(
                  a: "Well number",
                  b: "Solvent item",
                  c: "Solvent volume (µl)",
                  d: "Inducer Stock item",
                  e: "Volume of inducer stock (µl)"
                )
             n = 0
             
        # show do 
        #     title "End vol"
        #     note "#{end_vol}"
        #     note "Strain number #{strain_no}"
        #     note "Calculation #{(strain_no/10).to_f}"
        # end
        
        show do 
            title "Retrieve #{inducer_name} and solvent stocks"
            if inducer == "be"
                note " Beta-estradiol can be carcinogenic in humans in miligram amounts. Avoid skin exposure"
            elsif inducer == "coronatine"
                note "Coronatine is dissolved in DMSO which is irritating to the skin. Wear gloves."
            end
            note "#{inducer_name} stock-box location: #{inducer_box_location}" 
            note "Take a 1.5 mL tube rack over to #{stock_hi_conc.location[0..3]}"
            note "Take the following items from the freezer:"
            check "#{stock_no_conc.id} from #{stock_hi_conc.location}"
            check "#{stock_hi_conc.id} from #{stock_hi_conc.location}"
            if stock_mid_conc
                check "#{stock_mid_conc.id} from #{stock_mid_conc.location}"
            end
            check "#{stock_lo_conc.id} from #{stock_lo_conc.location}"
            note "Return to your workstation"
        end
       
        wells.length.times do
            inducer_series_set_up_table.a(wells[n]).b(stock_no_conc.id).c(solvent_vol[n]).d(stock[n]).e(stock_vol[n]).append
            n = n + 1
        end
        
        show do 
            title "Tips for setting up an accurate dilution series"
            note "Use a fresh pipette tip for every transfer. The small volumes that cling to the plastic of the pipette tip can alter the end concentrations"
            note "Always hold your pipette vertically when taking up liquid, this ensures maximum accuracy. You can angle the pipette as you dispense"
        end
        
        show do 
            title "Prepare the following dilution series"
            check "Take a stripwell and label #{inducer_name}"
            table inducer_series_set_up_table
        end
        
        show do 
            title "Place stripwell aside"
            check "Seal stripwell with lid"
            check "Vortex briefly to ensure mix"
            note "Put a lid on the stripwell and place to the side"
        end
        
        show do 
            title "Return inducer stocks"
            note "Take a 1.5 mL tube rack over to #{stock_hi_conc.location[0..3]}"
            note "Return the following items from the freezer:"
                check "#{stock_hi_conc.id} from #{stock_hi_conc.location}"
                if stock_mid_conc
                    check "#{stock_mid_conc.id} from #{stock_mid_conc.location}"
                end
                check "#{stock_lo_conc.id} from #{stock_lo_conc.location}"
            note "Return to your workstation"
        end
        
        concs = Hash[wells.zip(end_concs)]
        
        return concs
    end
    
#     def measure_cell_densities(items, plate)
        
#         show do
#             title "Retrieve Assay Plate"
#             note "Retrieve a #{plate[:object_type_name]}, from #{plate[:location]}"
#             note "The plate should be labelled 'cell densities'"
#             note "Remove the plastic seal and place to the side"
#         end
        
#         wells = show do 
#             title "Add strains to wells"
#             note "Vortex each overnight and then add 100 µL to a well of the assay plate"
#             note "Note down the well used for each strain:"
#             items.each do |i|
#                 check "100 µL of Yeast Overnight Suspension #{i}"
#                 get "text", var: "well_#{i}", label: "Well for #{i}", default: "A1"
#             end
#         end
        
#         show do
#             title "Take plate to flow cytometer"
#             note "Select wells #{wells.values}"
#             note "Autorun"
#         end
        
#         measurements = show do 
#             title "Measure densities in the cytometer"
#             note "Note down the events per µl for each measured well"
#             items.each do |i,w|
#                 get "number", var: "well_#{i}", label: "Events per µl in well #{i}", default: 500
#             end
#         end
        
#         densities = []
#         items.each do |i|
#             densities.push(measurements["well_#{i}".to_sym])
#         end
        
#         show do
#             title "Return assay plate"
#             note "Replace the seal on the assay plate"
#             note "Mark the used wells with an X"
#             note "If the plate is almost completely used discard and take a new one from the draw under the cytometer"
#         end
        
#         return densities
#     end
    
# end

# module Plates
    
#     #Will only work with a total strain_array * replicates * concs of less than 96
#     #Currently only works with beta-estradiol as an inducer
    
#     def inducer_plate_set_up(strain_ids, strain_samples, inducer)
        
#         if inducer == "be"
#             concs = [0, 0.05, 0.1, 0.5, 1, 2, 5, 10, 50, 100]
#             concs_extended = concs.flatten * strain_ids.length
#             inducer = concs_extended.map{ |c| "#{c} nM Beta-estradiol"}
#         elsif inducer == "coronatine"
#             concs = [0,0.1,0.25,0.5,1,2, 2.5,5,7.5,15]
#             concs_extended = concs.flatten * strain_ids.length
#             inducer = concs_extended.map{ |c| "#{c} uM Coronatine"}
#         end
            
#         strain_ids = strain_ids.map{|s| [s] * concs.length}.flatten 
#         strain_samples = strain_samples.map{|s| [s] * concs.length}.flatten 
        
#         rows = ["A", "B", "C", "D", "E", "F", "G", "H"]
#         columns = (1..10).to_a
        
#         plate = []
#         rows.each do |r|
#             columns.each do |c|
#                 plate.push("#{r}#{c}")
#             end
#         end
        
#         plate_set_up = []
            
        
#         plate.each do |w|
#             well_contents = {}
#             well_contents[:well] = w
#             well_contents[:item] = strain_ids[plate.index(w)]
#             well_contents[:sample] = strain_samples[plate.index(w)]
#             well_contents[:inducer] = inducer[plate.index(w)]
#             plate_set_up.push(well_contents)
#         end
        
#         return plate_set_up
        
#     end
    
end