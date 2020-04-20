

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    ot = OperationType.where("name": "Purify Gel Slice", "category": "Cloning").first
	ops = Operation.where("operation_type_id LIKE '#{ot.id}' AND updated_at LIKE '2018-09-14%' AND status LIKE 'done'")

	objt = ObjectType.find_by_name("Fragment Stock")
	
	frags = ops.map { |op| op.outputs[0].item }
	
# 	frags.each do |fr|
# 		fr.object_type_id = objt.id
# 		fr.save()
# 	end

	result = frags.map { |fr| fr.object_type.name }
    show do
        note result.to_s
    end

    {}

  end

end
