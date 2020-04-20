# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    operations.retrieve.make
    
    show do
        title "Gather items"
        check "2 Plastic sheets"
        check "Ethanol resistant marker pen"
    end
    
    show do
        title "Lay out leaf discs"
        check "Prepare a sheet of clear plastic divided into #{operations.length} sections"
        check "Using a marker pen write these item numbers into the sections: #{operations.collect{|op| "#{op.input("Leaf discs").item.id}"}.join (",")}"
        note "Ensure that as much of the plant tissue as possible is visible on the sheet"
    end
    
    operations.each do |op|
     results = show do
        title "Characterize the results for #{op.input("Leaf discs").id}"
        note "What is the extent of the stain?"
        select ["Complete", "Partial", "None"], var: "extent_#{op.id}", label: "Extent", default: 0
        note "How intense is the stain?"
        select ["Strong", "Medium", "Light", "None"], var: "intensity_#{op.id}", label: "Intensity", default: 0
    end
    
    op.output("Image").associate :result_extent, results["extent_#{op.id}"]
    op.output("Image").associate :result_intensity, results["intensity_#{op.id}"]
    
    show do 
        title "Take an image that captures the full plant tissue"
        note "Take pictures on your phone or other device till you have one that looks good"
    end
 
    data = show do
        operations.each do |op|
        title "Upload image file"
        upload var: "image_file_#{op.id}"
        end
    end

    operations.each do |op|
        op.output("Image").item.associate :results, data["image_file_#{op.id}"]
    end
    
    show do 
        title "Clean up and discard leaf discs"
        note "Spray 70% ethanol on a paper towel and use it to wipe up all the leaf discs from the plastic sheet"
        note "return the plastic sheet to where you got it from"
    end    
    
    operations.each do |op|
        op.input("Leaf discs").item.mark_as_deleted
        op.input("Leaf discs").item.save
    end
    
  
        
    
   operations.each do |op|
      it = op.outputs("image").item
       it.associate :aim_age, op.plan.get(:aim_age)
       it.associate :aim_pH, op.plan.get(:aim_pH)
       it.associate :incubation_time, op.plan.get(:incubation_time)
       it.associate :plant_age, op.plan.get(:plant_age)
    end
    
    operations.store
    
    return {}
    
  end

end
