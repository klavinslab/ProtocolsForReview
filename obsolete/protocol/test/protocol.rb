

# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main

    ups = show do
        upload var: "ups"
    end.get_response("ups")
    
    if ups
        show do
            title "uploads"
            ups.each do |u|
                note "#{u.id} - #{u.name}"
            end
        end
        
        show do
            title "uploads"
            ups.each do |u|
                contents = ""
                f = open(u.url)
                note f.read
            end
        end
    end
    {}
  end
end
