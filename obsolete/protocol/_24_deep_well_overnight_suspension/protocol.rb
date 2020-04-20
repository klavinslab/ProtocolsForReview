# By: Eriberto Lopez 08/22/17
# eribertolopez3@gmail.com 

# Loads necessary libraries from mammlian cell protocols
category = "Tissue Culture Libs"
needs "#{category}/CollectionDisplay"

class Protocol
    
#----------Constants-&-Libraries--------------------#
  include CollectionDisplay
  INPUT = "Plate"
  OUTPUT = "96_deep_well"
  REPLICATES = "Replicates"
  CONTAINER = "96-well TC Dish"
  PARAMETER_1 = "Replicates"
#----------------------------------------------------#
     
  def main 
        
    operations.retrieve.make 
    
    tin  = operations.io_table "input" 
    tout = operations.io_table "output"         

    show do     
      title "Input Table"     
      table tin.all.render       
    end   
    
    intro()
    aliquot_media()
    inoculate_plates(OUTPUT, INPUT)
   
    show do   
      title "Output Table"
      table tout.all.render
    end
    
    operations.store 
    
    return {} 
     
  end

    
    def intro()
        # Protocol Info  
        show do 
            title "Protocol Information"
            
            note "This protocol is used to prepare 1mL overnight yeast suspensions in a 96-deep well plate format."
        end
    end


  #TODO: Create function that will take media_vol and determine which tube to use.
  # Or we could do without it and ask tech to aliquot media into multichannel resevior
  def falcon (vol)
      if vol < 50
          return 1 
      else
         tubes = vol / 50
         if vol % 50 > 0
             return tubes + 1
         end  
     end
  end 
  
  # Calculates the amount of media needed for experiment
  def aliquot_media()
        reps = 1 # operations.collect {|op| op.input(PARAMETER_1).val.to_i} ### Will become a parameter that will allow for replicates flexablity
        media_vol = (operations.length * 1.1 * reps).round()
        
        # Aliquot media needed for experiment
        show do
          title "Media preparation in media bay"
          
          check "Slowly shake the bottle of 800 mL SC liquid (sterile) media to make sure it is still sterile!!!"
          check "Aliquot #{media_vol}mLs of SC media in #{falcon(media_vol)} 50mL Falcon tubes."
        end
    end

  # uses indicies of the collection made (8x12) to fill with the sample id of the plate used in the operation
  def sample_id(input, output, rw, cl)
        return operations.find {|op| op.output(output).row == rw && op.output(output).column == cl}.input(input).item.id
    end
    
  # Displays 96 well plate and fills with media and inoculates with incoming plate strain (operations) 
  def inoculate_plates(output, input)
      
        # takes output container/collection and iterates through it filling it with media and colonies
        operations.output_collections[output].each do |plate|   
        
            # Load 96 well plate with media in respective wells   
          show do  
              title "Filling 96-deep well plate #{plate.id}"  
            
              note "In a clean & sterile multichannel reservoir, pour aliquoted media." 
              check "Grab a new 96-deep well plate label with the id #{plate.id}."   
              note "Using a multichannel P1000 transfer 1mL of media to the following wells."  
           
              # CollectionDisplay library
              table highlight_non_empty(plate) { |r,c| "1.0 mL" } 
          end  
        
          # Inoculating 96-deep well plate with single colonies    
          show do  
              title "Inoculating 96-deep well plate #{plate.id}" 
            
              note "Using a pipette tip pick colony and inoculate yeast into well according the following table." 
              # CollectionDisplay library
              # table display_collection_matrix(plate) # Displays sample ids onto respective inoculation well
              table highlight_non_empty(plate) { |r,c| sample_id(input, output, r, c) } # Displays sample ids onto respective inoculation well
          end 
        
          # Move overnights to 30 C shaker incubator
          plate.location = "30 C shaker incubator"
          plate.save
      end 
  end

   
   
end
