def precondition(op)
    integrant = op.input("Overnight").sample.properties["Integrant"]
    
    if integrant.nil?
        op.error :no_integrant, "Your Yeast Strain #{op.input("Overnight").sample.name} has no listed integrant"
    else
        marker = integrant.properties["Yeast Marker"].downcase[0,3]
        marker = "kan" if marker == "g41"
        #return ["nat", "kan", "hyg", "ble", "5fo"].include?(marker)
    end
    
    return integrant# && ((Time.now - op.input("Plate").item.created_at) / 3600.00).ceil >= 12
end