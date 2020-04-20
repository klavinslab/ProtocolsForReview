

class Protocol
  
  GLYCEROL_PER_WELL = 100
  CULTURE_PER_WELL = 100
  
  def main

    operations.retrieve
    operations.make

    operations.each do |op|
        op.outputs.each do |out|
            transference_paperwork(op.input("Culture Plate").collection, out.collection)
        end
    end
    
    
    show do
      title "Label Plates"
      note "Grab #{operations.size} 96 well PCR plates"
      note "Label new plates as #{operations.map {|op| op.outputs }.flatten.map { |output| output.collection.id}.to_sentence}."
    end

    show do
        title "Prepare Glycerol Stock Plate(s)"
        note "Pour #{GLYCEROL_PER_WELL * operations.size * 3 + (GLYCEROL_PER_WELL * operations.size * 3 / 10.0)} uL of 50% Glycerol into a multichannel resevoir."
        note "Using an 8-lane multichannel pipette and the filled resevoir:"
        operations.map {|op| op.outputs}.flatten.map { |output| output.collection.id}.each do |plateid|
            check "Transfer #{GLYCEROL_PER_WELL} uL of 50% glycerol into each well of plate #{plateid}."
        end
    end
    
    operations.each do |op|
        show do
            title "Transfer Culture From Plate #{op.input("Culture Plate").collection.id}"
            note "Use an 8-lane multichannel pipette to transfer #{CULTURE_PER_WELL} uL of culture from every well of plate #{op.input("Culture Plate").collection.id} into the wells with the same position on plates #{op.outputs.map {|output| output.collection.id}.to_sentence }."
            warning "Ensure that the position of cultures on the output plates match the position on the input plate."
        end
    end

    operations.store

    {}

  end

end
