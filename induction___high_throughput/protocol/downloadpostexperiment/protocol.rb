# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!
needs "Standard Libs/Debug" 
needs "Induction - High Throughput/HighThroughputHelper" 

class Protocol
    
    #require 'rubygems'
    #require 'net/ssh'
    #require 'net/scp'
    
    include Debug    
    #include HighThroughputHelper     

    INPUT_ID="plan id"
    
    def main
    
    # look for associated item
    #it=Item.find(op.input(INPUT_ID))
    plan=Plan.find(7614)
    it=Item.find(112641)
    
    # what can we see?
    p_as=plan.associations
    i_as=it.associations
    
    show do
        p_as.each do |pa|
            note "#{pa}"
        end
    end
    
    show do
        i_as.each do |ia|
            note "#{ia}"
        end
    end
    
    #Net::SSH.start("ip_address", "username",:password => "*********") do |session|
    #    session.scp.download! "/home/logfiles/2-1-2012/login.xls", "/home/anil/Downloads"
    #end
    
    
    return {}
    
  end

end
