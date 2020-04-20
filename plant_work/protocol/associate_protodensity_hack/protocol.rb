#This is to reupload images to item froms the Check proto density(microscope) protocol

class Protocol
    Input = "protoplast_per_ML"
  def main
    operations.make
    
    fixImages

    operations.store

    {}

  end

    def fixImages
    
        operations.each do |op|
            
            proto_tube = op.input(INPUT).item

            show do 
                title "Desitioes are being uploaded"
            end
            
            proto_tube.associate :protoplast_per_ML, op.input(INPUT).value
            
        end
        
end
end