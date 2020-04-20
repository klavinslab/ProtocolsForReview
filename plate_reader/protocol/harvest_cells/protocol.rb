

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!
needs 'YG_Harmonization/BiotekPlateReaderCalibration'
needs "Standard Libs/Debug"
class Protocol
    
  include BiotekPlateReaderCalibration
  include Debug
  
  AMOUNT_TO_HARVEST = 1 # OD amount
  WELL_VOLUME = 1.00 #ml  #make hash for well types and volumes
  def main
  
    operations.retrieve.make
    # DOING FOR ONE OPERATION RIGHT NOW
    
    # get the file
    # get the matrix representation of a 96 well plate, but we want a 24 well plate representation
    # find formula for this conversion
    # get the concentration at each index
    # do M1V1 = M2V2 formula and solve for V1
    # Tell the tech to get this much and put into screwcap tube
    # make the tube
    
    # Thoughts: The input 24 or 96 deepwell plate will have a .csv file associated with it.
    #           This csv file should have the same number of entries as the deepwell plate has.
    #        
    
    operations.running.each do |op|
      # NEED TO FIX THIS! GET THE CORRECT FILE
      concentration_csv = Upload.find(11187)
      log_info 'concenctraiont csv'.upcase, concentration_csv
      raise concentration_csv.inspect
      concentration_matrix = (extract_measurement_matrix_from_csv(concentration_csv)).to_a # return data matrix obj then I turn that into 2-D Array(.to_a)
      
       show do
         note "#{concentration_matrix}"
       end
      
      yeast_collection = Collection.find(op.input("24 Deep Well Plate").item)
      if debug
        yeast_collection = Collection.find(287086)
      end
   
      yeast_collection_valid_index = yeast_collection.get_non_empty
  
      yeast_collection_matrix = yeast_collection.matrix
      
      # ERROR CHECK: SEE IF CSV MATRIX AND COLLECTION HAVE SAME DIMENSIONS
      items = {}
      table_list = []
      yeast_collection_matrix.each_with_index do |row, i|
        # Calculates the letter equivalent of this row index.
        s_rep = i.to_s
        s = s_rep.ord
        s_num = s + 17
        i_letter = s_num.chr
        
        current_row_table = [["Collection ID", "Well", "OD value", "Transfer volume (mL)", "Tube ID"]]
        row.each_with_index do |col, j|
          if(col == -1)
            break
          end
          concentration_string = concentration_matrix[i][j]
          concentration_num = concentration_string.to_f
          
          # formula to calculate how much volume is in an OD
          v1 = ((AMOUNT_TO_HARVEST) / (concentration_num)).round(2)
          
          # only take <= to available volume
          v2 = [v1, WELL_VOLUME].min
          
          sample = Sample.find(yeast_collection_matrix[i][j]) #Sample.where(sample_type_id: sample_type_id).find_by_name(operation_name)
  
          ot = ObjectType.find_by_name("2 mL Screw Cap Tube")
          
          od = (v2/v1).round(2)
          
          item = Item.make({quantity: 1, inuse: 0}, sample: sample, object_type: ot)
          item.associate :collection, yeast_collection.id
          item.associate :row, i
          item.associate :col, j
          item.associate :OD, od
          items[item] = v2
          
          current_row_information = ["#{yeast_collection.id}", "#{i_letter + (j + 1).to_s}", "#{od}", "#{v2}"]
          checkable_item = [item.id].map{|item| {content: item, check: true}}
          current_row_information.concat(checkable_item)
          current_row_table.push(current_row_information)
       
        end
        if current_row_table.length > 1
          table_list.push(current_row_table)
        end
      end
      
      # show do
      #   note "#{table_list}"
      # end
      
      show do
        title "Gather Screwcap tubes"
        
        note "Gather #{items.length} Screw Cap tubes and label them from #{items.keys[0].id} to #{items.keys[(items.length - 1)].id}"
      end
      
      show do
        title "Transfer volumes"
        
        note "In the following slides, transfer the amount in the \"Transfer Volume\" column to the
        corresponding 2mL Screw cap tube."
      end
      
      table_list.each do |row_table|
        show do
          table row_table
        end
      end
      
      show do 
        title "Centrifuge and Remove supernatant"
        
        check "Centrifuge at 1000 (g or rpm) for 5 minutes."
        check "Remove supernatant (aspirate)."
      end
      
      rna_latter_vol = items.length * 0.5
      
      show do
        title "Resuspend cell and centrifuge"
        
        check "Resuspend cell pellet in a 0.5mL of pre-made ice cold 60% Methanol (fixate cells)."
        check "Centrifuge at 1000 (g or rpm) for 5 mins"
        check "While centrifuging prepare RNAlater + 1XPBS solution (RNAlater w/ 1xPBS = 50% RNAlater + 50% PBS for each sample)"
        check "Mix #{rna_latter_vol} mL RNAlatter and #{rna_latter_vol} mL 1xPBS into 50mL falcon tube."
        check "Label tube RNAlater_PBS and date tube."
      end
      
      show do
        title "Resuspend cell and centrifuge"
        
        check "Remove supernatant (aspirate)"
        check "Resuspend cell pellet in 1mL of RNAlater w/ 1XPBS"
        check "Centrifuge at 100(g or rpm) for 5 mins"
        check "Remove supernatant (aspirate)"
      end

      op.input("24 Deep Well Plate").item.mark_as_deleted
      
      items.keys.sort! {|x, y| x.location.split('.')[1..3] <=> y.location.split('.')[1..3]} # Sorts by the box number Fridge.X.X.X
      items_grouped_by_box = items.keys.group_by {|i| i.location.split('.')[1]}
      items_grouped_by_box.each {|box_num, item_arr| # Groups by box then takes by box location
          release item_arr, interactive: true, method: "boxes"
      }
    end
    
    #release(items.keys, interactive: true)  
    operations.store(io: "input", interactive: true, method: "boxes")
    
    

    {}

  end

end
