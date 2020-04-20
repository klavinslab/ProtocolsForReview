# edited by SG for generalized gel
#
# gel type and percentage are associated with gel (collection)
# empty lanes depend on percentage:
#   0.8% - 2 empty lanes in each row (1kb and 100bp ladders)
#   2.0% - 1 empty lane  (100bp ladder)
#
# notes: 
# 1) 'Run Gel' should be able to identify empty lanes and place ladders accordingly
# 2) Preconditions extended to include 'Make qPCR Fragment'
needs "Standard Libs/SortHelper" # for sorting ops by media/container
needs "Standard Libs/AssociationManagement"

class Protocol
 
    include SortHelper, AssociationManagement
        
    # I/O
    PERCENTAGE="Percentage"
    TYPE="Gel Type"
    LANE="Lane"
    
    # gel lane stuff
    NUMBER_LANES_PER_GEL=12 
    NUMBER_ROWS=2
    DEFAULT_NUMBER_LADDERS=2
    LADDERS_IN_HIGH_PERCENTAGE_GEL=1 # THIS WAS REQUESTED BY LAB MANAGERS
    
    # gel components
    VOLUME = 50.0 # mL
    GEL_GREEN={name: "Gel Green", qty: 5, units: "µL"}
    TAE={name: "1xTAE", qty: 50, units: "mL"}
    
    def main
        
        # sort ops by gel type in preparation (1/2) for make
        ops_sorted = sortByMultipleIO(operations, ["in","in"], [TYPE,PERCENTAGE], [""], ["val","val"])
        operations = ops_sorted
        
        # insert virtual operations for ladders, unfilled gels, in preparation (2/2) for make
        gel_ops=[] # ops in current gel
        num_gels=0
        all_ops=[] # list of all operations (including virtual)
        number_ladders=0
        number_ops_per_gel=0
        number_ops_per_ladder=0
        operations.each_with_index { |op, i| 
            
            lastOp = (op==operations.last)
            
            if(gel_ops.length==0) # first op in gel
            
                gel_ops=[]
                gel_ops[0]=op 
                num_gels=num_gels+1
                # set gel lanes
                number_ladders = (op.input(PERCENTAGE).val.to_f==2.0) ? LADDERS_IN_HIGH_PERCENTAGE_GEL : DEFAULT_NUMBER_LADDERS
                number_ops_per_gel=(NUMBER_LANES_PER_GEL-NUMBER_ROWS*number_ladders).round
                number_ops_per_ladder=(number_ops_per_gel.to_f/NUMBER_ROWS).round
                
                show { 
                    title "DEBUGGING" 
                    note "type=#{op.input(TYPE).val}, percentage=#{op.input(PERCENTAGE).val}"
                    note "number_ladders=#{number_ladders}"
                    note "number_ops_per_gel=#{number_ops_per_gel}"
                    note "number_ops_per_ladder=#{number_ops_per_ladder}"
                } if debug
                 
                if(!lastOp) 
                    next
                end
                
            elsif( (gel_ops[-1].input(TYPE).val == op.input(TYPE).val) && 
                   (gel_ops[-1].input(PERCENTAGE).val == op.input(PERCENTAGE).val) ) # same gel, same percentage
                gel_ops=gel_ops.push(op) 
                newGel=0
                
            else # different type of gel
                newGel=1
            end
            
            if( ((gel_ops.length % (number_ops_per_gel))==0) || (newGel==1) || (lastOp) ) # need to "close" gel
                # insert virtual operations for ladders (at head of list)
                number_ladders.times do
                    all_ops = insert_op(all_ops, all_ops.length, VirtualOperation.new) 
                end
                # insert operations in first row
                gel_ops[0..([gel_ops.length,number_ops_per_ladder].min - 1)].each { |op|
                    all_ops = insert_op(all_ops, all_ops.length, op) 
                }
                # ladders - second row
                number_ladders.times do
                    all_ops = insert_op(all_ops, all_ops.length, VirtualOperation.new) 
                end
                # insert operations in second row
                if(gel_ops.length>number_ops_per_ladder)
                    gel_ops[number_ops_per_ladder..(number_ops_per_gel-1)].each { |op|
                        all_ops = insert_op(all_ops, all_ops.length, op) 
                    }
                end
                # pad unfilled gel with virtual operations (at tail of list)
                (number_ops_per_gel-gel_ops.length).times do 
                    all_ops = insert_op(all_ops, all_ops.length, VirtualOperation.new)
                end 
                # new gel
                gel_ops=[]
            end  
        } 
    
        # update operations and make
        operations=all_ops
        operations.extend(OperationList)
        operations.make
        display_collections(operations) if debug
        
        # pour gels
        operations.output_collections[LANE].each_with_index { | coll, i | 
                
            op=operations.select{ |op| !(op.virtual?) }.select{|op| op.output(LANE).collection==coll}.first
            gel_percentage=(op.input(PERCENTAGE).val).to_f
            gel_type=op.input(TYPE).val
            
            # associate type to collection
            assoc = AssociationMap.new(coll)
            assoc.put("percentage", gel_percentage)
            assoc.put("gel_type", gel_type) 
            assoc.save
                
            mass = (0.01*gel_percentage*VOLUME).round(2)
            error = (mass*0.05).round(5) 
            
            num_gels=operations.output_collections[LANE].length
                
            show do
                title "Prepare gel #{i+1} of #{num_gels}"
                check "Grab a flask from on top of the microwave M2."
                check "Using a digital scale, measure out #{mass} g (+/- #{error} g) of #{gel_type} agarose powder and add it to the flask."
                check "Get a graduated cylinder from on top of the microwave. Measure and add #{TAE[:qty]} #{TAE[:units]} of #{TAE[:name]} from jug J2 to the flask."
                check "Microwave 70 seconds on high in microwave M2, then swirl. The agarose should now be in solution."
                note "If it is not in solution, microwave 7 seconds on high, then swirl. Repeat until dissolved."
                warning "Work in the gel room, wear gloves and eye protection all the time"
            end
        
            show do
                title "Add #{GEL_GREEN[:name]} to gel #{i+1} of #{num_gels}"
                note "Using a 10 L pipetter, take up #{GEL_GREEN[:qty]} #{GEL_GREEN[:units]} of #{GEL_GREEN[:name]} into the pipet tip. Expel the #{GEL_GREEN[:name]} directly into the molten agar (under the surface), then swirl to mix."
                warning "#{GEL_GREEN[:name]} is supposedly safe, but stains DNA and can transit cell membranes (limit your exposure)."
                warning "#{GEL_GREEN[:name]} is photolabile. Limit its exposure to light by putting it back in the box."
                # image "gel_add_gelgreen"
            end
            
            show do
                title "Gel Number #{i + 1} of #{num_gels}, add top comb"
                check "Go get a 49 mL Gel Box With Casting Tray (clean)"
                check "Retrieve a 6-well purple comb from A7.325"
                check "Position the gel box with the electrodes facing away from you. Add a purple comb to the side of the casting tray nearest the side of the gel box."
                check "Put the thick side of the comb down."
                note "Make sure the comb is well-situated in the groove of the casting tray."
            end
            
            show do
                title "Gel Number #{i + 1} of #{num_gels}, add bottom comb"
                check "Retrieve a 6-well purple comb from A7.325"
                check "Position the gel box with the electrodes facing away from you. Add a purple comb to the center of the casting tray."
                check "Put the thick side of the comb down."
                note "Make sure the comb is well-situated in the groove of the casting tray."
                # image "gel_comb_placement"
            end
            
            show do
                title "Pour and label the gel #{i+1} of #{num_gels}"
                note "Using a gel pouring autoclave glove, pour agarose from one flask into the casting tray. 
                          Pour slowly and in a corner for best results. Pop any bubbles with a 10 uL pipet tip."
                note "Write <b>#{coll.id} #{gel_percentage}% #{gel_type}</b> on piece of lab tape and affix it to the side of the gel box."
                note "Leave the gel to location A7.325 to solidify."
                # image "gel_pouring"
            end
        
        }
        
        # store
        colls=operations.select{ |op| !(op.virtual?) }.map{|op| op.output(LANE).collection }.uniq
        release(colls, interactive: true)
        
        return {}
        
    end

    #-----------------------------------------------------------------------
    
    def insert_op(ops, index, element)
        #show { note "BEFORE INSERT ops=#{ops.length}: #{ops.map {|op| op.id}.to_sentence}" }
        index=[0,index].max
        index=[index,ops.length].min
        before = ops[0,index] || []
        after = ops[index,ops.length-index] || []
        ops = before + [element] + after
        #show {note "AFTER INSERT ops=#{ops.length}: #{ops.map {|op| op.id}.to_sentence}" } 
        return ops
    end

    def display_collections(ops)
        show {
            title "Output display"
            note "ops=#{ops.length}: #{ops.map {|op| op.id}.to_sentence}" 
            table ops.start_table
                .output_collection(LANE, heading: "TEST")
                .output_row(LANE)
                .output_column(LANE)
                .custom_column(heading: "op id") { |op| op.virtual? ?  0 : op.id  }
                .custom_column(heading: "% agarose") { |op| op.virtual? ?  0 : op.input(PERCENTAGE).val  }
                .custom_column(heading: "gel type", type: "string") { |op| op.virtual? ?  "-" : op.input(TYPE).val  }
                .end_table
        }
    end

end