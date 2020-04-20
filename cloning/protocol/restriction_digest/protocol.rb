#Abe/Garrett 8-12-2017
#Edited by Garrett 8-13-17
#edited by ayesha 5-3-18 -- goodness, gracious, me, oh my; time seems to positively fly

needs "Cloning Libs/Cloning"

class Protocol

    include Cloning
      
      QUANTITY_OF_DNA = 4000 #in ng
      VOL_OF_ENZYME = 1 #in uL
      VOL_OF_BUFFER = 4 #in uL
      TOTAL_VOL_RXN = 40 #in uL
      INCUBATION_TEMP = "37 C"
      INCUBATION_TIME = 60 #min 
      MIN_CONC = 200 #in ng/uL

    def main
      buffer = Sample.find_by_name("Cut Smart").in("Enzyme Buffer Stock").first
      take [buffer], interactive: true, method: "boxes"
      operations.retrieve only: ["Plasmid"]
      check_concentration operations, "Plasmid"
      debug = true
      if debug 
        operations.each do |op| 
          op.input("Plasmid").item.associate :concentration, 400
        end
      end

      operations.each do |op|
          stock = op.input("Plasmid").item
          enzymes = op.input_array("Enzymes").items
          # op.temporary[:enzyme_ids] = []
          # op.input_array("Enzymes").items.each  { |e| op.temporary[:enzyme_ids].push e.id}
          # NOTE FOR FUTURE REFERENCE: :enzyme_ids stuff could be written more simply:
          #   op.temporary[:enzyme_ids] = op.input_array("Enzymes").items.map { |e| e.id }
          if stock.get(:concentration) && stock.get(:concentration).to_f > 0 && stock.get(:concentration).to_f > 333
            stock_vol = QUANTITY_OF_DNA / stock.get(:concentration).to_f.round(1)
            op.temporary[:stock_vol] = stock_vol
            op.temporary[:water_vol] = [(TOTAL_VOL_RXN - stock_vol - VOL_OF_BUFFER - VOL_OF_ENZYME * enzymes.length).to_f.round(1), 0].max
          else
            op.error :concenration, "The plasmid stock either has too low a concentration or doesn't have a concentration associated with it."
          end
      end      
        
      if !operations.running.blank?  
        # get ice block
        show do
            title "Keep enzymes on ice block"
              
            warning "Grab an ice block, and place the enzymes on it while performing the following step!"
        end
          
        operations.retrieve only: ["Enzymes"]
        operations.make
        
        # get stripwells
        show do
            title "Grab stripwell(s) for restriction digest"
            
            operations.output_collections["Digest"].each do |sw|
                check "Grab a stripwell with #{sw.num_samples} wells, and label it #{sw.id}."
            end
        end
          
        # calculate volumes and build tmp array of enzyme ids
        
        # old calculations (for posterity)
        # templates_with_volume = templates.map.with_index { |t, idx| "#{template_vols[idx]} L of #{t.id}" }
        # buffer_with_volume = templates.map { |t| "1 L of #{buffer.id}" }
        # enzymes_with_volume = enzymes.map { |es| "0.5 L#{es.length > 1 ? " each" : ""} of #{es.map { |e| "#{e.id}" }.join(" and ") }" }
        # water_with_volume = water_vols.map { |wv| "#{wv} L" }
        
        # add water to wells
        show do
            title "Load Stripwell with Molecular Grade Water"
            
            table operations.start_table
                .output_collection("Digest", heading: "Stripwell")
                .custom_column(heading: "Well") { |op| op.output("Digest").column + 1 } # this gives us wells that start at 1, rather than 0, like output_column gives us
                .custom_column(heading: "Molecular Grade Water (uL)", checkable: true) { |op| op.temporary[:water_vol].to_f.round(1) }
            .end_table
            warn = check_p2 operations, :water_vol
            note "#{warn}"
        end
        
        # add smart buffer to wells
        # show do
        #     title "Load Stripwell with Cut Smart Buffer"
        #     operations.each do |op|
        #         check "Add 1L of Buffer to well #{op.output("Digest").column} of Stripwell #{op.output("Digest").collection.id}."
        #     end
        # end
        # I think this version cuts down on redundancy
        show do
            title "Load Stripwell with Cut Smart Buffer"
            
            note "Add #{VOL_OF_BUFFER}uL of Buffer to the following stripwell(s):"
            operations.output_collections["Digest"].each do |sw|
                check "Stripwell #{sw.id}, wells 1-#{sw.num_samples}"
            end
        end
        
        # add enzymes to wells
        show do
            title "Load Stripwell with Enzymes"
            
            note "Load wells with #{VOL_OF_ENZYME} uL of each specified enzyme"
            
            table operations.start_table
                .output_collection("Digest", heading: "Stripwell")
                .custom_column(heading: "Well") { |op| op.output("Digest").column + 1 }
                .custom_column(heading: "Enzymes (add #{VOL_OF_ENZYME} uL of each)", checkable: true) { |op| op.input_array("Enzymes").items.map { |e| e.id }.to_sentence } # .to_sentence is neat!
            .end_table
        end
        
        # add plasmid stock to wells
        show do
          title "Load Stripwell with Template"
            
          table operations.start_table
              .output_collection("Digest", heading: "Stripwell")
              .custom_column(heading: "Well") { |op| op.output("Digest").column + 1 }
              .input_item("Plasmid")
              .custom_column(heading: "Volume to add (uL)", checkable: true) { |op| op.temporary[:stock_vol].to_f.round(1) }
          .end_table
          warn = check_p2 operations, :stock_vol 
        warning "#{warn}"
        end
        
        # put away ingredients, and place output stripwells in incubator
        operations.output_collections["Digest"].each { |c| c.move "#{INCUBATION_TEMP} standing incubator"}
        operations.store io: "input", interactive: true, method: "boxes"
        release [buffer], interactive: true, method: "boxes"
        release operations.output_collections["Digest"], interactive: true
        
        # start incubation timer
        show do
          title "Start incubation timer"
          
          check "<a href='https://www.google.com/search?q=one+hour+timer&oq=#{INCUBATION_TIME}+minute+timer&aqs=chrome..69i57j69i60j69i65l2j69i60l2.1258j0j9&sourceid=chrome&ie=UTF-8' target='_blank'>Click here</a> to start a #{INCUBATION_TIME} minute timer."
          note "After timer finishes, go on to the next steps."
        end
        
        #grab stripwells back from incubator, and transfer to fridge
        take operations.output_collections["Digest"], interactive: true
        operations.output_collections["Digest"].each { |c| c.move  "R4 (beneath the DI dispensers)" }
        operations.store io: "output", interactive: true
      end  

      return {}
    end    
    # displays warning to use P2 pipette if necessary, for use in adding water and plasmid stock
    def check_p2 operations, vol
      operations.each do |op| 
          if op.temporary[vol] < 0.4
              return "There are volumes smaller than 0.4; please use the P2!"
          end
      end
      ""
    end
end