#this protocol makes 20 mM NaOH

class Protocol

  def main
      
    op=operations.first

    operations.retrieve interactive: false
    operations.make
    
    show do
        title "Gather the following items:"
        
        check "250 mL bottle"
        check "NaOH"
    end
    show do
        title "Weigh"
        
        check "Weigh out 0.159 g NaOH and add to bottle."
    end
    show do
        title "Add DI water"
       
        check "Fill bottle up to 200 mL mark with DI water, mix well."
    end
    show do
        title "Label"
        
        check "Label the bottle #{op.output("20 mM NaOH").item.id}, 'date', and your initials."
    end
    

    return {}
    
  end

end
