# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!
needs "Plant Work/Plant Work General"
class Protocol

include General

  def main
 
    operations.make

    
    show do
        title "Put on PPE"
        check "Lab coat"
        check "Overshoes"
        check "Gloves"
        check "Saftey goggles. Agrobacterium to the eyes can cause inflammation"
    end
    
    show do 
        title "Retrieve Agro Mixes"
        table operations.start_table
            .input_item("Agro mix")
            .custom_column(heading: "location", checkable: true){ |op| op.input("Agro mix").item.location}
            .end_table
    end
    
    show do 
        title "Gather items for infiltrations"
        note "<a href= https://docs.google.com/spreadsheets/d/16OkfwIC0hgEmXjRQMZeab9gaVdNIjzv-g99trjd2MZs/edit?usp=sharingPlant lab inventory> Plant lab inventory </a>"
        check "#{operations.length} 1 ml blunt end #{"syringe".pluralize(operations.length)}"
        check "Paper towels"
        check "Thick marker pen"
    end
    
    show do
        title "Prepare new trays"
        table operations.start_table
            .input_item("Plants", heading:"Tray of Plants")
            .custom_column(heading:"Transfer over"){"3 plants"}
            .output_item("Infiltrated plants", heading: "To new tray, labelled...", checkable: true)
            .end_table
        check "Label the plants in each tray 1,2,3 by writing on a leaf with marker pen"
    end
    
    operations.each do |op|
        show do
            title "Infiltrate plants in tray #{op.output("Infiltrated plants").item.id}"
            note "Pick a leaf on each plant that is of intermediate age and healthy appearance"
            check "Draw up agro strain into syringe. Place syringe flat against the bottom side of the leaf, with a gloved finger applying pressure on the opposite side of the leaf"
            check "Gently infiltrate bacterial suspension into leaf. It will spread as a dark spot. Aim for a roughly 1/2 inch diameter infiltration spot"
            idx = 1
            (0..2).each do
                check "Infiltrate strain #{op.input("Agro mix").item.id} into tray #{op.output("Infiltrated plants").item.id}, plant #{idx}"
                idx = idx + 1
            end
            check "Blot down leaves with tissue paper and trace around the edge of each infiltration spot"
        end
    end
    
    
    operations.each do |op|
        op.plan.associate :plant_age, "#{(weeks_old op.input("Plants").item) + 2} weeks".to_sym
        op.input("Agro mix").item.mark_as_deleted
        op.input("Agro mix").item.save
        op.output("Infiltrated plants").item.associate :plant_genotype, op.input("Plants").sample.name
    end
    
    show do
        title "Tidy up"
        check "Discard syringes into the autoclave waste"
        check "Discard tubes by placing in rack next to the sink in the main lab"
    end
    
    operations.store
    
    return {}
    
  end

end
