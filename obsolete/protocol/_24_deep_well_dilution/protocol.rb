# Eriberto Lopez 8/28/2017
# eribertolopez3@gmail.com


# Loads necessary libraries from mammlian cell protocols
category = "Tissue Culture Libs"
needs "#{category}/CollectionDisplay"



class Protocol
    
#---------------Constants-&-Libraries----------------#

  include CollectionDisplay
  INPUT = "96_deep_well"
  OUTPUT = "96_deep_well"
  CONTAINER = "96-well TC Dish"
  
#----------------------------------------------------#
  def main

    operations.retrieve.make
    
    # tin  = operations.io_table "input"
    # tout = operations.io_table "output"
    
    # show do 
    #   title "Input Table"
    #   table tin.all.render
    # end
    
    # Protocol Info
    intro()
    
    # Determines how much media will be needed for experiment
    aliquot_media()
    
    # Dilutes input 96-formatted plates (8x12)
    dilute_plates(INPUT, OUTPUT)
    
    # show do 
    #   title "Output Table"
    #   table tout.all.render
    # end
    
    operations.store
    return {}
    
  end # main
  
  
  # TODO: Create function that will take media_vol and determine which tube to use.
  # Or we could do with out it and ask tech to aliquot media into multichannel resevior
  def falcon (vol)
      if vol < 50
          return 1
      else
         tubes = vol / 50
         if vol % 50 >  1
             return tubes + 1
         end
     end
  end

  # Protocol Info
  def intro()
      show do
          title "Protocol Information"
        
          note "This protocol is used to dilute previously cultured overnight yeast suspensions 1:1000 in a 96-deep well plate format."
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
    
  # Displays 96 well plate and fills with media and inoculates with incoming plate strain (operations) 
  def dilute_plates(input, output)
      
        # Creates a hash that groups all the running operations to the input collection id it corresponds to
        grouped_by_collection = operations.running.group_by { |op| op.input(input).collection.id }
        
        # takes output container/collection and iterates through it filling it with media and colonies
        operations.output_collections[output].each do |outputPlate|   
            
          # Load 96 well plate with media in respective wells   
          load_media(outputPlate)
        
          # Diluting input 96-deep well plate to 1:1000 output plate    
          transfer_cults(grouped_by_collection, outputPlate)
        
          # Move overnights to 30 C shaker incubator
          outputPlate.location = "30 C shaker incubator"
          outputPlate.save
      end 
  end
  
  # Displays 96 well format to inform which wells to fill with liquid growth media 
  def load_media(outputPlate)
      show do  
          title "Filling new 96-deep well Item ##{outputPlate.id}"  
          
          note "In a clean & sterile multichannel reservoir, pour aliquoted media." 
          check "Grab a new 96-deep well plate and label with the Item ID ##{outputPlate.id}."   
          note "Using a multichannel P1000 transfer 999uL of media to the following wells."  
          # CollectionDisplay library
          table highlight_non_empty(outputPlate) { |r,c| "999uL" } 
        end  
  end
  
  # Diluting input 96-deep well plate to 1:1000 output plate 
  def transfer_cults(grouped_by_collection, outputPlate)
      show do
          # Removes the first object and takes the first index of that object
          inputPlateID = grouped_by_collection.shift.first

          title "Diluting 96-deep well Item ##{inputPlateID} => 1:1000" 
              
          note "Before diluting, place Item ##{inputPlateID} on bench top vortexer at a setting of 6 and pulse carefully."
          note "Observe from underneath to check for resuspension of cultures."
          note "Next, using a multichannel pipette take the following volume from the wells shown below from Item ##{inputPlateID}."
          # CollectionDisplay library
          table highlight_non_empty(outputPlate) { |r,c| "1.0uL" } 
          note "Dilute into the corresponding wells found in Item ##{outputPlate.id} that have been filled with growth media."
        end 
  end
  
end # Class