needs "Tissue Culture Libs/TissueCulture"

# TODO: Add specific media

class Protocol
    include TissueCulture

  def main

    required_ppe(STANDARD_PPE)

    plates = get_plates TRYPSINIZED_PLATE_CONTAINERS
    plates.each { |plate| plate.mark_as_deleted }
    release_tc_plates plates

    plate_requests = ObjectType.find_by_name("Plate Request").items.each { |i| i.mark_as_deleted }
    PLATE_REQUESTS.each do |n|
      ot = ObjectType.find_by_name(n) 
      ot.items.each { |i| i.mark_as_deleted } if ot
    end
    return {}
    
  end

end
