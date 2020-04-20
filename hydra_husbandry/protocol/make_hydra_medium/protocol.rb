class Protocol
  
  def main
    
    # mass of each reagent in grams per 50 L of DI H2O
    recipe = {"CaCl2" => 7.35, "MgCl2" => 1.02, "NaHCO3" => 0.15, "KNO3" => 2.1, "MgSO4" => 0.48}
    
    # total volume in liters of hydra medium produced
    volume = operations.sum{|op| op.input("Volume (L)").val}
    volume = volume == 0 ? 50 : volume # default to 0 L
    
    show do
      title "Gather the following reagents"
      
      recipe.each_key {|reagent| bullet reagent}
    end
    
    show do
      title "Make Hydra Medium"
      
      note "Weigh out the following masses of salts and add to Nalgene tank."
      table [["salt", "mass (g)"]] + recipe.keys.zip(recipe.values.map{|mpv| {content: (mpv*volume/50).round(2), check: true}})
      bullet "Add #{volume} L of DI H20 to the tank."
      bullet "Stir with paddle until fully dissolved."
    end

  end

end