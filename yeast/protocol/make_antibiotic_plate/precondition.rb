def precondition(op)
    # Ensure that the plate media is antibiotic
    plate_media = op.output("Plate").sample.name
    antiMarkers = ["nat", "kan", "hyg", "ble", "5fo", "g41"]
    antiMarkers.each do |marker| 
        if plate_media.downcase.include?(marker)
            return true
        end
    end
    op.error :not_antibiotic, "the media you selected to plate on is not antibiotic"
    return false
end