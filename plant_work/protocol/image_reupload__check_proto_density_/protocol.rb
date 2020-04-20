#This is to reupload images to item froms the Check proto density(microscope) protocol

class Protocol
INPUT = "Digesting Cells"
  def main
    operations.make
    
    fixImages

    operations.store

    {}

  end

    def fixImages
    
        operations.each do |op|
            
            proto_tube = op.input(INPUT).item
            measurements = 6
            
            densities = show do 
                title "Reupload Correct Images"
                note "Upload the #{measurements} images for #{op.input(INPUT).item.id}"
                upload var: :images
            end
            
            proto_tube.associate :microscope_images, densities[:images]
            
        end
        
end
end