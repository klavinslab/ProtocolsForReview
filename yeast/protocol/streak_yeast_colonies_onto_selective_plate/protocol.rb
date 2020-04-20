class Protocol
    
    def get_plates_steps ops, media
        media = Sample.find_by_name("YPAD")
        
        batch = Collection.where(object_type_id: ObjectType.find_by_name("Agar Plate Batch").id).select { |b| b.matrix[0].include? media.id }.first
        ops.each do |op|

            if !batch 
                batch = Collection.where(object_type_id: ObjectType.find_by_name("Agar Plate Batch").id).select { |b| b.matrix[0].include? media.id }.first
            end
    
            n = batch.num_samples
            r = (n / 10) + 1
            c = n % 10
              
            if c == 0 
                c = 9
                r = r - 1
            end
                
            batch.set r, c, nil
        end

        show do 
            title "Grab plates"
            note "Please grab #{ops.output_collections["Streak Plate"].length} plates from plate batch #{batch}"
            note "Label the plates #{ops.output_collections["Streak Plate"].map { |p| p.id }}"
            note "Divide each plate into four sections and mark each section from 1-4"
        end
    end
    
    def streak_plate_steps ops, media, container
      media = Sample.find_by_name(media)

      ops.retrieve(interactive: false)

      if container == ObjectType.where(name: "Yeast Glycerol Stock").first 
        show do
          title "Inoculation from glycerol stock in M80 area"
          check "Go to M80 area, clean out the pipette tip waste box, clean any mess that remains there."
          check "Put on new gloves, and bring a new tip box (green: 10 - 100 L), a pipettor (10 - 100 L), and an Eppendorf tube rack to the M80 area."
          check "Grab the plates and go to M80 area to perform inoculation steps in the next pages."
          image "streak_yeast_plate_setup"
        end
      end

      show do 
        title "Streak out on plate"
        note "Streak out the #{container.name} on the plate(s) according to the following table: "
        table ops.start_table
              .input_item("Yeast Strain", heading: "#{container.name} ID")
              .output_collection("Streak Plate", heading: "Divided Yeast Plate ID")
              .custom_column(heading: "Section") { |op| op.output("Streak Plate").column + 1 }
              .custom_column(heading: "Location") { |op| op.input("Yeast Strain").item.location }
              .end_table
      end

      show do 
        title "Leave plates on bench"
        note "Leave plates on bench until dried so streaking them out is easier."
      end

      show do 
        title "Streak plates"
        note "After the plates have been dried, streak them out by lightly moving a pipette tip
          back and forth across the agar. Make sure to angle the pipette tip correctly so you 
            don't end up puncturing the agar."
        image "streak_yeast_plate_video"
      end
      
      ops.each { |op| op.output("Streak Plate").item.move "30 C incubator" }
  end


        

  def main
      
    # operations.retrieve(interactive: false)
    
    # sort by media
    ops_by_media = Hash.new { |h, k| h[k] = [] }
    operations.each do |op|
        media = op.input("Yeast Strain").sample.properties["Media"].blank? ? "YPAD" : op.input("Yeast Strain").sample.properties["Media"]
        ops_by_media[media] += [op]
    end
    
    ops_by_media.each do |m, ops|
        ops = operations.select { |op| ops.include? op } # make Array into OperationList
        ops.make # .make needs to happen here so that like strains are plated on same media
        
        get_plates_steps ops, m
        
        ops_by_container = Hash.new { |h, k| h[k] = [] }
        ops.each do |op|
            ops_by_container[op.input("Yeast Strain").object_type] += [op]
        end 
        
        ops_by_container.each do |c, ops|
            ops = operations.select { |op| ops.include? op } # make Array into OperationList
            streak_plate_steps ops, m, c
        end
    end
    
    operations.store
    
    return {}
    
  end

end