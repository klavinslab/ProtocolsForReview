

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    

    c = Collection.find(299863)
    
    show do
        note c.to_s
    end

    gib_batch = Collection.where(object_type_id: ObjectType.find_by_name("Gibson Aliquot Batch").id).where('location != ?', "deleted").first
    
    show do 
        note gib_batch.to_s
    end

    {}

  end

end
