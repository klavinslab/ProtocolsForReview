needs "Standard Libs/Debug"
needs "Standard Libs/Feedback"
class Protocol
  include Debug
  include Feedback
  def main
    # list of antibiotic plate for yeast selection
    # ClonNat, NatMX, 25 µL, G418, KanMX, 300 µL, Hygromycin, HygMX, 200 µL, Zeocin, Bleo, 50 µL.
    # Clonat and Bleo insufficient volume to spread plate
    
    # TODO!!
    # NEED TO ADD: 5-FOA 
    # Make all same plate types in one batch instead of showing the same steps again
    
    markers_to_volume = { "clonNat"=>25, "G418"=>300, "Hygro"=>200, "Bleo"=>50 }
    operations.make
    operations.each do |op|
      media = op.output("Plate").sample.name
      antibiotic = ""
      volume = 0
      markers_to_volume.keys.each do |m|
          if media.downcase.include? m.downcase
              antibiotic = m
              volume = markers_to_volume[m]
          end
      end
      if (volume == 0 || antibiotic == "")
        op.error :no_marker, "The media of the output plate must contain one of the following markers: clonNat, G418, Hygro, Bleo"
        op.output("Plate").item.mark_as_deleted
      else
        # Make Antibiotic plates
        make_plates media, antibiotic, op, volume
        
        # Let plates dry
        dry_plates
        
        # Start a timer
        start_timer
        
        op.output("Plate").item.move "Media Bay Fridge"
        
      end
    end
    operations.store
    get_protocol_feedback
    return {}
  end # main
  
  # This method instructs the technician to dry plates.
  def dry_plates
    show do
      title "Let plate dry"
      check "Wrap plates in foil and place them agar side down in the dark fume hood to dry."
      check "Place the plates with agar side down in the dark fume hood to dry."
      note "Noting that placing agar side down is opposite of what you normally do when placing plates in incubator. This will help the antibiotic spread into the agar."
    end
  end
  
  # Tells the technician to make plates, and if a plate batch is empty, deletes it.
  #
  # @param media [String] the name of the media
  # @param antibiotic [String] the name of the antibiotic
  # @param op [Operation] the current operation this method operates on
  # @param volume [Integer] the volume of the antibiotic.
  def make_plates media, antibiotic, op, volume
    #  integer string_end is used to substring out the antibiotic marker from the output media name so a plate batch of the non antibiotic media can be found
    string_end = ((media.length - 1) - (antibiotic.length + 3))
    input_media = Sample.find_by_name(media[0..string_end])
    plate_batch = Collection.where(object_type_id: ObjectType.find_by_name("Agar Plate Batch").id).select { |b| (!b.deleted?) && (b.matrix[0].include? input_media.id) }.first        
    plate_batch.remove_one
    if plate_batch.empty?
      plate_batch.mark_as_deleted
    end
    show do
      title "Make Antibiotic Plates"
      check "Grab #{input_media.name} Plate from batch #{plate_batch.id}."
      check "Label the plate: #{op.output("Plate").item.id}"
      check "Grab 1 mL #{antibiotic} stock in SF1 or M20."
      check "Wait for the #{antibiotic} stock to thaw."
      if (antibiotic == "clonNat" || antibiotic == "Bleo")
        check "Make master mix by mixing #{volume}µL #{antibiotic} with #{antibiotic == "clonNat" ? 175:150}µL of water"
        check "Use sterile beads to spread mix on the #{input_media.name} plate. Mark the plate in RED sharpie"
      else
        check "Use sterile beads to spread #{volume} µL of #{antibiotic} on the #{input_media.name} plate. Mark the plate with RED sharpie."
      end
    end
  end
  
  # This method tells the technician to start a timer.
  def start_timer
    timer_link = 'https://www.google.com/search?q=timer+for+1+hour&oq=timer+for+1+hour+30+minute&aqs=chrome..69i57j0l5.2200j0j7&sourceid=chrome&ie=UTF-8'
    show do
      title "Start 1-hour, 30-minute timer"
      
      note "Start a <a href=#{timer_link} target='_blank'>one-hour 30-minute timer on Google</a>, and sit tight."
    end
  end

end # Protocol