eval Library.find_by_name("Preconditions").code("source").content
extend Preconditions

def precondition(op)
    # # ensure the user has set the output to Overnight for Antibiotic Plate if using antibiotic marker
    integrant = op.input("Genetic Material")
    full_marker = integrant.sample.properties["Yeast Marker"]
    marker = full_marker.downcase[0,3]
    marker = "kan" if marker == "g41"
    antibiotic_marker = ["nat", "kan", "hyg", "ble", "5fo"].include?(marker)
    
    
    # if(integrant.object_type.name == "0.6mL tube of Digested Plasmid" && op.output("Transformation").sample.properties["Integrant"] != integrant.sample) 
    #     op.error :integrant_mismatch, "the integrant you selected to use in the plan is not the same one associated with your Yeast Strain"
    #     return false
    # end
    
    
    yeast_integrant_fv = FieldValue.where(parent_id: op.output("Transformation").sample.id, parent_class: "Sample", name: "Integrant").first
    if yeast_integrant_fv.nil?
        return false
    end
    
    if integrant.object_type.name == "0.6mL tube of Digested Plasmid" && !(time_elapsed op, "Genetic Material", hours: 1)
        return false
    end
    
    if antibiotic_marker && op.output("Transformation").object_type.name == "Yeast Plate"
        op.error :need_to_incubate, "Plating your Yeast Strain #{op.input("Parent").sample.name} in #{full_marker} requires incubation. Please replan to include Yeast Antibiotic Plating."
        
        return false
    end
    if antibiotic_marker.blank? && op.output("Transformation").object_type.name == "Yeast Overnight for Antibiotic Plate"
        op.error :pick_plate_instead, "You do not need an overnight for #{op.input("Parent").sample.name} in #{full_marker}. Please replan, selecting Yeast Plate as an output Container for this protocol."
        
        return false
    end
    
    
    
    return Item.where(sample_id: op.input("Parent").sample.id, object_type_id: 457).first
end