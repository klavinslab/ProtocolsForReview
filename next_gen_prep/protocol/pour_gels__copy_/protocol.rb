# SG
# this version is for advanced prep of multiple gels.
# array output length determines how many of the indicated (type,percentage) gels will be poured.
# all info regarding ladders is in "Run Pre-poured Gel" protocol.
needs "Standard Libs/SortHelper" # for sorting ops by media/container

class Protocol

    include SortHelper  
  
    # I/O
    PERCENTAGE="Percentage"
    TYPE="Gel Type"
    GEL="Gel (array)"
  
    # params
    GEL_VOL={qty: 50.0, units: "mL"}  
    GEL_GREEN={name: "Gel Green",qty: 5.0, units: "L"}   
    TAE={name: "1xTAE", qty: 50, units: "mL"}
    COMB_TYPE="thick" # "thick" or "thin"
    MICROWAVE_TIME={qty: 30, units: "sec"} 
    GEL_LOCATION="Gel Room"
    GEL_COLLECTION="50 mL Agarose Gel in Gel Box" # collection object used for outputs
    AGAROSE="Agarose Gel" # sample with which empty gel is populated so that it will appear in inventory
  
    def main
    
        # sort ops by gel type, percentage
        ops_sorted = sortByMultipleIO(operations, ["in","in"], [TYPE,PERCENTAGE], ["",""], ["val","val"]) 
        operations = ops_sorted
        # NO MAKE! need to produce new collection(s)
        
        # get sample ID of agarose gel
        sid = Sample.find_by_name(AGAROSE).id
        show { note "sid=#{sid}" } if debug
        # make collections and populate collections with "Agarose Gel" BEFORE labeling gels
        operations.each { |op|
            op.output_array(GEL).each { |out|        
                object_type = ObjectType.find_by_name(GEL_COLLECTION)
                new_item = produce new_collection object_type.name 
                new_item.matrix = Array.new(object_type.rows) { Array.new(object_type.columns) { sid } }
                new_item.save
                out.set item: new_item
                # associate gel type, percentage, location
                out.item.associate :percentage, op.input(PERCENTAGE).val
                out.item.associate :type, op.input(TYPE).val 
                out.item.location=GEL_LOCATION
            }
        }
        
        # display how many gels will be made today
        tot_gels=0
        tab=[]
        tab[0]=["Gel Percentage","Agarose Type","Number of Gels"]
        gel_hash = group_ops_by_gel(operations)
        gel_hash.each_with_index { |(gel,ops),i|
            num_gels = ops.map { |op| op.output_array(GEL).length }.sum
            tab[i+1]=["#{gel[0].round(1)}",gel[1],num_gels]
            tot_gels=tot_gels+num_gels
        }
        show {
            title "You will prepare the following #{tot_gels} gels"
            table tab
        }
        
        # loop over seperate "pour gel"s
        operations.each { |op|
            op.output_array(GEL).collections.each_with_index { |it,i|
                mass = ( ((op.input(PERCENTAGE).val.to_f)/100) * GEL_VOL[:qty]).round(2) # g
                error = ( mass * 0.05 ).round(5) # allowed error in g is +/- 5%
                add_combs(i+1,tot_gels)
                pour_gel(mass,error,op.input(TYPE).val,i+1,tot_gels)
                add_gel_green(i+1,tot_gels)
                label_gel(it,op.input(TYPE).val,op.input(PERCENTAGE).val,i+1,tot_gels)
            }
        }
        
        return {}
     
    end
    
    #-----------------------------------------------------------------------------------------------------------
    
    # group operations by gel [percentage, type]
    def group_ops_by_gel(ops)
        gel_types=ops.map { |op| [op.input(PERCENTAGE).val.to_f, op.input(TYPE).val] }.uniq
        show { note "gel_types=#{gel_types}" } if debug
        ops_hash = Hash.new()
        gel_types.each { |m|
            ops_match = ops.select { |op| [op.input(PERCENTAGE).val.to_f, op.input(TYPE).val] == m } 
            ops_hash[m] = ops_match 
        }
        ops_hash
    end 
    
    # pour gel
    def pour_gel(mass,error,type,i,tot)
        show do
            title "Pour gel (#{i} of #{tot})"
            check "Grab a flask from on top of the microwave M2."
            check "Get a graduated cylinder from on top of the microwave. Measure and add <b>#{TAE[:qty]} #{TAE[:units]}</b> of #{TAE[:name]} from jug J2 to the flask."
            check "Using a digital scale, measure out <b>#{mass} g</b> (+/- #{error} g) of <b>#{type}</b> agarose powder and add it to the flask."
            if(type=="low melting")
                note "Low-melting agarose is located in the cabinet above the microwave."
            end
            check "Microwave <b>#{MICROWAVE_TIME[:qty]} #{MICROWAVE_TIME[:units]}</b> on high in microwave M2, then swirl. The agarose should now be in solution."
            note "If it is not in solution, microwave 7 seconds on high, then swirl. Repeat until dissolved."
            warning "Work in the gel room, wear gloves and eye protection all the time"
        end
    end
    
    def add_gel_green(i,tot)
        show do
            title "Add #{GEL_GREEN[:name]} (#{i} of #{tot})"  
            note "Using a 10 L pipetter, take up <b>#{GEL_GREEN[:qty]*(GEL_VOL[:qty]/50.0)} #{GEL_GREEN[:units]}</b> of #{GEL_GREEN[:name]} into the pipet tip. Expel the #{GEL_GREEN[:name]} directly into the molten agar (under the surface), then swirl to mix."
            warning "#{GEL_GREEN[:name]} is supposedly safe, but stains DNA and can transit cell membranes (limit your exposure)."
            warning "#{GEL_GREEN[:name]} is photolabile. Limit its exposure to light by putting it back in the box."
        end
    end
    
    def add_combs(i,tot)
        show do
            title "Add combs (#{i} of #{tot})"
            check "Go get a 49 mL Gel Box With Casting Tray (clean)"
            check "Retrieve 2 <b>6-well</b> purple combs from A7.325"
            check "Position the gel box with the electrodes facing away from you."
            check "Add a purple comb to the side of the casting tray nearest the side of the gel box."
            check "Put the <b>#{COMB_TYPE}</b> side of the comb down."
            check "Add another purple comb to the center of the casting tray."
            check "Put the <b>#{COMB_TYPE}</b> side of the comb down."
            note "Make sure that both combs are well-situated in their grooves of the casting tray."
        end
    end
    
    def label_gel(gel_item,type,percentage,i,tot)
        show do
            title "Pour and label the gel (#{i} of #{tot})"
            note "Using a gel pouring autoclave glove, pour agarose from one flask into the casting tray. 
                          Pour slowly and in a corner for best results. Pop any bubbles with a 10 L pipet tip."
            note "Write <b>#{gel_item}</b> + <b>#{percentage}% #{type}</b> + <b>#{Time.zone.now.to_date}</b> on piece of lab tape and affix it to the side of the gel box."
                note "Leave the gel at location A7.325 to solidify."
        end
    end
    
end