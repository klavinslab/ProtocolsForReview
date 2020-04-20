# By: Eriberto Lopez 11/05/2017
# eribertolopez3@gmail.com

# Loads necessary libraries
category = "Flow Cytometry - Yeast Gates"
needs "#{category}/Multiwell_Module"
needs "#{category}/Retrieve_Associations"
needs "Standard Libs/Debug" # Used for printing out objects for debugging purposes
needs "Tissue Culture Libs/CollectionDisplay"


class Protocol

#---------------Constants-&-Libraries----------------#
#   require 'date'
#   require 'matrix'
  
  include CollectionDisplay
  include Multiwell_Module
  include Retrieve_Associations
  include Debug
  
  INPUT = "24 Deep Well Plate"
  OUTPUT = "24 Deep Well Plate"
#   PARAM_WAVELENTH = "Wavelength (nm)"
  PARAM_TIME = "Time Point (hr)"
  PARAM_OD = "Final OD"
  CULT_VOL = 4 #mLs
#----------------------------------------------------#

  def main

    operations.make.retrieve
    
    ######------TESTING-----#######
    debuggin = false 
    ######------TESTING-----#######
    
    max_vol = CULT_VOL*1000 # mL -> uL
    final_OD = operations.map {|op| op.input(PARAM_OD).val.to_f}.first
    log_info 'final_OD param', final_OD
    
    wavelength = 600 #operations.map {|op| op.input(PARAM_WAVELENTH).val.to_i}.first
    timepoint = operations.map {|op| op.input(PARAM_TIME).val.to_i}.first
    key = 'optical_density' # Known beforehand, I knew where I created the association and with what key I used - Measure_OD_Draft
    
    in_colls = operations.map {|op| op.input(INPUT).collection}.uniq
    out_colls = operations.map {|op| op.output(OUTPUT).collection}.uniq
    log_info 'out_colls', out_colls
    
    in_colls.each do |in_coll|
        
        if debuggin == true
            collection = 111543 # testing collection
            item = Item.find(collection) 
            # tst = Item.find(collection).get(key)
            # log_info 'test', tst
        else
            item = Item.find(in_coll.id) 
        end

        log_info 'item', item, 'key', key
        # finds data association - Retrieve_Associations module
        hash = find_data_association(item, key)
        log_info "hash", hash
        
        if (!hash.nil?)
            # looks at all optical density associations, finds keys, and takes the last input - May be better to find the greatest number to account for the most time passed
            if debuggin == true
                keys = hash.keys
                log_info 'keys', keys
                keys.map! {|time| time.split('_')[0]}
                keys.sort!
                log_info 'keys', keys
                od_mat = hash["#{keys[-1]}_hr"] # Or keys.max
                log_info 'od_mat',od_mat
                
            else
                # Obtains the keys of the hash that is associated to the input item
                keys = hash.keys
                log_info 'keys', keys
                keys.map! {|time| time.split('_')[0]}
                keys.sort!
                # Then, uses the most recent timepoint to acquire the most recent timepoint hash
                od_mat = hash["#{keys[-1]}_hr"] # Or keys.max
            end
            
            # May be beneficial to have cultures diluted either 1:10 or 1:100 in order to pipette volumes accurately
            if (final_OD <= 0.01 && final_OD > 0.001) # needs a 1:10 dilution
                # show block directing a 1:10
                final_dilution = 10
                serial_dilution(final_dilution) # Multiwell Module
                
                # dilute matrix 1:10
                matrix = Matrix.rows(od_mat)
                dilution = (matrix/final_dilution).to_a
                
                # then use sync_calc to determine how much vol of culture needed from diluted cult
                cult_vols_ul = sync_calc(dilution, final_OD) # Creates a 2D array
                
            elsif (final_OD <= 0.001 && final_OD > 0.0001) # needs a 1:100 dilution
                # show block directing two 1:10 dilutions
                final_dilution = 100
                serial_dilution(final_dilution) # Multiwell Module

                # dilute matrix 1:100
                matrix = Matrix.rows(od_mat)
                dilution = (matrix/final_dilution).to_a
                
                # then use sync_calc to determine how much vol of culture needed from diluted cult
                cult_vols_ul = sync_calc(dilution, final_OD)
            else
                cult_vols_ul = sync_calc(od_mat, final_OD) # No dilution needed
            end
            
            cult_vols_mat = Matrix.rows(cult_vols_ul) ### how to handle empty
            
            # Creates matrix that contains max_vol of culture in each index
            rows = item.object_type.rows 
            cols = item.object_type.columns
            max_vol_mat = Matrix.build(rows, cols) {max_vol}
            
            # Subtracts the max_vol matrix from the cult_vols_ul matrix
            media_vols_ul = max_vol_mat - cult_vols_mat
            
            # for each output collection being made
            out_coll = out_colls.shift 

            show do
                title "Filling Item With Media"
                
                note "Grab a clean, 24 Deep Well plate and label with Item #<b>#{out_coll}</b>."
                note "Use a multichannel pipette or favorite method to dispense the following volumes of media."
                table highlight_non_empty(in_coll) {|r,c| "#{media_vols_ul[r,c]}ul"}
            end
            #display media for each well
            show do 
                title "Synchonization of Cultures by OD"
                if (!dilution.nil?)
                    note "Next, resuspend the following volumes of previously diluted cultures to reach a final OD of #{final_OD}"
                else
                    note "Next, resuspend the following volumes of cultures to reach a final OD of #{final_OD}"
                end
                table highlight_non_empty(in_coll) {|r,c| "#{cult_vols_mat[r,c]}ul"}
                check "When finished place an AeraSeal breathable seal on top of the plate (location: <b>B9.415</b>)"
            end
            # May change when harvesting library comes into play - EL 120517
            in_coll.mark_as_deleted
            
            out_coll.location = "Small 30C incubator on shaker @ 800rpm"
            out_coll.save

            # After synchronization is finished associate a t0 matrix to the output collection/item (should consist of the final OD)
            # Create t0 matrix
            final_od_mat = Matrix.build(rows, cols) {final_OD}
            # create a t0 hash and associate to the output item
            od_hsh = Hash.new(0)
            od_hsh["0_hr"] = final_od_mat
            Item.find(out_coll.id).associate(key, od_hsh) # 'optical_density'=>{'0_hr'=>[[final_od_mat]]}
        end
    end
    
    # include instruction for finishing up and cleaning 

    operations.store
    
    return {}
    
  end # main
    
    # returns the volume needed from each culture in ul
    #
    # @param matrix []
    # @param final_OD []
    # @return culture_vols []
    def sync_calc(matrix, final_OD)
        tot_od = final_OD * CULT_VOL.to_f
        culture_vols = matrix.map do |row|
            row.map do |col|
                if col == 0.0
                    col
                else
                    col = ((tot_od/col) * 1000).round(1)
                end
            end
        end
       return culture_vols
    end
    
    
    # def sync_calc(matrix, final_OD)
    #     culture_vols = matrix.each do |row|
    #         row.map! do |cult_od|
    #             # cult_ul = ((1000*(final_OD * CULT_VOL)/cult_od)).round(2)
    #             if cult_od == 0.0
    #                 cult_ul = ":D"
    #             else
    #                 tot_od = final_OD * CULT_VOL.to_f
    #                 cult_ul = ((1000*(tot_od/cult_od.to_f))).round(2)
    #             end
    #             cult_ul
    #         end
    #         row
    #     end
    #     return culture_vols
    # end


end # class
