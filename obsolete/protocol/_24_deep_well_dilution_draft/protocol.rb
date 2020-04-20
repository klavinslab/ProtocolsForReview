# Eriberto Lopez 11/16/2017
# eribertolopez3@gmail.com

# Loads necessary libraries from mammlian cell protocols
category = "Tissue Culture Libs"
needs "#{category}/CollectionDisplay"

class Protocol
    
#---------------Constants-&-Libraries----------------#

  include CollectionDisplay
  
  INPUT = "24 Deep Well Plate"
  OUTPUT = "24 Deep Well Plate"
#   CONTAINER = "24 Deep Well Plate"
  CULT_VOL = 4.0
  
#----------------------------------------------------#
  def main

    operations.retrieve.make
    
    # Protocol Info
    intro()
    # Determines how much media will be needed for experiment
    aliquot_media()
    # Dilutes input 24-formatted plates (4x6))
    dilute_plates(INPUT, OUTPUT)
    # TODO: Create Harvesting module, then call module here depending on what type of harvesting needs to be done
    finishing_up() 
    operations.each {|op| op.input(INPUT).collection.mark_as_deleted } 
    operations.store
    return {}
    
  end # main
  
  
#   # TODO: Create function that will take media_vol and determine which tube to use.
#   # Or we could do with out it and ask tech to aliquot media into multichannel resevior
#   def falcon (vol)
#       if vol < 50
#           return 1
#       else
#          tubes = vol / 50
#          if vol % 50 >  1
#              return tubes + 1
#          end
#      end
#   end

  # Protocol Info
  def intro()
      show do
          title "Protocol Information"
        
          note "This protocol is used to dilute previously cultured overnight yeast suspensions 1:1000 in a 24-deep well plate format."
      end
  end
  
  # Calculates the amount of media needed for experiment
  def aliquot_media()
        media_vol = (operations.length * CULT_VOL * 1.03).round()
        # Aliquot media needed for experiment
        show do
          title "Media preparation in media bay"

          media_bottle = "800 mL SC liquid media" # Item.find_by_object_type_id(ObjectType.find_by_name("800 mL SC liquid (sterile)").id)
          check "Slowly shake a <b>#{media_bottle}</b> bottle to make sure it is still sterile!!!"
          check "You will need #{media_vol}mLs for this experiment." #"Aliquot #{media_vol}mLs of SC media in #{falcon(media_vol)} 50mL Falcon tubes."
        end
  end
    
  # Displays 24 well plate and fills with media and inoculates with incoming plate strain (operations) 
  def dilute_plates(input, output)
      
        # Creates a hash that groups all the running operations to the input collection id it corresponds to
        grpd_by_in_coll = operations.running.group_by { |op| op.input(input).collection.id }
        
        # takes output collection hash and iterates through it filling each outputPlate with media and cells
        operations.output_collections[output].each do |outputPlate|   
          
          # Load 24 well plate with media in respective wells   
          load_media(outputPlate)
        
          # Diluting input 24-deep well plate to 1:1000 output plate    
          transfer_cults(grpd_by_in_coll, outputPlate)
        
          # Move overnights to 30 C shaker incubator
          outputPlate.location = "Small 30 C shaker incubator"
          outputPlate.save
      end 
  end
  
  # Displays 24 well format to inform which wells to fill with liquid growth media 
  def load_media(collection)
      show do  
          title "Filling new 24-Deep Well Item ##{collection.id}"  
          
        #   note "Use the appropriate method to dispense your aliquoted media." 
          check "Grab a sterile 24-deep well plate and label with the Item ID #<b>#{collection.id}</b>." 
          check "Label Rows A-D and Columns 1-6, for orientation and reference."
          note "Using a serilogical pipette, transfer appropriate volume of media to the following wells." 
          # CollectionDisplay library
          table highlight_non_empty(collection) { |r,c| "#{CULT_VOL.to_s} mL" } 
        end  
  end
  
  # Diluting input 24-deep well plate to 1:1000 output plate 
  def transfer_cults(grpd_by_in_coll, outputPlate)
      
        # Grabs the first element of the input collection id array and takes the first index of that element
        inputPlateID = grpd_by_in_coll.shift.first
        
        show do
          title "Diluting 24-deep well Item ##{inputPlateID} => 1:1000" 
              
          note "Observe from underneath to check for suspension of cultures."
          note "Next, Using a 12 channel 10ul pipette, set pipetter to 2ul."
          note "With 2 pipette tips in each well, transfer 4ul of culture to the appropriate wells in item #<b>#{outputPlate.id}</b> as shown in the table below."
        #   note "Dilute into the corresponding wells found in Item #<b>#{outputPlate.id}</b> that have been filled with growth media."
          # CollectionDisplay library
          table highlight_non_empty(outputPlate) { |r,c| "#{CULT_VOL.to_s}\n uL" }
        end
  end
  
  def finishing_up()
      plates_to_clean = operations.map {|op| op.input(INPUT).collection.id}.uniq
      
      show do 
          title "Finishing Up..."
         
          note "Before finishing up, prepare 24 Deep Well plate(s) for autoclaving."
          plates_to_clean.each {|plt| note "Clean item #{plt}"} 
          note "Place plate(s) at cleaning station and soak with bleach solution."
      end
  end
  
end # Class