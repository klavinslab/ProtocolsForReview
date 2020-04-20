class Protocol
    
  def main
    # sort by media
    ops_by_media = Hash.new { |h, k| h[k] = [] }
    operations.each do |op|
      media = "LB"
      op.input("Plasmid").sample.properties["Bacterial Marker"].split('+').each do |m|
          m = "chlor" if m == "chl"
          media = media + " + " + formalize_marker_name(m)
      end
      
      ops_by_media[media] += [op]
    end
    
    ops_by_media.each do |m, ops|
      ops = operations.select { |op| ops.include? op } # make Array into OperationList
      ops.make # .make needs to happen here so that like strains are plated on same media
      
      get_plates_steps ops, m
      
      ops_by_container = Hash.new { |h, k| h[k] = [] }
      ops.each do |op|
          ops_by_container[op.input("Plasmid").object_type] += [op]
      end 
      
      ops_by_container.each do |c, ops|
          ops = operations.select { |op| ops.include? op } # make Array into OperationList
          streak_plate_steps ops, m, c
      end
    end
    
    operations.store
    
    return {}
  end
  
  # This method formalizes marker names to be like Amp, Kan, Chlor.
  def formalize_marker_name marker
    if marker
      marker = marker.delete(' ')
      marker = marker.downcase
      marker = marker[0].upcase + marker[1..marker.length]
    end
    return marker
  end
    
  # TODO: handle empty batches correctly. *after* removing one, 
  #   batch should be checked if empty and deleted automatically if that is the case
  # This method finds batches of Agar Plates and then tells the technician to physically grab those plates.
  def get_plates_steps ops, media
      media = Sample.find_by_name(media)
      
      batch = Collection.where(object_type_id: ObjectType.find_by_name("Agar Plate Batch").id).select { |b| (!b.deleted?) && (b.matrix[0].include? media.id) }.first
      if batch.nil?
        raise "no #{media.name} Agar Plate batches are available for this protocol"
      end
      ops.each do |op|
        if batch.empty?
            batch = Collection.where(object_type_id: ObjectType.find_by_name("Agar Plate Batch").id).select { |b| (!b.deleted?) && (b.matrix[0].include? media.id) }.first
        end

        batch.remove_one
      end

      show do 
        title "Grab plates"
        note "Please grab #{ops.length} #{media.name} plates from plate batch #{batch}"
        note "Label the plates #{ops.map { |op| op.output("Plate").item.id }}"
      end
  end
    
  # This method tells the technician to streak yeast plates.
  def streak_plate_steps ops, media, container
    media = Sample.find_by_name(media)

    ops.retrieve(interactive: false) 

    if container == ObjectType.where(name: "Plasmid Glycerol Stock").first 
      show do
        title "Inoculation from glycerol stock in M80 area"
        check "Go to M80 area, clean out the pipette tip waste box, clean any mess that remains there."
        check "Put on new gloves, and bring a new tip box (green: 10 - 100 µL), a pipettor (10 - 100 µL), and an Eppendorf tube rack to the M80 area."
        check "Grab the plates and go to M80 area to perform inoculation steps in the next pages."
        image "streak_yeast_plate_setup"
      end
    end

    show do 
      title "Streak out on plate"
      note "Streak out the #{container.name} on the plate(s) according to the following table: "
      table ops.start_table
        .input_item("Plasmid", heading: "#{container.name} ID")
        .custom_column(heading: "Location") { |op| op.input("Plasmid").item.location }
        .output_collection("Plate", heading: "#{media.name} Plate ID", checkable: true)
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
    
    ops.each { |op| op.output("Plate").item.move "37 C incubator" }
  end

end