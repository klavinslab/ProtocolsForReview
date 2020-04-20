# Methods for Hydra informatics and Data compilation

needs "Standard Libs/Debug"
module HydraInformatics
  
  include Debug
  def findByAttribute(key)
    # return a list of items with the given attribute
    wells = getWells()
    # log_info(wells.select{|well| well.get(key) != nil})
    return wells.select{|well| well.get(key) != nil}
  end
  
  def findWithAttribute(pattern)
    wells = getWells()
    wells = wells.select do |well|
        keys = well.associations.keys.join(", ").downcase
        keys.include? pattern.downcase
    end
    return wells
    # wells.each{|well| log_info(well.associations)}
  end
  
  def getWells()
    plates = Collection.where(object_type_id: ObjectType.find_by_name("Unverified Hydra Plate").id)
    wells = plates.map{|plate| plate.matrix.flatten.reject{|well_id| well_id == -1}.map{|well_id| Item.find(well_id)}}.flatten
    return wells
  end
  
  def getVerifications(hydra)
      verifications = []
      keys = hydra.associations.keys
      keys.each do |key|
        if(key.include? "Verification")
            data_hash = hydra.get(key)
            date = key.dup
            date.slice! "Verification "
            data_hash['date_verified'] = date
            verifications.append(data_hash)
        end
      end
      return verifications
  end
end
