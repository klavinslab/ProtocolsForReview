


class Protocol

    INPUT = "Culture"
    OUTPUT = "Lysate"
      
  def main
      
      ##TASK: Retrieve operation inputs and make operation outputs. 
      operations.retrieve
      operations.make
      
        intro
        
        spin_down
        
        lyse
        
        rnaseA
        
        return {}
  end
  
  
  
  def intro
        show do
            title 'Intro'
            note "Fifty-milliliter yeast cultures were harvested by centrifugation and lysed by heating to 70 °C 
                  for 10 min in 2 mL of 200 mM LiOAc and 1% SDS (44)."   
        end
  end
  
  def spin_down
      
        speed = 12000
        duration = 10

      show do 
          title "Transfer to centrifuge buckets"
          note "Using a Sharpie, label #{operations.length} 50 mL Falcon tubes with the following IDs:"
          operations.each do |op|
              note "#{op.input(INPUT).item.id}"
              check "Falcon tube labelled #{op.input(INPUT).item.id}"
          end
          check "Pour the contents of each flask into the corresponding Falcon tube"
          operations.each do |op|
              check "Contents of flask #{op.input(INPUT).item.id} into Falcon tube #{op.input(INPUT).item.id}"
          end
      end
      show do
          title 'Spin Down Sample'
           if operations.length % 2 == 1
              ##TASK: Add a 'warning' that centrifuges must be balanced'
              warning 'Create balance tube to balance centrifuge'
            end
          check "Spin down samples at #{speed} RPM for #{duration} minutes"
          ##TASK: Define constants for the speed and duration of the spin. Then refer to these constants in the line above. 
       end
       
       show do 
            title "Discard supernatant"
            note "Carefully pour out the supernatant from each Falcon tube into liquid waste:"
            #TASK Check box for ID of each input item.
            operations.each do |op|
              check "Contents of flask #{op.input(INPUT).item.id} into liquid waste"
          end
            
      end
       
  end
  
   def lyse
  
       lioac = find(:item, object_type: { name: "200 nM LiOAc" })
       lioac_vol = 2
       sds = find(:item, object_type: { name: "1% SDS (44)" })
       sds_vol = 2
     
         show do
             title "Resuspend pellets in  LiOAc and SDS"
             
             operations.each do |op|
                 check "Add #{sds_vol} mL of #{sds} to #{op.input(INPUT).item.id}"
             end
             operations.each do |op|
                 check "Add #{lioac_vol} mL of #{lioac} to #{op.input(INPUT).item.id}"
             end
             
           end
           
         show do
             title "Remove Supernatant"
             operations.each do |op|
                 check "Pour supernatant of falcon tube #{op.input(INPUT).item.id} into liquid waste"
             end
         end
         
   end

   def rnaseA
      
       rA = find(:item, object_type: { name: "Bovine Pancreatic Ribonuclease" })
       
       show do
           title "Add rnaseA"
           operations.each do |op|
              check "Add #{rA} to #{op.input(INPUT).item.id}" 
           end
       end
   end
   
end
