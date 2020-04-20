# testing data association to plan for EXISTING plan, EXISTING data
needs "Standard Libs/Debug"  

class Protocol
    
  include Debug
  
  PLAN_INPUT="plan id"    
  ITEM_INPUT="item id"
  EXP_NUM="expected number of uploads"
  PREFIX="prefix"

  def main

    # no make needed
    operations.each { |op| 
    
        doPlan=1
        doItem=1
        
        # try to find item/plan number
        begin 
            plan = Plan.find(op.input(PLAN_INPUT).val.round) # round because input is a float
        rescue
            show {note "no plan with input id #{op.input(PLAN_INPUT).val.round}! will not attach to plan. (#{__method__.to_s})."}
            doPlan=0
            #return {}
        end
        
        # try to find item/plan number
        begin 
            item = Item.find(op.input(ITEM_INPUT).val.round) # round because input is a float
        rescue
            show {note "no item with input id #{op.input(ITEM_INPUT).val.round}! will not attach to item. (#{__method__.to_s})."}
            doItem=0
            #return {}
        end
        
        if( (doPlan==0) and (doItem==0) )
            return
        end
        
        # get expected number of uploads, update to 1 if <1
        expected=op.input(EXP_NUM).val.round # round float to integer
        if(expected<1)
            expected=1
        end
        
        # reset numbers for testing
        #plan = Plan.find(7608)
        #item = Item.find(112440)
        #expected = 96
        
        # upload interactively - 3 tries
        uploads={}
        numUploads=0
        attempt=0 # number of upload attempts
        
        loop do
            
            break if ( (attempt>=3) or (numUploads==expected) )
                
            attempt=attempt+1;
            uploads = show do
                title "Select <b>#{expected}</b> files"
                if(attempt>1) 
                    warning "Number of uploaded files (#{numUploads}) was incorrect, please try again! (Attempt #{attempt} of 3)"
                end
                upload var: "fcs_files"
            end
            if(!uploads[:fcs_files].nil?)
                numUploads=uploads[:fcs_files].length
                #show {note "numUploads = #{numUploads}"}
            end
            
        end
        
        # return if wrong number of files
        if !(numUploads==expected)
            show {warning "wrong number of files! exiting (#{__method__.to_s})."}
            return {}
        end
        
        # prefix for these files, "_" will be added as needed    
        prefix=op.input(PREFIX).val    
        
        # associate uploads. association key will be prefix followed by original filename   
        ups=Array.new # array of upload hashes, will be associated with item
        if (!uploads[:fcs_files].nil?)
            #show do
                uploads[:fcs_files].each_with_index do |upload_hash, ii|
                    up=Upload.find(upload_hash[:id])
                    
                    if (doPlan==1)
                        # associate with plan - so users can download without navigating into job->item  (UPLOAD association)
                        plan.associate "#{prefix}_#{upload_hash[:id]}", "#{prefix} #{upload_hash[:id]} #{upload_hash[:name]} plan note", up
                    end
                    
                    if (doItem==1)
                        # build uploads array
                        #note "upload_hash id= #{upload_hash[:id]} name=#{upload_hash[:name]}"
                        ups[ii]=up
                    end
                end
            #end
            
            # associate array of upload hashes to item  (REGULAR association)    
            if(doItem==1)
                #test_str="test_string"
                #test_array=[1,2,3]
                #test_hash={"one"=>1,"two"=>2}
                #item.associate "TEST1", test_str
                #item.associate "TEST2", test_array
                #item.associate "TEST3", test_hash
                #item.associate "TEST4", ups.first
                #item.associate "TEST5", ups.last
                item.associate "#{prefix}_uploads", ups
            end
            
            # associate to hash using A0.fcs 
        end # if uploads not nil
    
        return {}
    
    } # operations.each
    
  end # main

end # Protocol
