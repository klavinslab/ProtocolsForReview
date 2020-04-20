
needs 'Standard Libs/CommonInputOutputNames'

module YeastDisplayShows
    
    include CommonInputOutputNames

    def prepare_media(container_group, language)
        flask_type = language[:flask_type]
        media_volume = language[:media_volume]
        
        flask_type = flask_type.pluralize if container_group.length > 1
        
        show do
          title "Prepare media"
          warning "Work in the media bay for media preparation."
          check "Grab #{container_group.length} #{flask_type}."
          
          out_ids = container_group.map { |op| op.output(OUTPUT_YEAST).item.id }.join(", ")
          check "Label each flask or tube with the following ids: #{out_ids}"
          
          note "Add #{media_volume} of the following media into the #{flask_type}."
          
          table media_table(container_group)
        end
    end
  
    def innoculate_flasks(container_group, language)
        passage_amount = language[:passage_amount]
        
        input_type = operations.first.input(INPUT_YEAST).name
        plural_input_type = operations.length > 1 ? input_type.pluralize : input_type
        language = language.merge({ input_type: input_type })
        
        show do
          title "Inoculate #{plural_input_type}"
      
          note passage_amount % language
          table transfer_table(container_group)
        end
    end
    
    def media_table(container_group)
        this_table = container_group.start_table
        this_table = this_table.custom_column(heading: 'Media') { |op| op.input("Media").sample.name }
        
        if container_group.all? { |op| media_volume(op) }
            this_table = this_table.custom_column(heading: 'Volume (ml)') { |op| media_volume(op).round }
        end
        
        this_table.output_item(OUTPUT_YEAST, checkable: true).end_table
    end
    
    def get_media(container_group)
        media = container_group.map { |op| op.input("Media").sample.name }.first
        
        show do
            title "Get media"
            
            check "Get a bottle of #{media}."
        end
    end
    
    def transfer_table(container_group)
        this_table = container_group.start_table.input_item(INPUT_YEAST)
        
        if container_group.any? { |op| sample_tube_label(op.input(INPUT_YEAST).item) }
            this_table = this_table.custom_column(heading: 'Tube label') { |op| sample_tube_label(op.input(INPUT_YEAST).item) }
        end
        
        if container_group.all? { |op| transfer_volume(op) }
            this_table = this_table.custom_column(heading: 'Volume (ml)') { |op| transfer_volume(op).round(1) }
        end
        
        this_table.output_item(OUTPUT_YEAST, checkable: true).end_table
    end
    
    def measure_culture_ods(ops)
        show do
            title 'Measure library culture densities.'
            
            note 'Use the Nanodrop to measure the density of each yeast culture, and record the OD600.'
            warning 'Record the OD600 exactly as it is shown on the screen.'
            
            table ops.start_table
                .input_item(INPUT_YEAST)
                .get(:od, type: 'number', heading: 'OD600')
                .end_table
        end
    end
  
end