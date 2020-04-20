
class Protocol

  def main
    show do 
      title "Please discard all following items"
      note "If the item is an overnight, please bleach the tubes and leave them at the dishwashing station."
      note "If the item is a plate, plasmid, fragment, or glycerol stock, please discard it in the biohazard."
    end
    
    operations.retrieve
    
    operations.each do |op|
      op.input("Item").item.mark_as_deleted
    end

    return {}
  end
end
