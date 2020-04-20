#Make Kan Stock Solution 

class Protocol


  def main

    operations.retrieve interactive: false
    operations.make
    
show do #gather
    title "Gather the following items:"
    
    check "100 mL bottle"
    check "Kanamycin powder"
    check "MG Water"
end

show do #add
    title "Add to bottle"
    
    check "Weigh out 0.5g Kanamycin Powder and add to 100 mL bottle"
end
show do #add water
    title "Add MG H20"
    
    check "Add 50 mL MG water to 100 mL bottle"
end
show do
    title "Label"
    
    check "Mix until powder is dissolved"
    check "Label the bottle #{op.output("Kanamycin Stock Solution").item.id}, 10g/ml 'date', and your initials."
    check "Store in media bay fridge"
end
    
    operations.store interactive: false
    
    return {}
    
  end

end
