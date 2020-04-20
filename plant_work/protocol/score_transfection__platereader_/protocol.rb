needs "Tissue Culture Libs/CollectionDisplay"

INPUT = "Protos"
TRANSFECTION_TIME_KEY = "transfection_time"
TECH_REPS = 3
WELL_VOL = 100

class Protocol
    
    include CollectionDisplay

  def main

    operations.retrieve
    
    calculate_transfection_time
    
    plate = prepare_plate

    score_transfection(plate)

    operations.store

    {}

  end
  
  def calculate_transfection_time
      
        operations.each do |op|
          
          seconds_per_hour = 60*60
          item_age = Time.zone.now - op.input(INPUT).item.created_at 
          rounded_item_age = item_age.round(1)
          op.associate TRANSFECTION_TIME_KEY.to_sym, rounded_item_age
          
        end          
  end
  
    def prepare_plate
        
        plate = Collection.new_collection("96 Well Flat Bottom (black)")
        
            plate_rows = ["A","B","C","D", "E", "F", "G", "H"]
            plate_columns = ["01","02","03","04","05","06","07","08","09","10","11","12"]
            plate_wells = []
            plate_rows.each do |r|
                plate_columns.each do |c|
                    plate_wells.push("#{r}#{c}")
                end
            end
      
        n = 0
        operations.each do |op|
            
            op.associate :plate_id, plate.id
            
            ##Add samples to plate
            sample_ids = [op.input(INPUT).sample.id] * TECH_REPS
            plate.add_samples(sample_ids)
            
            ## Associate the input item ids, transfection plasmid ids as part associations
            
            item_id = op.input(INPUT).item.id
            incubation_hrs = ((Time.zone.now - op.input(INPUT).item.created_at) / (60*60)).round(2)
            if debug then incubation_hrs = 17 end
            
            sample_parts = plate.select{|p| p == op.input(INPUT).sample.id}
            
            sample_parts.each do |p| #Note each part has a row and column position, accessed as part[0] and part[1]
              
               #Associate item id of transfection mix
                unless plate.get_part_data(:item_id, p[0], p[1]) #This unless clause is necessary to avoid parts with the same sample ID having their data overwritten. 
                    plate.set_part_data(:item_id, p[0], p[1], item_id)
                end
                
                #Associate transfection incubation time
                unless plate.get_part_data(:incubation_hrs, p[0], p[1])
                    plate.set_part_data(:incubation_hrs, p[0], p[1], incubation_hrs)
                end
                
                #Associate plate well
                unless plate.get_part_data(:plate_well, p[0], p[1])
                    plate.set_part_data(:plate_well, p[0], p[1], plate_wells[n])
                    n = n + 1
                end

            end
            
        end
        
        rcx_list = []
        plate.get_non_empty.each do |r,c|
            rcx_list.push([r,c, plate.get_part_data(:item_id, r, c)])
        end
        
        show do 
            title "Set up plate"
            note "#{WELL_VOL} uL of transfection mix in the relevant wells as follows:"
            table highlight_rcx plate, rcx_list
        end
        
      return plate
      
    end
  
    def score_transfection(plate)
        
        show do 
            title "Run plate in plate reader"
            note "Measure plate #{plate.id} with the following scans, 10 nm interval for ranges"
            note "Measure absorbance - Phososytem II (low) - 420-480 nM with 550 nM as reference"
            upload var: :photosystem_II_420_480_vs_550
            note "Measure absorbance - Phososytem II (high) - 650-700 nM with 550 nM as reference"
            upload var: :photosystem_II__480_vs_550
            note "Measure fluoresence - Venus - Excitation 480-530, Emission 520-580"
            upload var: :venus_Ex480_530_Em520_580
        end
        
    end
    

end
