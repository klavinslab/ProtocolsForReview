# By: Eriberto Lopez
# elopez3@uw.edu
# 05/22/18
# °C µl


# Protocol Outline
# Gather materials
# Prepare 96 Deep well w/ appropriate media
# Transfer culture vol from input collection to new deep well plate
# Move plate to incubator
# Set timer for 3 hours


needs "Standard Libs/Debug"
needs "YG_Harmonization/Upload_PlateReader_Data"
needs "YG_Harmonization/PlateReaderMethods"
needs "Tissue Culture Libs/CollectionDisplay"
needs "Induction - High Throughput/NovelChassisLib" # Temporary EL

class Protocol
    
    include Debug
    include Upload_PlateReader_Data
    include PlateReaderMethods
    include CollectionDisplay
    include NovelChassisLib
    
    #I/O
    INPUT = "96 Deep Well Plate in"
    OUTPUT = "96 Deep Well Plate out"
    
    # Parameters 
    CULT_DILU_VOL = "Culture Vol (µl)"
    MEDIA_DILU_VOL = "Media Vol (µl)"
    GROWTH_TEMP = "Growth Temperature (°C)"
    
    # Constants
    RECOVERY_PERIOD = 3#hrs
    
    def main
        
        intro()
        
        operations.make
        
        # Gather materials
        gather_materials()
        
        operations.each do |op|
            if debug
                in_collection = Collection.find(271067)
            else
                in_collection = op.input(INPUT).collection
            end
            
            out_collection = op.output(OUTPUT).collection
            
            
            copy_samp_ids_to_coll(in_collection,out_collection)
            
            # Get associated matricies from input collection
            if debug
                in_collection = Item.find(271067) # example
                inducer_mat = in_collection.get('inducer_mat')
                experimental_antibiotic_mat = in_collection.get('experimental_antibiotic_mat')
            else
                input_item = Item.find(in_collection.id)
                inducer_mat = input_item.get('inducer_mat')
                experimental_antibiotic_mat = input_item.get('experimental_antibiotic_mat')
                
                # Associated matricies to new 96 flat bottom plate
                associate_to_item(out_collection, 'inducer_mat', inducer_mat)
                associate_to_item(out_collection, 'experimental_antibiotic_mat', experimental_antibiotic_mat)
            end
            
            # Slice experimental media matrix by the indecies of the type of media
            medias_rc_lists = uniq_media_rc_lists(experimental_antibiotic_mat)
            
            # Display and direct tech by using a list of media rc_lists
            fill_plate_with_media(op, out_collection, medias_rc_lists)
            
            # Transfer culture into plate
            transfer_cultures(op)
            
            # Moving output plate to incubator
            show {
                title "Incubating Plate #{out_collection.id}"
                separator
                check "Set a <b>#{RECOVERY_PERIOD}hr</b> timer & let a lab manger know if you will not be present when it is done."
            }
            out_collection.location = "#{op.input(GROWTH_TEMP).val.to_i}°C 800rpm shaker"
            out_collection.save
            release [Item.find(out_collection.id)], interactive: true
            
            ### Creating inducer+antibiotic media ###
            # Creating experimental antibiotic and inducer media hash & antibiotic_inducer_matrix to associate to output item
            media_hash, experimental_media_matrix = experimental_media_hash_matrix(inducer_mat, experimental_antibiotic_mat)
            log_info 'experimental media matrix', experimental_media_matrix
            # Associate antibiotic_inducer_matrix to output item
            associate_to_item(out_collection, 'experimental_media_mat', experimental_media_matrix) # Associate to item in order to .get() in the next step
            
            # Directing tech to create experimental media
            creating_experimental_media(media_hash)
            
            # Delete stationary phase overnight plate
            in_collection.mark_as_deleted
            in_collection.save
            
            # cleaning up 
            show {
                title "Cleaning Up..."
                separator
                check "Before finishing protocol, take 96 Deep Well plate #{in_collection} and soak wells with diluted bleach."
                check "Put the <b>1M IPTG</b> & <b>1M Arabinose</b> stocks back into the 4°C fridge."
            }
        end
        
        # operations.store
        
        return {}
    end #main
    
    def intro()
        show do
            title "Introduction - Novel Chassis"
            separator
            note "In this portion of the workflow you will dilute stationary phase cultures in order to get cultures back into log phase."
            note "<b>1.</b> Fill dilution plates with media"
            note "<b>2.</b> Dilute stationary phase cultures"
            note "<b>3.</b> Incubate diluted plate in plate reader for 3 hours"
            note "<b>4.</b> Prepare induction media"
        end
    end
    
    def gather_materials()
        output_plates = operations.map {|op| op.output(OUTPUT).item.object_type.name}
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
    
    # Filling out_collection plate with media and displaying the collection to direct the tech
    #
    # @params op [operation obj] a single operation
    # @parms collection [collection obj] the collection that is being filled with media
    # @parms rc_list [2-D Array] is a matrix of the coordinates that a certain media should go into ie: [[no_anti_media_coordinates,'M9'], ... , [kan_chlor_coordinates, 'M9 + Kan + Chlor']]
    def fill_plate_with_media(op, collection, rc_list)
        count = 0
        rc_list.each { |media_coords, med_type|
            media_vol = ((media_coords.length + 2) * op.input(MEDIA_DILU_VOL).val.to_i)/1000#mL
            show {
                title "Filling #{Item.find(collection.id).object_type.name} #{collection.id}"
                separator
                (count == 0) ? (check "Obtain a <b>#{Item.find(collection.id).object_type.name}</b> and label with #<b>#{collection.id}</b>") : nil
                check "Aliquot <b>#{media_vol.round(2)}mL</b> of <b>#{med_type}</b> into a clean reservoir."
                note "Follow the table below to fill Deep Well plate #{collection.id} with <b>#{op.input(MEDIA_DILU_VOL).val.to_i}µl</b> the appropriate media:"
                table highlight_rc(collection, media_coords) {|r,c| med_type}
            }
            count += 1
        }
    end
    
    def transfer_cultures(op)
        show {
            title "Recovering Stationary Cultures"
            separator
            note "Transfer <b>#{op.input(CULT_DILU_VOL).val.to_i}µl</b> from plate <b>#{op.input(INPUT).collection.id}</b> to plate <b>#{op.output(OUTPUT).collection.id}</b>"
            bullet "<b>Maintain the same layout and order of the cultures!</b>"
        }
    end
    
    def experimental_media_hash_matrix(inducer_mat, experimental_antibiotic_mat)
        media_hash = Hash.new(0)
        experimental_media_matrix = [] # Combines antibiotic and inducer media strings to create a matrix that combines both medias
        inducer_mat.each_with_index { |row, r_idx|
            mat_row = []
            row.each_with_index { |col, c_idx|
                if col == "-1"
                    media = -1
                else
                    media = experimental_antibiotic_mat[r_idx][c_idx] + "_" + col
                end
                mat_row.push(media)
                if !media_hash.include? media
                    media_hash[media] = 1
                else
                    media_hash[media] += 1
                end
            }
            experimental_media_matrix.push(mat_row)
        }
       return media_hash, experimental_media_matrix 
    end
    
    
    # Creates experimental induction + antibiotic media for subsequent induction protocols
    def creating_experimental_media(media_hash)
        media_hash.each { |media, quant|
            log_info 'media', media
            if media != -1
                show {
                    title "Creating Experimental Induction Media"
                    separator
                    if media.include? 'Kan'
                        check "In an appropriate container, aliquot <b>#{(quant * 3.3).round(2)}mL</b> of <b>M9 + Kan Media</b> and label: <b>#{MEDIA_LABEL_HASH[media]}</b>"
                    else
                        check "In an appropriate container, aliquot <b>#{(quant * 3.3).round(2)}mL</b> of <b>M9 Media</b> and label: <b>#{MEDIA_LABEL_HASH[media]}</b>"
                    end
                    if media.include? 'IPTG'
                        check "To the tube labeled #{MEDIA_LABEL_HASH[media]}, add <b>#{(quant * 3.3 * 0.25).round(2)}µl</b> of <b>1M IPTG</b>" # calculates inducer per 1mL of media
                    end
                    if media.include? 'arab'
                        check "To the tube labeled #{MEDIA_LABEL_HASH[media]}, add <b>#{(quant * 3.3 * 25).round(2)}µl</b> of <b>1M Arabinose</b>" # calculates inducer per 1mL of media
                    end
                }
            end
        }
    end
    
    
    
    
end #Class
