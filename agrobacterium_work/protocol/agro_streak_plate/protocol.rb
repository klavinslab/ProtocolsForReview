class Protocol
  

def main
    
    operations.make 
    
    selections = operations.map { |op| op.input("Stock").sample.properties["Agro Selection"] }
    gent = selections.count "Gentamycin"
    kan = selections.count "Kanamycin"
    spec = selections.count "Spectinomycin"
    
    show do 
        note "#{gent},#{kan}, #{spec}"
    end
    
    plate_batches = Collection.where(object_type_id: ObjectType.find_by_name("Agar Plate Batch").id)
    gent_plates = plate_batches.find {|batch| batch.matrix.flatten.include? Sample.find_by_name("YEB Gent").id}
    kan_plates = plate_batches.find {|batch| batch.matrix.flatten.include? Sample.find_by_name("YEB Gent + Kan").id}
    spec_plates = plate_batches.find {|batch| batch.matrix.flatten.include? Sample.find_by_name("YEB Gent + Spec").id}
        
#     if gent > 0 
#         gent_plates = find(:collection, { sample: { name: "YEB Gent" }, object_type: { name: "Agar Plate Batch" } } ) 
#     end
#     if kan > 0 
#         kan_plates = find(:collection, { sample: { name: "YEB Gent + Kan" }, object_type: { name: "Agar Plate Batch" } } ) 
#     end
#   if spec > 0 
#       spec_plates = find(:collection, { sample: { name: "YEB Gent + Spec" }, object_type: { name: "Agar Plate Batch" } } ) 
#     end
        
    show do
        title "Take plates from the plant lab fridge"
        if gent > 0
            check "Take #{gent} #{"plate".pluralize(gent)} from #{gent_plates.id} located in #{gent_plates.location}"
            Sample.find_by_name("YEB Gent").id
        end
        if kan > 0
            check "Take #{kan} #{"plate".pluralize(kan)} from #{kan_plates.id} located in #{kan_plates.location}"
           kan_plates.subtract_one Sample.find_by_name("YEB Gent + Kan").id
        end 
        if spec > 0
            check "Take #{spec} #{"plate".pluralize(spec)} from #{spec_plates.id} located in #{spec_plates.location}"
            spec_plates.subtract_one Sample.find_by_name("YEB Gent + Spec").id
        end
    end
   
    
    show do
        title "Label plates"
        operations.each do |op|
            check "Take a YEB #{op.input("Stock").sample.properties["Agro Selection"]} plate"
            check "Label #{op.output("Plate").item.id} + your initials + #{DateTime.now.month}/#{DateTime.now.day}"
        end
    end
        
    
    show do
          title "Inoculation from glycerol stock in M80 area"
          check "Go to M80 area, clean out the pipette tip waste box, clean any mess that remains there."
          check "Put on new gloves, and check that there is a box of 200µl pipette tips available"
          check "Grab the plates and go to M80 area to perform inoculation steps in the next pages."
    end

    operations.each do |op|
        
        show do
            title "Retrieve stock"
            note "Retrive stock #{op.input("Stock").item.id} from #{op.input("Stock").item.location}"
        end
        
        
        show do 
            title "Streak out on plate"
            note "Streak out stock #{op.input("Stock").item.id} onto plate #{op.output("Plate").item.id}"
            note "Streak out with a 200 µl pipette tip. Run the tip back and forth across the whole surface of the plate to get an even spread of bacteria"
        end
        
        show do
            title "Return stock"
            note "Return stock #{op.input("Stock").item.id} to #{op.input("Stock").item.location}"
        end
        
    end
    
    show do
        check "Place #{"plate".pluralize(operations.length)} upside down in 30 C incubator"
    end
  
    
    operations.each do |op|
        op.output("Plate").item.location = "30 C incubator"
        op.output("Plate").item.save
    end

    
    return {}
    
  end

end
