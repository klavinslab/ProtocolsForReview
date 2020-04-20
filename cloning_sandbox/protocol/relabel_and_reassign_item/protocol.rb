needs "Cloning Sandbox/Association passing"


class Protocol
    
    include AssociationPassing

  def main
      
      operations.retrieve.make
      
      debug = false
      
    if debug
        operations.each do |op|
            op.input("Input").item.associate :key, "value"
        end
    end
    
    show do 
        title "Relabel tubes"
        operations.each do |op|
            check "Relabel tube #{op.input("Input").item.id} to #{op.output("Output").item.id}"
        end
    end
    
    operations.each do |op|

        op.input("Input").item.data_associations.each do |d|
            pass_association(op,"Input","Output",d)
        end
        
        op.output("Output").item.associate :provenance, "Reassigned #{op.input("Input").item.id}, a #{op.input("Input").item.object_type.name} of #{op.input("Input").sample.name}"
        
        op.input("Input").item.mark_as_deleted
        op.input("Input").item.save
    end
    
    operations.store
        

    {}

  end

end

