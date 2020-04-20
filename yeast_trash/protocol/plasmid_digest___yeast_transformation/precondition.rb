def precondition(op)
    # ensure the user has set the output to Overnight for Antibiotic Plate if using antibiotic marker
    integrant = op.input("DNA Integrant").sample
    
    if integrant.nil?
        op.error :no_integrant, "Your Yeast Strain #{op.input("Parent").sample.name} has no listed integrant."
        return false
    else
        full_marker = integrant.properties["Yeast Marker"]
        marker = full_marker.downcase[0,3]
        marker = "kan" if marker == "g41"
        antibiotic_marker = ["nat", "kan", "hyg", "ble", "5fo"].include?(marker)
        
        if antibiotic_marker && op.output("Transformation").object_type.name == "Yeast Plate"
            op.error :need_to_incubate, "Plating your Yeast Strain #{op.input("Parent").sample.name} in #{full_marker} requires incubation. Please replan to include Yeast Antibiotic Plating."
            
            return false
        end
        if antibiotic_marker.blank? && op.output("Transformation").object_type.name == "Yeast Overnight for Antibiotic Plate"
            op.error :pick_plate_instead, "You do not need an overnight for #{op.input("Parent").sample.name} in #{full_marker}. Please replan, selecting Yeast Plate as an output Container for this protocol."
            
            return false
        end
    end
    
    return true
end