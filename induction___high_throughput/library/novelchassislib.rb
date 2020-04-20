# By: Eriberto Lopez 06/13/18
# elopez3@uw.edu 

module NovelChassisLib
    
    MEDIA_LABEL_HASH = {
        'None'=>'M9',
        'Kan'=>'M9+Kan',
        'Kan_Chlor'=>'M9+Kan+Chlor',
        'None_None'=>'M9', 
        'None_arab_25.0'=>'M9 + Arab', 
        'Kan_None'=>'M9 + Kan', 
        "None_IPTG_0.25"=>'M9 + IPTG', 
        "None_IPTG_0.25|arab_25.0"=>'M9 + IPTG + Arab', 
        "Kan_IPTG_0.25"=>'M9 + Kan + IPTG',
        'Kan_arab_25.0'=>'M9 + Kan + Arab',
        'Kan_IPTG_0.25|arab_25.0'=>'M9+Kan + IPTG + Arab'
    }
    
    
    # Takes a 2-D array of medias from the experimental plan, finds the uniq media types, then finds the coordinates for each type of media. 
    # The output of this function will be used to display what kind of media should go into which well of a collection
    #
    # @params media_matrix [2-D Array] matrix that contains the name/idenitfier of the media that will be used in the portion of the experiment
    # @returns medias_rc_list [2-D Array] is a matrix of 'tuples' of the media_coordinates & the name/display string of the media 
    # ie: [[no_anti_media_coordinates,'M9'], ... , [kan_chlor_coordinates, 'M9 + Kan + Chlor']]
    def uniq_media_rc_lists(media_matrix)
        # Example
        # arr = ['x', 'o', 'x', '.', '.', 'o', 'x']
        # arr.each_index.select{|i| arr[i] == 'x'} # =>[0, 2, 6]        
        medias_rc_lists = []
        media_matrix.flatten.uniq.each { |med_type|
            if (med_type != "-1" && med_type != -1)
                media_coords_arr = []
                media_matrix.map.each_with_index { |row, r_idx|
                    col_idx = row.each_index.select {|well| row[well] == med_type }
                    col_idx.each {|c_idx| media_coords_arr.push([r_idx, c_idx])}
                }
                med_type = MEDIA_LABEL_HASH[med_type]
                medias_rc_lists.push([media_coords_arr, med_type])
            end
        }
        # desired output: [[no_anti_media_coordinates,'M9'], [kan_media_coordinates,'M9 + Kan'], [kan_chlor_coordinates, 'M9 + Kan + Chlor']]
        return medias_rc_lists
    end
    
    # Filling out_collection plate with media and displaying the collection to direct the tech
    #
    # @params op [operation obj] a single operation
    # @parms collection [collection obj] the collection that is being filled with media
    # @parms rc_list [2-D Array] is a matrix of the coordinates that a certain media should go into ie: [[no_anti_media_coordinates,'M9'], ... , [kan_chlor_coordinates, 'M9 + Kan + Chlor']]
    def fill_plate_with_media(collection, rc_list, well_vol=180)
        count = 0
        rc_list.each do |media_coords, med_type|
            media_vol = (media_coords.length + 2) * 0.2#mL
            show do
                title "Filling #{Item.find(collection.id).object_type.name} Plate #{collection.id}"
                separator
                (count == 0) ? (check "Obtain a <b>#{Item.find(collection.id).object_type.name}</b> and label with #<b>#{collection.id}</b>") : nil
                check "Aliquot <b>#{media_vol.round(2)}mL</b> of <b>#{med_type}</b> into a clean reservoir."
                note "Follow the table below to fill Deep Well plate with <b>#{well_vol}µl</b> the appropriate media:"
                table highlight_rc(collection, media_coords) {|r,c| med_type}
            end
            count += 1
        end
    end
    
    # Copies sample id matrix from one collection to another
    #
    # in_coll [collection obj] the collection from which the samp id matrix will be copied from
    # out_coll [collection obj] the collection to which the samp id matrix will be copied to
    def copy_samp_ids_to_coll(in_coll,out_coll)
        samp_id_matrix = in_coll.matrix
        out_coll.matrix = samp_id_matrix
        out_coll.save
    end

end # module