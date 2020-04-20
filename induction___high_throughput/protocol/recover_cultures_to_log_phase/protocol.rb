needs "Standard Libs/Debug"
needs "Tissue Culture Libs/CollectionDisplay"
needs "Standard Libs/AssociationManagement"
needs "High Throughput Culturing/ExperimentInitializer"

# HIDDEN INPUTS!
# - Antibiotic Media for plating
# - IF prepare_media_cookie THEN
#       - Pre-made antibiotic media
#       - Inducers

# HIDDEN OUTPUTS!
# - IF prepare_media_cookie THEN
#       - antibiotic media with inducer, enough for full induction experiment

class Protocol
    
  include Debug
  include CollectionDisplay
  include AssociationManagement
  include PartProvenance
  include ExperimentInitializer
  
  #I/O
  INPUT = "96 Deep Well Plate in"
  OUTPUT = "96 Deep Well Plate out"
  
  # Parameters 
  CULT_DILU_VOL = "Culture Vol (µl)"
  MEDIA_DILU_VOL = "Media Vol (µl)"
  GROWTH_TEMP = "Growth Temperature (°C)"
  RECOVERY_PERIOD = "Recovery Time (hr)"
  
  def main
      
      intro()
      
      operations.retrieve
      operations.make
      
      # Gather materials
      gather_materials()
      
      operations.each do |op|
        
        in_collection = op.input(INPUT).collection

        out_collection = op.output(OUTPUT).collection
        
        # COPY DATA AND SAMPLES FROM INPUT COLLECTION TO OUTPUT COLLECTION
        # ALSO RECORD PROVENANCE RELATION
        transference_paperwork(in_collection, out_collection)
        
        experimental_antibiotic_mat   = in_collection.data_matrix_values("Experimental Antibiotic")
        media_type_mat                = in_collection.data_matrix_values("Type of Media")
        inducer_mat                   = in_collection.data_matrix_values("Inducers")

        # Display and direct tech by using a list of media rc_lists
        fill_plate_with_media(out_collection, experimental_antibiotic_mat, media_type_mat) # From InnoculateHelper
        
        # Transfer culture into plate
        transfer_cultures(op)
        
        # Moving output plate to incubator
        show {
          title "Incubating Plate #{out_collection.id}"
          separator
          check "Set a <b>#{op.input(RECOVERY_PERIOD).val}hr</b> timer & let a lab manger know if you will not be present when it is done."
        }
        out_collection.location = "#{op.input(GROWTH_TEMP).val.to_i}C 800rpm shaker"
        out_collection.save
        release [Item.find(out_collection.id)], interactive: true
        
        if in_collection.get("prepare_media_cookie") && in_collection.get("prepare_media_cookie") == "yes"
          # Creating experimental antibiotic and inducer media hash
          media_hash = complex_tally_induced_media_variants(inducer_mat, experimental_antibiotic_mat, media_type_mat)

          # Directing tech to create just the right amount of each variant of experimental media
          create_induced_media_instructions(media_hash)
        end
        
        # Delete stationary phase overnight plate
        in_collection.mark_as_deleted
        in_collection.save
        
        # cleaning up 
        show {
          title "Cleaning Up..."
          separator
          check "Before finishing protocol, take 96 Deep Well plate #{in_collection} and soak wells with diluted bleach."
          check "Put the <b>1M IPTG</b> & <b>1M Arabinose</b> stocks back into the 4C fridge."
        }
      end
      operations.store() #THERE SHOULD BE NOTHING TO STORE
      return {}
  end #main
  
  def intro()
    show do
      title "Introduction - Overnight Plate Recovery"
      separator
      note "In this protocol you will dilute stationary phase cultures in order to get cultures back into log phase."
      note "<b>1.</b> Fill dilution plates with media"
      note "<b>2.</b> Dilute stationary phase cultures"
      note "<b>3.</b> Incubate diluted plate in plate reader for 3 hours"
      note "<b>4.</b> Prepare induction media"
    end
  end
  
  def gather_materials()
      output_plates = operations.map {|op| op.output(OUTPUT).collection.object_type.name}
      num_plt_hash = Hash.new(0)
      output_plates.each {|obj_type|
        if !num_plt_hash.include? obj_type
          num_plt_hash[obj_type] = 1
        else
          num_plt_hash[obj_type] += 1
        end
      }
      show do
        title "Gather Materials"
        separator
        num_plt_hash.each {|obj_type, num_plt| check "<b>#{num_plt}</b> #{obj_type}(s)" }
        check "<b>1M IPTG</b> from antibiotics freezer and set on bench to thaw."
        check "<b>1M Arabinose</b> from antibiotics freezer and set on bench to thaw."
      end
  end
  
  def transfer_cultures(op)
    show {
      title "Recovering Stationary Cultures"            
      separator
      note "Transfer <b>#{op.input(CULT_DILU_VOL).val.to_i}ul</b> from plate <b>#{op.input(INPUT).collection.id}</b> to plate <b>#{op.output(OUTPUT).collection.id}</b>"
      bullet "<b>Maintain the same layout and order of the cultures!</b>"
    }
  end
  
  # Creates experimental induction + antibiotic media for subsequent induction protocols
  def create_induced_media_instructions(media_hash)
    show do
      title "Add inducer to experimental media"
      media_hash.each do |media_type_and_inducers, quant|
        media_type = media_type_and_inducers[0]
        inducer_hash = media_type_and_inducers[1]
        
        full_name = media_type
        inducer_hash.each do |inducer, conc|
          full_name += " + " + inducer + ":" + conc.to_s + "mM"
        end 
        
        check "In an appropriate container, aliquot <b>#{(quant * 3.3).round(2)}mL</b> of <b>#{media_type}</b> and label: <b>#{full_name}</b>"
        inducer_hash.each do |inducer_type, conc|
            check "To the container labeled <b>#{full_name}</b>, add #{(quant * 3.3 * conc).round(2)}µl of #{inducer_type}"
        end
      end
      note "Put aside induced media for use in the downstream operations of this induction experiment."
    end
  end
  
end #Class
