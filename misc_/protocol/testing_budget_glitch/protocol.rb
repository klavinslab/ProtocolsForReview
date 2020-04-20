# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    # This is a default, one-size-fits all protocol that shows how you can 
    # access the inputs and outputs of the operations associated with a job.
    # Add specific instructions for this protocol!

    # users = User.all
    # show do
    #     users.each do |u|
    #         note "#{u.name}"
    #     end
    #     #note "#{user.budget_info.collect { |bi| bi[:budget].name }}"
    # end

    
    user = User.find_by_name("Eriberto Lopez")
    budgets = user.budget_info.collect { |bi| bi[:budget].name }.to_a
    show do 
        note "#{user.name}"
        note "#{budgets}"
        select budgets, var: "choice", label: "Choose a budget"
        select ["DARPA"], var: "num", label: "Choose a number"
    end
    
    return {}
    
  end

end