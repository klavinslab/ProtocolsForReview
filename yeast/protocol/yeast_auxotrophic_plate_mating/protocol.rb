needs "Standard Libs/Feedback"
class Protocol
    include Feedback
  PLATE_OUTPUT = "Diploid"
  STRAIN_A = "Haploid 1"
  STRAIN_B = "Haploid 2"
  OVERNIGHT_PIPETTE_VOL = 2
  INCUBATOR = "30 C shaker incubator"
  MEDIA = "SDO"
  
  def main

    operations.retrieve

    collect_and_label_plates(operations)
    
    cancel_plateless_ops(operations)
    
    operations.make
    
    label_plates(operations)
    
    operations.running.each do |op|
      mating_ritual(op)
    end
    
    operations.store
    get_protocol_feedback
    return {}
    
  end
  
  def collect_and_label_plates(operations)
    
    if debug
        show do
            title "DEBUG MARKERS TABLE"
            table operations.start_table
                .custom_column(heading: "listed sample markers") { |op| op.output(PLATE_OUTPUT).sample.properties["Integrated Marker(s)"] }
                .end_table
        end
    end
    
    operations.each do |op|
      markers = op.output(PLATE_OUTPUT).sample.properties["Integrated Marker(s)"].split(/[,\s]+/)
      if markers.length < 2
        op.error :not_enough_markers, "A mated yeast strain needs at least 2 markers to correctly select for the diploid strain." 
      end
      markers.map! { |m| m.upcase }
      
      aux_markers, antibiotic_markers = markers.partition { |m| ((m.include?"URA") || (m.include?"TRP") || (m.include?"LEU") || (m.include?"HIS")) }
      if antibiotic_markers.length > 1
        op.error :cannot_plate_antibiotic_markers, "Cannot plate diploid directly onto antibiotic plates. Please use \"Yeast Mating\" protocol instead."
      end
      markers = aux_markers
      
      markers.sort!
      markers.map! { |m| "-#{m}" }
      op.temporary[:my_plate_type] = MEDIA + " " + markers.to_sentence(words_connector: ",", last_word_connector: ",", two_words_connector: ",")
    end
    
    # operations.group_by { |op| op.temporary[:my_plate_type] }
    
    plate_table = operations.running.start_table
                            .custom_column(heading: "Plate type") { |op| op.temporary[:my_plate_type] }
                            .get(:plate_found?, type: 'text', default: 'y', heading: 'Plate Found?')
                            .output_sample(PLATE_OUTPUT)
                            .custom_column(heading: "listed sample markers") { |op| op.output(PLATE_OUTPUT).sample.properties["Integrated Marker(s)"] }
                            .end_table
    
    show do 
      title "Collect and Label Plates"
      note "Collect the following plates and label them with corresponding item id."
      note "If a plate type could not be found in inventory, mark 'Plate Found?' as \'n\' for that row."
      table plate_table
      warning 'Operations for which no plate was found will be canceled.'
    end
  end
  
  def cancel_plateless_ops(operations)
    operations.running.each do  |op|
      if !op.temporary[:plate_found?].downcase.include? "y"
        op.error :no_plate_available, "A valid #{op.temporary[:my_plate_type]} plate could not be found for running this operation."
      end
    end       
    
    if operations.running.empty?
      show do
        title "All operations cancelled."
        note "Make more plates."
      end
    end
  end
  
  def label_plates(operations)
      
        plate_table = operations.running.start_table
                            .custom_column(heading: "Plate type") { |op| op.temporary[:my_plate_type] }
                            .output_item(PLATE_OUTPUT)
                            .end_table
                            
        show do 
          title "Label Plates"
          note "Collect the following plates and label them with corresponding item id."
          table plate_table
        end
  end
  
  def plating_instructions(object_type_name)
    case object_type_name
    when "Yeast Plate"
        plating_instructions = "Scrap some yeast from"
    when "Yeast Glycerol Stock"
        plating_instructions = "Scrap some yeast from"
    when "Yeast Overnight Suspension"
        plating_instructions = "Pipette #{OVERNIGHT_PIPETTE_VOL}uL from"
    else
        plating_instructions = "Scrap some yeast from"
    end
    return plating_instructions
  end
  
  def mating_ritual(op)
    area = "<i>1cm<sup>2</sup></i>"
    show do
      title "Mate strains from #{op.input(STRAIN_A).item} and #{op.input(STRAIN_B).item} for plate #{op.output(PLATE_OUTPUT).item}"
      check "Using a marker, quickly draw a small #{area} box on the bottom of plate #{op.output(PLATE_OUTPUT).item}"
      check "#{plating_instructions(op.input(STRAIN_A).object_type.name)} #{op.input(STRAIN_A).item.object_type.name} #{op.input(STRAIN_A).item} and place onto a #{area} area on Yeast Plate #{op.output(PLATE_OUTPUT).item}."
      check "#{plating_instructions(op.input(STRAIN_B).object_type.name)} #{op.input(STRAIN_B).item.object_type.name} #{op.input(STRAIN_B).item} and place right onto the same #{area} area."
      check "Using a pipette tip or sterile toothpick, mix the two cultures in the #{area} square on the Yeast Plate #{op.output(PLATE_OUTPUT).item}."
      note "Make sure both strains are in contact with each other on the plate. They must be in contact to <i>schmoo</i> (i.e. \"kiss\") to mate. <sup><sup>(how romantic)</sup></sup>"
      check "Finally, using the same pipette tip or sterile toothpick, streak out the mixed yeast across the plate to form single colonies"
    end
    
    op.output(PLATE_OUTPUT).item.move INCUBATOR
  end
end
