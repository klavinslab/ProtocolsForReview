
class Protocol

  def main
      
    op=operations.first

    operations.retrieve.make
   
   #ask tech to gather items 
   show do
       title "Gather the following items:"
       
       check "Autoclavable bottle - 400 mL"
       check "Casamino Acids"
       check "DI H20"
       check "Magnetic Stirrer"
   end
   
   #ask tech to add acids to bottle
   show do
       title "Add to bottle:"
       
       check "Add 40 g casamino acids into bottle."
   end
   
   #display directions to adjust with DI water
   show do
       title "Adjust"
       
       check "Adjust to 400 mL with DI H20"
   end
   
   #ask tech to stir solution
   show do
       title "Stir"
       
       check "Stir with magnetic stirrer until dissolved."
   end
   
   #dsplay directions to autoclave
   show do
       title "Autoclave"
       
       check "Autoclave bottle."
   end
   
   #ask tech to label bottle
   show do
       title "Label"
       
       check "Label bottle with Casamino Acids 10% #{op.output("Casamino Acids 10%").item.id} 10mg/ml"
   end
    
    return {}
    
  end

end
