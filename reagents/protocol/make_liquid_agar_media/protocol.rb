
class Protocol
    
    
def make_media_steps bottle, num_bottles, multiplier, ingredient
  
  show do
    title "Gather the Following Items"
    check "#{num_bottles} #{bottle}(s)"
    ingredient.each{|reagent, info|
       if info[3] == true
        check "#{reagent}" 
       end
       
    }
  end

  if(bottle.include?("1 L Bottle"))
    show do
      title "Add Stir Bar"
      check "Retrieve 1 Medium Magnetic Stir Bar(s) from B1.525 or dishwashing station."
      check "Add the stir bar(s) to the bottle(s)."
    end
  end
  
  ingredient.each{|reagent, info|
    if info[3] == true
      show do
        title "Add #{reagent}"                                                        
        note "Using the #{info[1]}, add <b>#{info[0] * multiplier}</b> #{info[2]} <b>'#{reagent}'</b> into each bottle."
      end
    end
    
  }
  
end

def label_media_steps multiplier, label, number, mix_note = "Shake until most of the powder is dissolved. It is ok if a small amount of powder is not dissolved because the autoclave will dissolve it", water_note = "DI water carboy", label_note = ""
show do
    title "Measure Water"
    note "use the #{water_note} to add water up to the #{multiplier * 800} mL mark"
  end

  show do
    title "Mix Solution"
    note "#{mix_note}"
  end

  show do  
    title "Label Media"
    note "Label the bottle(s) with '#{label}', 'Your initials', 'date', and '#{number}'"
    note "#{label_note}"
  end

end


def main
  a = operations.retrieve(interactive: false).make
  
  n = operations.length
  
  media_to_make = Hash.new(0)
  operations.each do |op|
    item = op.output("Media").item
    name = item.sample.name
    container = item.object_type.name
    if media_to_make["#{container} #{name}"] == 0
      media_to_make["#{container} #{name}"] = [1] #first number in array signifies # of bottles
    else
      media_to_make["#{container} #{name}"][0] += 1 
    end
      media_to_make["#{container} #{name}"].push op.output("Media").item.id #other numbers in array signify the output numbers
  end
  
  media_to_make.each do |media, array|
  num_bottles = array.slice(0)
  item_numbers = array[1...array.length]
  vol = media[0..2].to_f
  agar = media.include? "Agar"

  multiplier = vol / 800.0
  bottle = "#{vol + vol / 4 == 1000.0 ? "1 L" : "#{vol + vol / 4} mL"} Bottle"
  ingredient = Hash.new(0)  
  label = ""
  
  case
    when media.include?("SOB") || media.include?("SOC")
      label = "SOB liquid Media"
    
      #ingredient.push Item.find_by_object_type_id(ObjectType.find_by_name("Hanahan's Broth").id)
      ingredient["Hanahan's Broth"] = [22.4, "gram scale, large weigh boat, and chemical spatula", "grams of", true]
      if media.include?("SOC")
        label = "SOC liquid Media - Dextrose not added yet"
        #ingredient.push Item.find_by_sample_id(Sample.find_by_name("40% Dextrose").id)
        make_media_steps bottle, num_bottles, multiplier, ingredient #change to bacteria media steps when Hanahan's broth is fixed
        label_media_steps multiplier, label, item_numbers
        show do
          title "Add Dextrose"
          note "Once the autoclave is done, remove the SOC liquid without Dextrose and add #{7.2 * multiplier} mL of 40% Dextrose to the bottle"
        end
        show do 
          title "Relabel"
          note "Cross out the 'Dextrose not added'"
        end
      else
        make_media_steps bottle, num_bottles, multiplier, ingredient #change to bacteria media steps when Hanahan's broth is fixed
        label_media_steps multiplier, label, item_numbers 
      end
    when media.include?("TB")
      label = "TB Liquid Media"
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Terrific Broth, modified").id).object_type.name}"] = [38.08, "gram scale, large weigh boat, and chemical spatula", "grams of", true] 
      ingredient["#{Item.find_by_sample_id(Sample.find_by_name("50% Glycerol").id).sample.name}"] = [12.8, "serological pipette", "mL of", true]
      make_media_steps bottle, num_bottles, multiplier, ingredient
      label_media_steps multiplier, label, item_numbers
    when media.include?("LB")
      if agar 
        label = "LB Agar"
        ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("LB Agar Miller").id).object_type.name}"] = [29.6, "gram scale, large weigh boat, and chemical spatula", "grams of", true]
      else 
        label = "LB Liquid Media"
        ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Difco LB Broth, Miller").id).object_type.name}"] = [20, "gram scale, large weigh boat, and chemical spatula", "grams of", true]
      end
      make_media_steps bottle, num_bottles, multiplier, ingredient
      label_media_steps multiplier, label, item_numbers 
    when media.include?("10% Glycerol")
       ingredient["#{Item.find_by_sample_id(Sample.find_by_name("50% Glycerol").id).sample.name}"] = [160, "serological pipette", "mL of", true]
       make_media_steps bottle, num_bottles, multiplier, ingredient
       label_media_steps multiplier, label, item_numbers
    when media.include?("YPAD")
      if agar
        label = "YPAD Agar"
      else
        label = "YPAD liquid"
      end
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Bacto Tryptone").id).object_type.name}"] = [16, "gram scale, large weigh boat, and chemical spatula", "grams of", true]
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Bacto Yeast Extract").id).object_type.name}"] = [8, "gram scale, large weigh boat, and chemical spatual", "grams of", true]
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Dextrose").id).object_type.name}"] = [16, "gram scale, large weigh boat, and chemical spatula", "grams of", true]
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Adenine (Adenine hemisulfate)").id).object_type.name}"] = [0.064, "gram scale, large weigh boat, and chemical spatula", "grams of", true]
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Bacto Agar").id).object_type.name}"] = [16, "gram scale, large weigh boat, and chemical spatula", "grams of", agar]
      
      if media.include? "Sorbitol"
        label = "YPAD + 1M Sorb liquid"
        sorb_sample = Sample.find_by_name("Sorbitol Powder")
        sorb_item = sorb_sample.items.select {|i| i.location != 'deleted' && i.object_type.name == "Bottle"}.first
        ingredient["#{sorb_item} #{sorb_sample.name}"] = [145.74, "gram scale, large weigh boat, and chemical spatula", "grams of", true] # grams of sorb (182.17g/mol) for 1M sorb in 800mL of media
      end
      
      make_media_steps bottle, num_bottles, multiplier, ingredient
      label_media_steps multiplier, label, item_numbers
    when media.include?("SC") || media.include?("SDO")
      galactose = media.include?("Gal")
      label = "SDO"
      label += " +Gal" if galactose
      his = true unless media.include? ("-His")
      label += " -His" unless his == true
      leu = true unless media.include? ("-Leu")
      label += " -Leu" unless leu == true
      ura = true unless media.include? ("-Ura")
      label += " -Ura" unless ura == true
      trp = true unless media.include? ("-Trp")
      label += " -Trp" unless trp == true
      if media.include?("SDO") && !["-His", "-Leu", "-Ura", "-Trp"].any? { |m| media.include? m }
        his = false 
        leu = false 
        ura = false
        trp = false
      end

      if media.include?("SC")
        label = "SC"
      end
     
      label += " Agar" unless agar == false

      drop_out = [true, true, true, galactose, true, his, leu, ura, trp, ]
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Yeast Nitrogen Base without Amino Acids").id).object_type.name}"] = [5.36, "gram scale, large weigh boat, and chemical spatula", "grams of", true]
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Yeast Synthetic Drop-out Medium Supplements").id).object_type.name}"] = [1.12, "gram scale, large weigh boat, and chemical spatula", "grams of", true]
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Dextrose").id).object_type.name}"] = galactose ? [1.6, "gram scale, large weigh boat, and chemical spatula", "grams of", true] : [16, "gram scale, large weigh boat, and chemical spatula", "grams of", true]
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Galactose, 99%").id).object_type.name}"] = [16, "gram scale, large weigh boat, and chemical spatula", "grams of", galactose]
      #ingredient.push "D-Galactose"
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Adenine (Adenine hemisulfate)").id).object_type.name}"] = [0.064, "gram scale, large weigh boat, and chemical spatula", "grams of", true]

      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Histidine Solution").id).object_type.name}"] = [8, "serological pipette", "mL of", his]
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Leucine Solution").id).object_type.name}"] = [8, "serological pipette", "mL of", leu]
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Uracil Solution").id).object_type.name}"] = [8, "serological pipette", "mL of", ura]
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Tryptophan Solution").id).object_type.name}"] = [8, "serological pipette", "mL of", trp]
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Bacto Agar").id).object_type.name}"] = [16, "gram scale, large weigh boat, and chemical spatula", "grams of", agar]


      make_media_steps bottle, num_bottles, multiplier, ingredient
      label_media_steps multiplier, label, item_numbers
      
      
      
    # Yeast Gates Alternative media
    when media.include?("Synthetic Complete + 1M Sorbitol Media") || media.include?("Synthetic Complete + 2% glycerol 2% ethanol Media")
        label = media.include?('2% glycerol') ? 'SC + 2% glycerol 2% EtOH' : 'SC + 1M Sorbitol'
        
        directions = ["gram scale, large weigh boat, and chemical spatula", "serological pipette"]
        units = ['grams of', 'mL of']
        
        # common ingredients
        dry_list = [["Yeast Nitrogen Base without Amino Acids", 5.36], ["Yeast Synthetic Drop-out Medium Supplements", 1.12], ["Adenine (Adenine hemisulfate)", 0.064]]
        liquids_list = [["Histidine Solution", 8],["Leucine Solution", 8],["Uracil Solution", 8], ["Tryptophan Solution", 8]]

        # Alternative ingredient compositions
        dextrose = media.include?('Sorbitol') ? ['Dextrose', 16] : nil
        sorbitol = media.include?('Sorbitol') ? ['Sorbitol', 145.7] : nil # Amount of grams of sorbitol/per 800mL
        glycerol = media.include?('2% glycerol') ? ['50% Glycerol', 32] : nil
        # etoh = media.include?('2% glycerol') ? ['100% Ethanol', 16] : nil
        etoh = nil # Due to likely issue of evaporation durring autoclaving, we will add this ingredient after
        
        alt_ingredients = [dextrose, glycerol, etoh, sorbitol].select {|ingred| ingred != nil}
        
        dry_list.each {|ing, amt| ingredient[Item.find_by_object_type_id(ObjectType.find_by_name(ing).id).object_type.name] = [amt, directions[0], units[0], true]}
        liquids_list.each {|ing, amt| ingredient[Item.find_by_object_type_id(ObjectType.find_by_name(ing).id).object_type.name] = [amt, directions[1], units[1], true]}
        
        alt_ingredients.each do |ingred, amt| 
            if ingred.include?('%')
                ingredient[ingred] = [amt, directions[1], units[1], true]
            else
                ingredient[ingred] = [amt, directions[0], units[0], true]
            end
        end
        
        make_media_steps bottle, num_bottles, multiplier, ingredient
        label_media_steps multiplier, label, item_numbers
    when media.include?("YPAD + 1M Sorbitol")
      
    when media.include?("M9 + Glucose")
      label = "M9-glucose"
      ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("DI Water, Sterile").id).object_type.name}"] = [500, "autoclaved, large graduated cylinder", "mL of", true]
      ingredient["CaCl2, 1M"] = [80, "P100 pipette", "uL of", true]#Item.find_by_sample_id(Sample.find_by_name("CaCl2 1M").id) 
      ingredient["MgSO4, 1M"] = [1.6, "serological or P1000 pipette", "mL of", true]#Item.find_by_sample_id(Sample.find_by_name("MgSO4 1M").id)
      ingredient["Thiamine Hydrochloride solution (34g/L)"] = [8, "serological pipette", "mL of", true]#Item.find_by_sample_id(Sample.find_by_name("Thiamine Hydrochloride 34g/L").id) 
      ingredient["10% Casamino Acids"] = [16, "serological pipette", "mL of", true] #Item.find_by_sample_id(Sample.find_by_name("10% Casamino Acids").id)
      ingredient["20% D-Glucose"] = [16, "serological pipette", "mL of", true]#Item.find_by_sample_id(Sample.find_by_name("20% D-Glucose").id) 
      ingredient["5x M9 salts"] = [160, "serological pipette", "mL of", true]#Item.find_by_sample_id(Sample.find_by_name("5x M9 salts").id)

      make_media_steps bottle, num_bottles, multiplier, ingredient
      label_media_steps multiplier, label, item_numbers, "Shake the bottle(s) to mix the solution.", "sterile DI Water", "M9-glucose is not autoclaved. store it in the Deli Fridge."
    
    when media.include?("5x M9 salts")
        label = "5x M9 salts"
        ingredient["DI water"] = [600, "DI water carboy", "mL of", true]
        ingredient["Sodium Phosphate, Dibasic"] = [27.12, "gram scale, large weigh boat, and chemical spatula", "grams of", true] ##{Item.find_by_object_type_id(ObjectType.find_by_name("Sodium Phosphate, Dibasic").id).object_type.name}
        ingredient["Potassium Phosphate, Monobasic"] = [12, "gram scale, large weigh boat, and chemical spatula", "grams of", true]#{Item.find_by_object_type_id(ObjectType.find_by_name("Potassium Phosphate, Monobasic").id).object_type.name}
        ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Sodium Chloride").id).object_type.name}"] = [2.0, "gram scale, large weigh boat, and chemical spatula", "grams of", true]
        ingredient["Ammonium Chloride"] = [4.0, "gram scale, large weigh boat, and chemical spatula", "grams of", true]

        make_media_steps bottle, num_bottles, multiplier, ingredient
        label_media_steps multiplier, label, item_numbers, mix_note = "stir with magnetic stirrer until dissolved.\nThis solution is sterilized by autoclaving."
    when media.include?("Casamino Acids 10%")
        label = "Casamino acids 10%"
        ingredient["#{Item.find_by_object_type_id(ObjectType.find_by_name("Bacto Casamino Acids").id).object_type.name}"] = [80.0, "gram scale, large weigh boat, and chemical spatula", "grams of", true]

        make_media_steps bottle, num_bottles, multiplier, ingredient
        label_media_steps multiplier, label, item_numbers, mix_note = "stir with magnetic stirrer until dissolved." #\nThe solution can either be autoclaved or filter sterilized (0.22 uM)
    end


  end

end
end