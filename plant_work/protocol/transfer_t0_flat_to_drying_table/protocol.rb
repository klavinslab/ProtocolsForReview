# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  def main
 if t0_flats.empty? == false
#         t0_flats_data = show do
#             title "Check status of T0 flats"
#             t0_flats.each do |tf|
#                 select ["flowers", "green siliques", "dry siliques"], var: "infloresence_status_#{tf.id}", label: "What is the current status of the infloresences of the plants in this flat #{tf.id}?", default: "#{tf.get(:infloresence)}"
#             end
#         end
#     end
    
#     t0_flats.each do |tf|
#         tf.associate :infloresence, t0_flats_data["infloresence_status_#{tf.id}"]
#         if tf.location == "Wrapped on workbench"
#             tf.move("GT1") &&
#             show do
#                 check "Move flat no. #{tf.id} to #{tf.location}"
#             end
#         end
        
#         if tf.get(:infloresence) == "green siliques"
#           tf.move("DT1") &&
#             show do
#               check "Move flat no. #{tf.id} to the drying table #{tf.location}"
#             end
#         end
#     end

    
  end

end
