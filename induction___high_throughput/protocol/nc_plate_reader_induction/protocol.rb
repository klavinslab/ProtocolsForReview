# By: Eriberto Lopez
# elopez3@uw.edu
# °C µl
# P.1	Prepare 96_flat_3* with 192.4 µL media
# P.2	Prepare 96_flat_4* with 191.2 µL media + inducers
# P.3	Stamp 7.6 µL from 96_deep_2 into 96_flat_3
# P.4	Stamp 8.8 µL from 96_flat_3 into 96_flat_4
# P.5	Add 200 µL media blanks to 4 wells of 96_flat_4 in column 12
# P.6	Incubate 96_flat_4 with low-evaporation lid in platereader for __ h at 30/37C, shaking 3mm double orbital at 282 cpm and reading abs600 and ex488em530, with a bandpass of 30 if available
# with timepoints being taken every 10 mins

needs "Standard Libs/Debug"
needs "YG_Harmonization/Upload_PlateReader_Data"
needs "YG_Harmonization/PlateReaderMethods"
needs "Tissue Culture Libs/CollectionDisplay"
needs "Induction - High Throughput/NovelChassisLib" # Temporary EL
needs "Plate Reader/PlateReaderHelper"


class Protocol
    
    include Debug
    include Upload_PlateReader_Data
    include PlateReaderMethods
    include CollectionDisplay
    include NovelChassisLib
    include PlateReaderHelper
    
    #I/O
    INPUT = "96 Deep Well plate"
    OUTPUT = "96 Well Flat Bottom"
    
    # Parameters
    GROWTH_TEMP = "Growth Temperature (°C)"
    
    # Constants
    FIRST_DILU_MED_VOL = 192.4#µl
    FIRST_DILU_CULT_VOL = 7.6#µl
    SEC_DILU_MED_VOL = 191.2#µl
    SEC_DILU_CULT_VOL = 8.8#µl
    
    PLATE_READER_TEMPLATE = {37=>"novel_chassis_20hr_outgrowth"} # outgrowth time dependent on incubation temperature

    def main
        
        operations.make
        
        intro()
        
        operations.each { |op|
            # gather materials
            gather_materials(op)
            
            # Prepare 96 flat first dilution
            prep_first_dilution_plate(op)
            
            # Prepare 96 flat output 
            plate_reader_induction(op)
            
            # First dilution
            dilution_transfer(input_plate=op.input(INPUT).collection.id, diluted_plate='First Dilution', transfer_vol=FIRST_DILU_CULT_VOL)
            
            # Place input plate back into incubator
            release [op.input(INPUT).item], interactive: true
            
            # Second dilution
            dilution_transfer(input_plate='First Dilution', diluted_plate=op.output(OUTPUT).collection.id, transfer_vol=SEC_DILU_CULT_VOL)
            
            # Adding blanks before we transfer plate to plate reader
            type_of_media = 'M9'
            tot_vol = SEC_DILU_MED_VOL + SEC_DILU_CULT_VOL
            out_collection = op.output(OUTPUT).collection
            add_blanks(collection=out_collection, type_of_media=type_of_media, tot_vol=tot_vol, blank_wells=nil)
            
            # Setup plate reader for time series experiment; time based on growth temperature
            timeseries_filename = set_up_plate_reader(out_collection, PLATE_READER_TEMPLATE[op.input(GROWTH_TEMP).val.to_i])
            
            # Associate timeseries filename to save and upload when time course is finished
            Item.find(out_collection.id).associate('timeseries_filename', timeseries_filename)
            
            out_collection.location = "BioTek Plate Reader"
            out_collection.save
            release [Item.find(out_collection.id)], interactive: false
        }
        
        # operations.store # Already released items in protocol
        
        return {}
        
    end # Main


    def intro()
        show {
            title "Introduction - Plate Reader Induction"
            separator
            note "In this experiment you will dilute cultures into experimental induction media, before loading the plate onto the plate reader."
            note "<b>1.</b> Pre-fill plates with experimental induction media."
            note "<b>2.</b> Dilute cultures."
            note "<b>3.</b> Load plate onto plate reader."
        }
    end
    
    def gather_materials(op)
        if debug
            experimental_media_mat = Item.find(271082).get('experimental_media_mat')
        else
            experimental_media_mat = op.input(INPUT).item.get('experimental_media_mat')
        end
        medias_rc_lists = uniq_media_rc_lists(experimental_media_mat)
        show {
            title "Gather Materials"
            separator
            note "Grab the following materials for this expeiment:"
            check "<b>2</b> #{op.output(OUTPUT).item.object_type.name} plate(s)"
            check "The following medias:"
            medias_rc_lists.each {|rc_list, med_type|
                bullet "Media: <b>#{med_type}</b>"
            }
        }
    end

    def prep_first_dilution_plate(op)
        # samp_id_matrix = op.input(INPUT).collection.matrix
        plate = op.output(OUTPUT)
        copy_samp_ids_to_coll(op.input(INPUT).collection,op.output(OUTPUT).collection)
        # plate.collection.matrix = samp_id_matrix
        # plate.collection.save
        type_of_media = 'M9'
        show {
            title "Filling First Dilution #{plate.item.object_type.name} Plate"
            separator
            check "Gather a <b>#{plate.item.object_type.name}</b> and label it: <b>'First Dilution'</b>"
            note "Follow the table below to fill the correct wells with <b>#{FIRST_DILU_MED_VOL}µl</b> of media."
            table highlight_non_empty(plate.collection) {|r,c| "#{type_of_media}"}
        }
    end
    
    # Gets the associated experimental media matrix (inducer+antibiotic) matrix, finds unique media types and collects positions of media in collection, then displays where each media should go into collection
    def plate_reader_induction(op)
        if debug
            experimental_media_mat = Item.find(271082).get('experimental_media_mat')
        else
            experimental_media_mat = op.input(INPUT).item.get('experimental_media_mat')
        end
        
        out_collection = op.output(OUTPUT).collection
        medias_rc_lists = uniq_media_rc_lists(experimental_media_mat)
        fill_plate_with_media(out_collection, medias_rc_lists, well_vol=SEC_DILU_MED_VOL)
        # Associate inducer+antibiotic matrix to item
        associate_to_item(out_collection, 'experimental_media_mat', experimental_media_mat)
    end
    
    
    # Directs tech to dilute cultures by transferring culture from one plate to another
    #
    # @parmas input_plate [string] either the name or the id of the plate that culture will be taken from
    # @parmas diluted_plate [string] either the name or the id of the plate that the culture will be diluted into
    # @parmas transfer_vol [integer] the volume of culture that will be tranferred from the input_plate to the diluted_plate
    def dilution_transfer(input_plate, diluted_plate, transfer_vol)
        show {
            title "Tranferring and Diluting Cultures for Plate Reader"
            separator
            check "From plate <b>#{input_plate}</b> transfer <b>#{transfer_vol}µl</b> of culture to the plate labeled => <b>#{diluted_plate}</b>"
        }
    end

end # Class
