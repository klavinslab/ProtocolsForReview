# Transfer from 24-well plates to 96 well-plates (for flow cytometry or platereader)
# 4 24-well plates -> 1 96-well plate
# ok to batch:
# - each experiment is limited to 4 24-well plates.
# - each batch uses the same a single transfer, single dilution volume
# - each operation will be placed in a separate 96-well. 
# - coded so that 96-well plates are prepared sequentially, to avoid contamination between different experiments.
needs "Induction - High Throughput/HighThroughputHelper"
needs "Standard Libs/Debug"

class Protocol
    
  include HighThroughputHelper  
  include Debug
    
  IN_NAME="24 well plates"
  OUT_NAME="96 well plate"
  
  U_TYPE="96 U-bottom Well Plate"
  FLAT_TYPE="96 Well Flat Bottom (black)"
  
  TRANSFER_VOL="transfer volume (µL)"
  DILUTION_VOL="dilution volume (µL)"
  
  MAX_24_WELL=4 # max numer of 24 well plates for single 96 well plate, and for single operation
  # 24-well plate pp, column cc (4 wells) to be transfered to 96-well ROW_STR[pp][cc], COL_STR[pp][cc] (4 wells)
  ROW_STR=[[1,3,5,7],     [1,3,5,7],        [2,4,6,8],     [2,4,6,8]]        # for screen instructions
  COL_STR=[[1,2,3,4,5,6], [7,8,9,10,11,12], [1,2,3,4,5,6], [7,8,9,10,11,12]] # for screen instructions
  COL_NUM=6 # number of columns in 24-well plate
  
   def main

    # check <=4 24-well plates per operation
    operations.each { |op|
        if ( op.input_array(IN_NAME).length > MAX_24_WELL ) || (op.input_array(IN_NAME).empty?)
            op.error :wrongNumberOfPlates , 
            "Only 1-4 24-well plates per operation allowed, operation gave #{op.input_array(IN_NAME).length}"
        else
            operations.running.select { |o| o == op }.retrieve.make  # ugly code. make single operation==op
        end 
    }
     
    # count how many physical plates needed for each type
    u_bottom=0 # number of u-bottom 96-well plates
    flat_bottom=0 # number of flat-bottom 96-well plates
    operations.running.each { |op|
        u_bottom = u_bottom + (plate_type=op.output(OUT_NAME).object_type.name==U_TYPE ? 1 : 0)
        flat_bottom = flat_bottom + (plate_type=op.output(OUT_NAME).object_type.name==FLAT_TYPE ? 1 : 0)
    }
    
    # gather stuff for all operations (only if need > 0 of each)
    show do
        title "Gather the following items:"
        if(flat_bottom>0)
            check "#{flat_bottom} flat-bottom black 96-well plate(s)"
        end
        if(u_bottom>0)
            check "#{u_bottom} U-bottom 96-well plate(s)"
        end
        check "8-channel pippette"
        check "#{u_bottom+flat_bottom} aerated seal(s)" 
        check "1xPBS + Kan (2 mg/mL) containing at least #{20}mL"
    end
    
    # prepare odd-row-only tip boxes
    oddRowOnlyTips(2, 100)
        
    # get 24-well plates separately for each operation   
    operations.running.each.with_index  { |op, ii|  
        
        # start transfer
        show do
            title "Prepare 96-well plate"
            check "Take empty 96-well plate of type #{op.output(OUT_NAME).object_type.name}"   
            check "Label the plate #{op.output(OUT_NAME).item.id} + (your initials) + #{Time.zone.now.to_date}"
        end
        
       
        # may have 1-4 24-well plates here
        op.input_array(IN_NAME).item_ids.each.with_index { |id, jj|
            show do
                title "Transfer culture from 24-well plate to 96-well plate"
                check "Locate 24-well plate #{id}"
                check "Locate 96-well plate #{op.output(OUT_NAME).item.id}"
                warning "This transfer is one column at a time. Use 4 fresh tips for each column!"
            end 
            COL_NUM.times do |cc|
                show do
                    title "Transfer culture from 24-well plate to 96-well plate"
                    check "Load 4 100 µL tips from odd-only tip box on 8-channel pipette, on every other channel"
                    check "Transfer #{op.input(TRANSFER_VOL).val}µL from all wells in column <b>#{cc+1}</b> of 24-well plate #{id} to column <b>#{COL_STR[jj][cc]}</b>, rows #{ROW_STR[jj].join(' ')} of 96-well plate (see below)"
                    image "Actions/Induction_High_Throughput/24to96_plate#{jj+1}_cropped.jpg"
                    check "Trash tips"
                end
            end
            show do
                check "Move plate #{id} aside"
            end
        }
        
        show do
            title "Add media to 96-well plate"
            check "Pour PBS+Kan into a 25mL reservoir"
            check "Take a new box of 100 µL tips"
            warning "Add media, one column at a time. Use 8 fresh tips for each column! "
            check "Using the 8-channel pipette, add #{op.input(DILUTION_VOL).val} µL of PBS+Kan to all occupied wells of the 96-well plate #{op.output(OUT_NAME).item.id}"
            check "Cover plate #{op.output(OUT_NAME).item.id} with an aerated seal and label it: #{Time.zone.now.to_date}"
        end
        
        # copy info from 24-well collection(s) into 96-well collection
        #displayCollectionHash(op.output(OUT_NAME).collection, 'before transfer')
        transferWellInfo(op.input_array(IN_NAME).collections, op.output(OUT_NAME).collection)
        #displayCollectionHash(op.output(OUT_NAME).collection, 'after transfer')
        
        # associate time with it for cytometry precondition
        Item.find(op.output(OUT_NAME).collection.id).associate :incubationTime_hrs, 1 # one hour incubation time
        
        # 96 well location
        op.output(OUT_NAME).item.move('Bench') # incubation on bench
        
        # place plates back in shaker as temporary backup, to be trashed later
        op.input_array(IN_NAME).items { |plate|
            plate.move('Shaker')
            plate.save
        }
    
    } # operations.running.each
    
    # need parameter for this???
    # set 1-hr timer EXTERNAL to aquarium
    timer_link = 'https://www.google.com/search?q=timer+for+1+hour&oq=timer+for+1+hour&aqs=chrome..69i57j0l5.2200j0j7&sourceid=chrome&ie=UTF-8'
    show do
        title "Start 1-hour timer"
        note "Start a <a href=#{timer_link} target='_blank'>one-hour timer on Google</a>, and complete this protocol"
        note "When the timer stops, it will be time to measure the 96 well plate on the flow cytometer"
    end
    
    # store stuff
    operations.running.store
    
    return {}
    
  end

end

