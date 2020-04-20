# By: Eriberto Lopez 12/01/2017
# eribertolopez3@gmail.com

# Loads necessary libraries from mammlian cell protocols
category = "Tissue Culture Libs"
needs "#{category}/CollectionDisplay"

# Used for printing out objects for debugging purposes
needs "Standard Libs/Debug"

class Protocol

#----------Constants-&-Libraries--------------------#
  include Debug
  include CollectionDisplay

  INPUT = "Yeast Cells"
  OUTPUT = "24 Deep Well Plate"
  CULT_VOL = 4.0
#----------------------------------------------------#

  def main
    operations.make
    
    # A way to retrieve all items except Yeast Glycerol Stock
    operations.retrieve(interactive: false)
    item_array = []
    operations.each do |op|
        if op.input(INPUT).object_type.name != "Yeast Glycerol Stock"
            item_array.push(op.input(INPUT).item)
        end
    end
    item_array.uniq
    take item_array, interactive: true
    
    intro()
    
    # Fill 24 Well plate with media
    aliquot_media()
    
    # Start cultures in 24 Well format
    inoculate_plates(OUTPUT, INPUT)
    
    yeast_plates = []
    operations.each do |op|
        if op.input(INPUT).object_type.name == "Yeast Plate"
            yeast_plates.push(op.input(INPUT).collection)
        end
    end
    
    if (!yeast_plates.nil?)
        show do 
            title "Discard Yeast Plate(s)"
            
            yeast_plates.each {|plate| check "Discard item #{plate}"} 
            
        end
    end
    
    yeast_plates.each {|collection| collection.mark_as_deleted}
    operations.store 
    return {}
  end


  def intro()
      # Protocol Info
      show do
          title "Protocol Information"

          note "This protocol is used to prepare 4 mL overnight yeast suspensions in a 24-deep well plate format."
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
    
  # Displays 96 well plate and fills with media and inoculates with incoming plate strain (operations)
  def inoculate_plates(output, input)

        # takes output collection hash and iterates through it filling it with media and colonies
        operations.output_collections[output].each do |plate|

          # Load 24 well plate with media in respective wells
          show do
              title "Filling 24-Deep Well Plate ##{plate.id}"

              check "Grab a sterile 24-Deep Well Plate and label with Item #<b>#{plate.id}</b>."
              check "Label Rows A-D and Columns 1-6, for orientation and reference."
              note "Using a serilogical pipette, transfer appropriate volume of media to the following wells."

              # CollectionDisplay library
              table highlight_non_empty(plate) { |r,c| "#{CULT_VOL} mL" }
          end

          # Inoculating 24-deep well plate with single colonies
          show do
              title "Inoculating 24-Deep Well Plate ##{plate.id}"
              
              note "Follow the table to inoculate the correct well."
            #   note "Use the appropriate sterile techniques to inoculate #<b>#{plate.id}</b>."
              note "Using a 1000ul tip on a pipette take a scoop from the yeast patch."
              note "Inoculate yeast into respective well and pipette to mix throughly."
              
              # Displays sample ids onto respective inoculation well
              table highlight_non_empty(plate) { |r,c| item_id(input, output, r, c) }
              check "After wells have been inoculated cover with a breathable seal to prevent contamination."
          end
          
          
          # Move plate to 30 C shaker incubator
          plate.location = "Small 30C incubator on shaker @ 800rpm"
          plate.save
      end
  end

  # uses indicies of the collection made (4x6) to fill with the sample id of the plate used in the operation
  def item_id(input, output, row, col)
        op = operations.find {|op| op.output(output).row == row && op.output(output).column == col}
        
        container = op.input(input).object_type.name 
        plate_section = op.input(input).column.to_i + 1
        
        case container 
        when "Yeast Plate"
            return "#{op.input(input).item.id}" #.#{plate_section}"
        when "Yeast Glycerol Stock"
            return "#{op.input(input).item.location}\n#{op.input(input).item.id}"
        else
            return "#{op.input(input).item.id}"
        end
    end

end # class 
