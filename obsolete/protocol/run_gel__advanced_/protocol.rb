# edited by SG for generalized gel
#
# gel type and percentage are associated with gel (collection)
# empty lanes depend on percentage:
#   0.8% - 2 empty lanes in each row (1kb and 100bp ladders)
#   2.0% - 1 empty lane  (100bp ladder)
# NOTE: Run gel should be able to identify empty lanes ans place ladders accordingly!!! 
class Protocol
    
    # I/O
    GEL="Gel" # gel lane 
    FRAGMENT="Fragment"
    
    # other
    LADDER_100BP="100 bp Ladder"
    LADDER_1KB="1 kb Ladder"
    LOADING_DYE="6X Loading Dye"
    DEFAULT_PERCENTAGE=0.8
    HIGH_PERCENTAGE=2.0
    LADDER={qty: 10, units: "µL"}
    DYE={qty: 10, units: "µL"}
    TIME={qty: 40, units: "min"}
    VOLTAGE={qty: 80, qty: "units"}
    DEFAULT_PERCENTAGE=0.8
    DEFAULT_TYPE="regular"
    
    def main
      
        # sort inputs and reassign gel lanes       
        arrange_gels_by_stripwells operations.reject { |op| op.virtual? }
    
        # No make! Place output collection part in the input collection, at the input part (row,col)  
        operations.each do |op|
            op.output(FRAGMENT).make_part(
                op.input(GEL).collection,
                op.input(GEL).row,
                op.input(GEL).column
            )
        end
        
        # get stuff
        gels = operations.map { |op| op.input(GEL).collection }.uniq
        stripwells = operations.map { |op| op.input(FRAGMENT).collection }.uniq.sort { |sw1, sw2| sw1.id <=> sw2.id } 
        dye = Item.where(sample_id: (Sample.find_by_name(LOADING_DYE)).id).reject! { |i| i.deleted? }.first 
        ladder_100 = Sample.find_by_name(LADDER_100BP).in("Ladder Aliquot").first
        ladder_1K = nil
        items = [dye, ladder_100]
        # 1K ladder if needed
        need_1K = gels.map { |gel| (gel[:percentage] || DEFAULT_PERCENTAGE) < HIGH_PERCENTAGE }.include?(true)
        if(need_1K)
            ladder_1K = Sample.find_by_name(LADDER_1KB).in("Ladder Aliquot").first
            items.push(ladder_1K)
        end
        take items + gels.collect { |i| Item.find_by_id(i.id) } + stripwells.collect { |i| Item.find_by_id(i.id) }, interactive: true
        
        show do
            title "Set up the power supply"
            note  "In the gel room, obtain a power supply and set it to #{VOLTAGE[:qty]} #{VOLTAGE[:units]} and with a #{TIME[:qty]} #{TIME[:units]} timer."
            note  "Attach the electrodes of an appropriate gel box lid from A7.525 to the power supply."
            image "Items/gel_power_settings.JPG" 
        end
        
         show do
            title "Set up the gel box(s)"
            check "Remove the casting tray(s) (with gel(s)) and place it(them) on the bench."
            check "Using the graduated cylinder at A5.305, fill the gel box(s) with 200 mL of 1X TAE from J2 at A5.500. TAE should just cover the center of the gel box(s)"
            check "With the gel box(s) electrodes facing away from you, place the casting tray(s) (with gel(s)) back in the gel box(s). The top lane(s) should be on your left, as the DNA will move to the right."
            check "Using the graduated cylinder, add 50 mL of 1X TAE from J2 at A5.500 so that the surface of the gel is covered."
            check "Remove the comb(s) and place them in the appropriate box(s) in A7.325."
            check "Put the graduated cylinder back at A5.305."
            image "Items/gel_fill_TAE_to_line.JPG"
        end
        
        gels.each do |gel|
            gel.set 0,0, ladder_100.id
            gel.set 1,0, ladder_100.id
            if( (gel[:percentage] || DEFAULT_PERCENTAGE) >= HIGH_PERCENTAGE ) # 1Kb ladder not needed
                gel.set 0,1,ladder_1k.id
                gel.set 1,1, ladder_1k.id
            end
            show do
                title "Add Ladder(s) to Gel"
                note "Pipette #{LADDER[:qty]} #{LADDER[:units]} of #{LADDER_100BP} (#{ladder_100}) to positions (1,1) and (2,1) of gel #{gel}"
                if( (gel[:percentage] || DEFAULT_PERCENTAGE) >= HIGH_PERCENTAGE )
                    note "Pipette #{LADDER[:qty]} #{LADDER[:units]} of #{LADDER_1KB} (#{ladder_1K}) to positions (1,2) and (2,2) of gel #{gel}"
                end
            end
        end
        
        show do 
            title "Add Dye to Each Well"
            stripwells.each do |s|
                note "Add #{DYE[:qty]} #{DYE[:units]} #{LOADING_DYE} (#{dye}) to stripwell #{s} from wells #{s.non_empty_string}" 
            end
        end
       
        show do 
            title "Transfer the entire contents of each PCR reaction into indicated gel lane"
            note "Transfer samples from each stripwell to the gel(s) according to the following table:"
            table operations.reject { |op| op.virtual? }.sort { |op1, op2| op1.input(FRAGMENT).item.id <=> op2.input(FRAGMENT).item.id }.extend(OperationList).start_table
                .input_collection(FRAGMENT, heading: "Stripwell")
                .custom_column(heading: "Well Number") { |op| (op.input(FRAGMENT).column + 1)  }
                .input_collection("Gel", heading: "Gel")
                .custom_column(heading: "Gel Row") { |op| (op.input(GEL).row + 1) }
                .custom_column(heading: "Gel Column", checkable: true) { |op| (op.input(GEL).column + 1) }
            .end_table
        end
        
        show do
            title "Start Electrophoresis"
            note "Carefully attach the gel box lid(s) to the gel box(es), being careful not to bump the samples out of the wells. Attach the red electrode to the red terminal of the power supply, and the black electrode to the neighboring black terminal. Hit the start button on the gel boxes - usually a small running person icon."
            note "Make sure the power supply is not erroring (no E* messages) and that there are bubbles emerging from the platinum wires in the bottom corners of the gel box."
            image "gel_check_for_bubbles"
        end
        
        show do 
            title "Discard Stripwells"
            note "Discard all the empty stripwells"
        end
        operations.each do |op|
            op.input(FRAGMENT).item.mark_as_deleted
        end
        
        show do
            title "Set a timer" 
            check "When you get back to your bench, set a #{TIME[:qty]} #{TIME[:units]} timer." 
            check "When the timer is up, grab a lab manager to check on the gel. The lab manager may have you set another timer after checking the gel."
        end
        
        release items, interactive: true
        
        return {}
    
    end
    
    #---------------------------------------------------------------------------------------------------
  
    # reassigns gel lanes to make tables nicer
    # retains grouping according to gel type
    def arrange_gels_by_stripwells(mixed_ops)
        
        # group operations by gel type, percentage
        ops_hash = group_ops_by_gel(mixed_ops)
        
        # for each gel type, reassign lanes to operations
        ops_hash.each { |gt, ops| 
            # get fragment collections, give each well a serial index
            stripwells = ops.map { |op| op.input(FRAGMENT).collection }.uniq.sort { |sw1, sw2| sw1.id <=> sw2.id }
            sw_size = stripwells.first.object_type.columns
            wells = ops.map do |op|
                sw_offset = stripwells.index(op.input(FRAGMENT).collection) * sw_size
                op.temporary[:sw_val] = sw_offset + op.input(FRAGMENT).column
            end
            show { note "wells #{wells}" } if debug
            
            # get gel collections, give each lave a serial index
            gels = ops.map { |op| op.input(GEL).collection }.uniq.sort { |g1, g2| g1.id <=> g2.id }
            gel_size = gels.first.object_type.rows * gels.first.object_type.columns
            gel_columns = gels.first.object_type.columns
            lanes = ops.map do |op| 
                gel_offset = gels.index(op.input(GEL).collection) * gel_size
                row_offset = op.input(GEL).row * gel_columns
                gel_offset + row_offset + op.input(GEL).column
            end
            show { note "lanes #{lanes}" } if debug
            
            # sort lanes by stripwells
            wells_sorted = wells.sort
            lanes_sorted = lanes.sort
            well_to_lane = lanes_sorted.each_with_index.each_with_object({}) do |(l, i), hsh|
            	hsh[wells_sorted[i]] = l
            end
            show { note "well_to_lane #{well_to_lane.to_s}" } if debug
            
            lanes_ordered_by_well = wells.map { |well| well_to_lane[well] }
            show { note "lanes_ordered_by_well #{lanes_ordered_by_well}" } if debug
            
            # associate fragment parts with gel parts
            ops.each_with_index do |op, idx|
                gel_idx = lanes_ordered_by_well[idx] / gel_size # which gel
                lane = lanes_ordered_by_well[idx] - gel_idx * gel_size # which index within gel (1-8)
                row = lane / gel_columns 
                column = lane % gel_columns
                
                gel_fv = op.input(GEL) # assign new gel collection, row, column to this operation
                gel_fv.set collection: gels[gel_idx]
                gel_fv.row = row  
                gel_fv.column = column
                gel_fv.save
            end
        }
    end
    
    # group operations by gel [percentage, type]
    def group_ops_by_gel(ops)
        gel_types=ops.map { |op| 
            [(op.input(GEL).item.get(:percentage) || DEFAULT_PERCENTAGE), (op.input(GEL).item.get(:type) || DEFAULT_TYPE)] 
        }.uniq
        show { note "gel_types=#{gel_types}" } if debug
        ops_hash = Hash.new()
        gel_types.each { |m|
            ops_match = ops.select { |op| 
            [(op.input(GEL).item.get(:percentage) || DEFAULT_PERCENTAGE), (op.input(GEL).item.get(:type) || DEFAULT_TYPE) ] == m 
            } 
            ops_hash[m] = ops_match 
        }
        ops_hash
    end # def

end
