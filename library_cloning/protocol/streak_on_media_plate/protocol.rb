# SG
# enables streaking on plates with specified media types
#
# TO DO: delete empty collections (ala mark_as_deleted)
needs "Standard Libs/SortHelper" # for sorting ops by media/container

class Protocol
    
    include SortHelper 
    
    # I/O
    IN_STRAIN="Yeast Strain"
    IN_MEDIA="Media"
    OUT_PLATE="Streak Plate"
    
    # other
    PLATE_LOCATION="30 C incubator"
    STREAKS_PER_PLATE=4
    YGS = "Yeast Glycerol Stock" 
    
    def main
        
        # check plates for each media type, error relevant number of operations if do not have enough plates
        # sorting by media for consistent order in displays 
        ops_sorted_by_media = sortByMultipleIO(operations, ["in"], [IN_MEDIA], [""], ["val"]) 
        media_types = ops_sorted_by_media.map { |op| op.input(IN_MEDIA).val }
        media_types=media_types.uniq
        plates_hashes = Hash.new()
        media_types.each { |m|
            ops = operations.select { |op| op.input(IN_MEDIA).val == m } 
            plates_hashes[m] = get_plates(ops.length, m) 
            if(plates_hashes.fetch("#{m}").fetch("num_unplated") > 0) # not enough plates
                plates_hashes.fetch("#{m}").fetch("num_unplated").times { |i|
                    ops[i].error :no_plate, "There were not enough #{m} plates for this Streak Plate operation." 
                }
            end
        }
        
        # sort running operations for convenience in make, numbering, display later on: media, followed by container type
        ops_r = operations.running
        if(ops_r.empty?)
            show {
                title "No operations running"
                note "There are no items to streak, possibly because there were no plates of the selected Media types. Please check."
            } 
            return
        end
        
        ops_r = sortByMultipleIO(ops_r, ["in", "in"], [IN_MEDIA, IN_STRAIN], ["","object_type"], ["val", "item"])
        # make - each (up to) 4 ops with the same media are made separately!!! otherwise output plates are mixed-media
        plates_hashes.each { |m, ph|  
            m_ops = ops_r.select {|op| op.input(IN_MEDIA).val == m}
            m_ops.in_groups_of(STREAKS_PER_PLATE, false).each { |subarray|
                m_subops = ops_r.select { |op| subarray.include? op }
                m_subops.make
            }
        }
        
        # grab plates for operations
        tab = Array.new(){ Array.new() } # for show
        tab[0] = ["Batch ID","Media","number of plates"] # header
        line_ind = 1
        plates_hashes.each { |m, ph|  
            ph.fetch("batches").each_with_index { |b, i|
                out_plates=Array.new()
                tab[line_ind]=[ b.to_s, m , ph.fetch("plates_from_batch")[i].to_s]
                line_ind += 1
            }
        }
        show do 
            title "Grab plates"
            note "Grab the following plate(s) from the listed plate batches, located in #{PLATE_LOCATION}:"
            table tab
        end
        
        # label plates and associate media to plates
        tab = Array.new(){ Array.new() } # for show
        tab[0] = ["Plate ID","Media"] # header
        line_ind = 1
        plates = ops_r.map { |op| op.output(OUT_PLATE).item.id } 
        plate_media = ops_r.map { |op| op.input(IN_MEDIA).val } 
        plates.each_with_index { |pl, i|
            if(i > 0)
                if(plates[i]==plates[i-1])
                    next
                end
            end
            tab[line_ind]=[plates[i], plate_media[i]]   
            Item.find(plates[i]).associate :"media", plate_media[i] 
            line_ind += 1
        }
        show do
            title "Label plates"
            table tab
            note "Divide each plate into four sections and mark each section from 1-#{STREAKS_PER_PLATE}"
            note "Leave plate(s) on bench until dried so streaking is easier"
            note "" # blank line
        end
        
        # streak intro
        show do
            title "Intro to Streaking"
            note "After the plate(s) have been dried, streak them out by lightly moving a pipette tip
                back and forth across the agar. Make sure to angle the pipette tip correctly so you 
                don't puncture the agar."
            image "streak_yeast_plate_video"
        end
    
        # streak plates - from glycerol stocks
        gs = ops_r.select {|op| op.input(IN_STRAIN).item.send("object_type").name == YGS}
        if(gs.any?)
            show do
                title "Inoculation from glycerol stock in M80 area"
                warning "Work quickly with glycerol stocks and return to M80 immediately when finished"
                check "Go to M80 area, clean out the pipette tip waste box, clean any mess that remains there"
                check "Put on new gloves, and bring a new tip box (green: 10 - 100 µL), a pipettor (10 - 100 µL), and an Eppendorf tube rack to the M80 area"
                check "Grab plate(s) #{gs.map { |op| op.output(OUT_PLATE).collection.id}.uniq.to_sentence} and go to M80 area to perform the streak step"
            end
            show do 
                title "Streak plates from glycerol stocks"
                note "Streak according to the following table:"
                table gs.start_table
                    .output_collection(OUT_PLATE, heading: "Divided Yeast Plate ID")
                    .custom_column(heading: "Location on plate") { |op| op.output(OUT_PLATE).column + 1 }
                    .custom_column(heading: "Media") { |op| op.input(IN_MEDIA).val }
                    .custom_column(heading: "Input ID") { |op| op.input(IN_STRAIN).item.to_s }
                    .custom_column(heading: "Freezer Box Slot") { |op| op.input(IN_STRAIN).item.location }
                    .end_table
                warning "Be cautious about your sterile technique"
                note "Grab one glycerol stock at a time out of the M80 freezer and place in the tube rack"
                note "Use a sterile 100 µL tip with the pipettor and carefully scrape a half-pea-sized chunk of glycerol stock"
                note "Place the chunk about 1 cm away from the edge of the yeast plate agar section"
            end
        end
        
        # streak plates - from non-glycerol stocks
        ngs = ops_r.select {|op| op.input(IN_STRAIN).item.send("object_type").name != YGS }
        if(ngs.any?)
            ngs.retrieve
            show do 
                    title "Streak plates from non-glycerol stock sources"
                    note "Streak according to the following table: "
                    table ngs.start_table
                          .output_collection(OUT_PLATE, heading: "Divided Yeast Plate ID")
                          .custom_column(heading: "Location") { |op| op.output(OUT_PLATE).column + 1 } 
                          .custom_column(heading: "Media") { |op| op.input(IN_MEDIA).val }
                          .custom_column(heading: "Input ID") { |op| op.input(IN_STRAIN).item.to_s }
                          .custom_column(heading: "Container type") { |op| op.input(IN_STRAIN).item.send("object_type").name }
                          .end_table
            end
        end
        
        # set location of output plates
        ops_r.each { |op|
            op.output(OUT_PLATE).item.update_attributes(location: PLATE_LOCATION)
        }
        # store output plates
        operations.store(io: "output", interactive: true)
        # store non-glycerol stock input items
        if(ngs.any?)
            ngs.store(io: "input", interactive: true)
        end 
        
        return {}
    
    end # main
     
    #-----------------------------------------------------------------------------
    # get plates
    # delete plates that will be grabbed from collection
    # 
    # input: ops_len, number of operations that will be streaked on media
    #        mediaStr - string describing media to streak on
    # return: hash with keys "num_unplated" - integer, number of ops that cannot be plated due to lack of plates
    #                        "batches" - array of collections, which plate batches to take from 
    #                        "plates_from_batch" - array, how many plates to take from batch (same order)
    #-----------------------------------------------------------------------------
    def get_plates(ops_len, mediaStr)
        
        still_need=(ops_len.to_f/STREAKS_PER_PLATE).ceil
        batches = Array.new
        plates_from_batch = Array.new
        hash = { "num_unplated" => ops_len, "batches" => batches, "plates_from_batch" => plates_from_batch }
        
        # find media
        m = Sample.find_by_name(mediaStr)
        if(m.nil?)
            return hash
        end
        
        # see if have enough plates of this media, delete plates that will be used from collection
        num_plates=0
        none_left=0
        batch=nil
        
        loop do
            
            # stopping condition: have enough plates, or no plates left
            break if ( (still_need<=0) || (none_left==1) )
            
            # need a new agar plate batch
            if(!batch)
                batch = Collection.where(object_type_id: ObjectType.find_by_name("Agar Plate Batch").id).select { |b| b.matrix[0].include? m.id }.first 
            end
            if( (batch.nil?) || (batch.get_non_empty.length==0) )
                none_left=1
                next
            end
            
            # have plates in batch
            batches.push(batch)
            plates_in_batch = (batch.get_non_empty).length 
            num_plates = num_plates + plates_in_batch
            still_need = still_need - plates_in_batch # negative if we have more than we need
            
            # delete used plates
            if(still_need>=0) # delete entire batch
                #batch.mark_as_deleted # this does not work
                dims = batch.dimensions
                batch.matrix =  Array.new(dims[0]){Array.new(dims[1],-1)}  # empty all items
                batch.save
                batch=nil # for loop
                plates_from_batch.push(plates_in_batch)
            else # delete one by one (kinda primitive)
                (plates_in_batch + still_need).times {
                    batch.subtract_one nil, reverse: true                
                }
                plates_from_batch.push(plates_in_batch + still_need)
                num_plates = num_plates + still_need
            end

        end # loop
    
        hash = { "num_unplated" => [(ops_len - STREAKS_PER_PLATE*num_plates), 0].max, "batches" => batches, "plates_from_batch" => plates_from_batch }
        return hash
        
    end # def
    
end # protocol