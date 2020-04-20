needs "Hydra Husbandry/UnverifiedHydra"

class Protocol

  include UnverifiedHydra
  
  

  def main
    
    plates = find_all_uvhp()
    show do
      title "Plate Situation:"
      plates.each do |plate|
        table plate.matrix.map{|row| row.map{|id| id == -1 ? '(empty)' : Item.find(id).location}}
      end
    end
    
    show do
      title "Time for some magic"
      note "Say abracadabra and hit okay."
    end
    
    wells = find(:item, { object_type: { name: "Unverified Hydra Well" } } )
    show do
      note "There are #{wells.size} UVHWs"
    end
    wells.each do |well|
      if find_uvhw(well) == nil
        store_uvhw(well)
      end
      well.location = name_of_uvhw(well)
    end
    
    plates = find_all_uvhp()
    show do
      title "Plate Situation:"
      plates.each do |plate|
        table plate.matrix.map{|row| row.map{|id| id == -1 ? '(empty)' : Item.find(id).location}}
      end
    end

    return {}
    
  end
  

end
