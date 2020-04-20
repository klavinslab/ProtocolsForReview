 module HighThroughputHelper
    
  #-------------------------------------------------------------------------------------------
  # passes all relevant array stuff from input to output WITHOUT generating new array item
  #
  # in_array - input array (e.g., op.input_array(INPUT_NAME) )
  # out_array - input array (e.g., op.output_array(OUTPUT_NAME) )
  # must have the same number of elements in input and output arrays (same number of circles on graphic block in plan)
  #-------------------------------------------------------------------------------------------            
  def passArray(in_array, out_array) 
      in_array.zip(out_array).each do |input, output|   # zip pairs array 
          output.child_sample_id=input.child_sample_id
          output.child_item_id=input.child_item_id
          output.save
      end
  end
  
  #-------------------------------------------------------------------------------------------
  # associates FSC upload ids to correct row, column in collection hash
  # ASSUMES FILENAMES ARE A0-H11.fcs
  #
  # association is based on filenames: hash key R0C0 will have upload value with upload[:name] == A0.fsc 
  # incol - input collection that has associated FCS files (if not - nothing is done here)
  #-------------------------------------------------------------------------------------------        
  def associatePlateFSCuploads(incol, uploads_key)
        # check if have associated uploads, if not - return
        ups=Item.find(incol.id).get(uploads_key)
        if(ups.nil?)
            return
        end
      
        # input hash, info - create if nil
        dims=incol.dimensions
        inplate=incol.matrix
        inhash=Item.find(incol.id).get("item_info")
        # are we appending to or creating collection's hash?
        if (inhash.nil?) 
            inhash=Hash.new() 
        end
        inhash_names = Item.find(incol.id).get("item_info_names")
        if (inhash_names.nil?) 
            inhash_names=Array.new()
        end
            
        # copy item ids to collection.matrix[i][j] and info to hash
        ups.each do |up| 
            # find unique name of upload, format is uploadID_wellName, where wellName is in A0 to H11 range
            mymatch=/(?<myrow>[A-H]{1,1})(?<mycol>[0-9]{1,2}).fcs/.match(up[:name])
            if(!mymatch.nil?) # in case there is no match
                rr=mymatch[:myrow].ord.to_i-"A".ord    # subtract ascii value of "A" from A-H to get row integer, 0-7
                cc=mymatch[:mycol].to_i                # col integer, 0-11
                # add to hash at correct row rr, column cc
                inhash.store("R#{rr}C#{cc}_upload", up) # we are associating upload item using regular association, not upload association
            end
        end
        
        # add new association name "upload" to hash item_info strings
        Item.find(incol.id).associate :item_info_names, inhash_names.concat(["upload"])
        Item.find(incol.id).associate :item_info, inhash # in case there was no hash for this collection. replaces previous hash.
        
        incol.save # may not be needed
  end # initializeDilutionPlate
  
  #-------------------------------------------------------------------------------------------
  # initializes 24-well inducer plates for induction experiment:
  # - assigns ids to occupied wells
  # - populates a hash with additional well information
  # - associates hash and array item_info_names describing strings with collection 
  #
  # incol - 24 well collection with strains in right side
  # outcol - 24 well collection to be populated
  # left_Lara - float, concentration of Lara in left side of plate
  # left_IPTG - float, concentration of aTc in left side of plate
  # left_aTc - float, concentration of IPTG in left side of plate
  # right_Lara - float, concentration of Lara in right side of plate
  # right_IPTG - float, concentration of aTc in right side of plate
  # right_aTc - float, concentration of IPTG in right side of plate
  #-------------------------------------------------------------------------------------------        
  def initializeInducerPlate(incol, outcol, left_Lara, left_aTc, left_IPTG , right_Lara, right_aTc, right_IPTG)
        col_shift=3 # shift between column and its duplicate
      
        # input info
        dims=incol.dimensions
        inplate=incol.matrix
        inhash=Item.find(incol.id).get("item_info")
        inhash_names = Item.find(incol.id).get("item_info_names")
        
        # output 
        ind_plate=Array.new(dims[0]){Array.new(dims[1],-1)} # induction plate. same size, -1 default value
        hash = Hash.new # for induction plate 
        
        # produce items, add their ids to collection.matrix[i][j] and info to hash
        dims[0].times do |rr|
            (dims[1]/2).round.times do |cc|
                # ids - copy from incol.matrix, right side
                ind_plate[rr][cc]=inplate[rr][cc+col_shift]
                ind_plate[rr][cc+col_shift]=inplate[rr][cc+col_shift]
                
                if !(inhash.nil?)
                    # add replicate number, strain info to hash - left side
                    hash.store("R#{rr}C#{cc}_strain", inhash.fetch("R#{rr}C#{cc+col_shift}_strain") ) # strain
                    hash.store("R#{rr}C#{cc}_replicate", inhash.fetch("R#{rr}C#{cc+col_shift}_replicate") ) # replicate number    
                    # right side
                    hash.store("R#{rr}C#{cc+col_shift}_strain", inhash.fetch("R#{rr}C#{cc+col_shift}_strain") ) # strain
                    hash.store("R#{rr}C#{cc+col_shift}_replicate", inhash.fetch("R#{rr}C#{cc+col_shift}_replicate") ) # replicate number 
                    
                    # add inducer data - left side
                    hash.store("R#{rr}C#{cc}_IPTG_conc", left_IPTG) # IPTG
                    hash.store("R#{rr}C#{cc}_Lara_conc", left_Lara) # L-ara
                    hash.store("R#{rr}C#{cc}_aTc_conc", left_aTc) # aTc
                    # right side
                    hash.store("R#{rr}C#{cc+col_shift}_IPTG_conc", right_IPTG) # IPTG
                    hash.store("R#{rr}C#{cc+col_shift}_Lara_conc", right_Lara) # L-ara   
                    hash.store("R#{rr}C#{cc+col_shift}_aTc_conc", right_aTc) # aTc
                end

            end
        end 
        # associate ids
        outcol.matrix = ind_plate 
        # associate hash 
        Item.find(outcol.id).associate :item_info, hash 
        # associate strings of the info in all initialized items 
        Item.find(outcol.id).associate :item_info_names, ["strain","replicate","Lara_conc","aTc_conc","IPTG_conc"]
        outcol.save # may not be needed
  end # initializeInductionPlate
  
  #-------------------------------------------------------------------------------------------
  # initializes 24-well dilution plate for induction experiment: 
  # - assigns ids to occupied wells
  # - populates a hash with additional well information
  # - associates hash and array of item_info_names describing strings with collection
  #
  # incol - 24 well collection with strains in left side
  # outcol - 24 well collection to be populated
  #
  # plate order (left side is intermediate dilution, right side is relevant dilution):
  # pos, dup1        neg, dup 1          tets, dup1                   pos, dup1        neg, dup 1          tets, dup1
  # pos, dup2        neg, dup 2          tets, dup2                   pos, dup2        neg, dup 2          tets, dup2 
  # pos, dup3        neg, dup 3          tets, dup3                   pos, dup3        neg, dup 3          tets, dup3
  # pos, dup4        neg, dup 4          tets, dup4                   pos, dup4        neg, dup 4          tets, dup4
  #-------------------------------------------------------------------------------------------        
  def initializeDilutionPlate(incol, outcol)
        col_shift=3 # shift between column and its duplicate
      
        # input info
        dims=incol.dimensions
        inplate=incol.matrix
        inhash=Item.find(incol.id).get("item_info")
        inhash_names = Item.find(incol.id).get("item_info_names")
        
        # output 
        dilplate=Array.new(dims[0]){Array.new(dims[1],-1)} # same size, -1 default value
        hash = Hash.new
        
        # copy item ids to collection.matrix[i][j] and info to hash
        dims[0].times do |rr|
            (dims[1]/2).round.times do |cc|
                # ids
                dilplate[rr][cc]=inplate[rr][cc]
                dilplate[rr][cc+col_shift]=inplate[rr][cc]
                
                if !(inhash.nil?)
                    # add replicate number, strain info to hash. key contains position within collection.
                    hash.store("R#{rr}C#{cc}_strain", inhash.fetch("R#{rr}C#{cc}_strain") ) # strain
                    hash.store("R#{rr}C#{cc}_replicate", inhash.fetch("R#{rr}C#{cc}_replicate") ) # replicate number
                    hash.store("R#{rr}C#{cc+col_shift}_strain", inhash.fetch("R#{rr}C#{cc}_strain") ) # strain
                    hash.store("R#{rr}C#{cc+col_shift}_replicate", inhash.fetch("R#{rr}C#{cc}_replicate") ) # replicate number
                end

            end
        end 
        # associate ids
        outcol.matrix = dilplate 
        # associate hash 
        Item.find(outcol.id).associate :item_info, hash 
        # associate strings of the info in all initialized items
        Item.find(outcol.id).associate :item_info_names, ["strain","replicate"]
        outcol.save # may not be needed
      
  end # initializeDilutionPlate
     
  #-------------------------------------------------------------------------------------------
  # initializes 24-well inoculation plate for induction experiment: 
  # - assigns ids to occupied wells, 
  # - populates a hash with additional well information
  # - associates hash and array of well_info describing strings with collection
  #
  # col - 24 well collection
  # posname - name of positive control strain  (e.g., op.input(POS_NAME).sample.name)
  # negname - name of negative control strain
  # testname - name of test strain
  #
  # plate order:
  # pos, dup1        neg, dup 1          tets, dup1                   -1   -1   -1
  # pos, dup2        neg, dup 2          tets, dup2                   -1   -1   -1
  # pos, dup3        neg, dup 3          tets, dup3                   -1   -1   -1
  # pos, dup4        neg, dup 4          tets, dup4                   -1   -1   -1
  #-------------------------------------------------------------------------------------------     
  def initializeMultiwell(col, dups_per_strain, posname, negname, testname)
      # hash that will become collection's item_info
        hash = Hash.new
        
        # produce items, add their ids to collection.matrix[i][j]
        dups_per_strain.times do |n|
            pos=produce new_sample posname, of: "E coli strain", as: "E coli plate well (Sub item)"
            neg = produce new_sample negname, of: "E coli strain", as: "E coli plate well (Sub item)"
            tes = produce new_sample testname, of: "E coli strain", as: "E coli plate well (Sub item)"
            
            # add item ids to collection.matrix
            col.set n, 0, pos.id
            col.set n, 1, neg.id
            col.set n, 2, tes.id
            
            # add replicate number, strain info to hash. key contains position within collection.
            hash.store("R#{n}C#{0}_strain", pos.sample.name) # strain
            hash.store("R#{n}C#{0}_replicate", n) # replicate number
            hash.store("R#{n}C#{1}_strain", neg.sample.name) # strain
            hash.store("R#{n}C#{1}_replicate", n) # replicate number
            hash.store("R#{n}C#{2}_strain", tes.sample.name) # strain
            hash.store("R#{n}C#{2}_replicate", n) # replicate number

            # save items (not sure this is needed) 
            pos.save
            neg.save
            tes.save
        end
        # associate hash to collection
        Item.find(col.id).associate :item_info, hash
        # associate strings of the info in all initialized items
        Item.find(col.id).associate :item_info_names, ["strain","replicate"]
        col.save # may not be needed
  end # initializeMultiwell
  
  #-------------------------------------------------------------------------------------------
  # transfers info from one or mmore multi-well collections to another multi-well collection.
  #  order:
  #------------------------------------------
  #    cols 0-5      |    cols 6-11
  #------------------------------------------
  # plate0-even rows |   plate2-even rows
  # plate1-odd rows  |   plate3-odd rows
  #------------------------------------------
  #
  # inputs:
  # cols24 - array of 24 well collections (e.g., input(INPUT_NAME).input_array.collections )
  # col96 - 96 well collection
  #-------------------------------------------------------------------------------------------
  def transferWellInfo(cols24, col96) 
      
        # check dimensions of plates
        if (col96.nil?)
           show {note "96 well is nil!!!"}
           return false
        end
        dims96=col96.dimensions
        if dims96.empty? 
           show {note "96 well DIMENSIONS ARRAY IS EMPTY!!!"}
           return false
        end
        if !(dims96.all? {|dim| dim>0})  || !(dims96.length==2) 
           show {note "96 well DIMENSIONS ARRAY HAS BAD DIMS!!!"}
           return false
        end
      
        # check array of 24 plates
        if cols24.empty?
           show{ note "NO 24 wells given!!!"}
           return false
        end
        
        if (cols24.length>4) || (cols24.length<1)
           show {note "BAD NUMBER OF 24 wells given!!! (#{cols24.length})"}
           return false
        end
      
        # check each 24 well plate
        if (cols24.nil?)
           show{note "24 well array is nil!!!"}
           return false
        end
        
        cols24.each { |col24|
            dims=col24.dimensions
            if dims.empty? 
               show {note "24 well DIMENSIONS ARRAY IS EMPTY!!!"}
               return false
            end
            if !(dims.all? {|dim| dim>0})  || !(dims.length==2) 
               show {note "24 well DIMENSIONS ARRAY HAS BAD DIMS!!!"}
               return false
            end
        }
        
        dims=cols24[0].dimensions
        plate96=Array.new(2*dims[0]){Array.new(2*dims[1],-1)} # will be 96 well matrix
        plate96hash=Hash.new                                  # will be 96 well hash
        
        cols24.each_with_index { |col24, plateii|
            
            # get 24 well stuff
            plate24=col24.matrix                                       # plate-specific
            plate24hash = Item.find(col24.id).get("item_info")         # plate-specific
            plate24names = Item.find(col24.id).get("item_info_names")  # should be the same for all plates
            
            col_shift=0
            row_shift=0
            
            if !(plateii.even?) 
                row_shift=1
            end
            if (plateii > 1)   
                col_shift=6
            end
            
            # transfer to 96 well, row-wise
            dims[0].times do |r|
                (col_shift..(dims[1]-1+col_shift)).each_with_index {|ind96, ind24| 
                    # copy id
                    plate96[2*r+row_shift][ind96] = plate24[r][ind24]
                    # copy hash info
                    if !(plate24hash.nil?) && !(plate24names.nil?) && (plate24[r][ind24]>0)
                        plate24names.length.times do |ii|
                            key96="R#{2*r+row_shift}C#{ind96}_#{plate24names[ii]}"      
                            key24="R#{r}C#{ind24}_#{plate24names[ii]}"   
                            plate96hash.store( key96, plate24hash.fetch(key24) )
                        end
                    end
                }
            end # do
            
            # set 96 well matrix to plate96
            col96.associate plate96
            # associate hash item_info
            Item.find(col96.id).associate :item_info, plate96hash
            # associate item_info_names
            Item.find(col96.id).associate :item_info_names, plate24names
            col96.save
            
        } # cols24.each
  end # transferWellInfo 
 
  #-------------------------------------------------------------------------------------------
  # displays the item id matrix, hash item names, and hash data associated with the items within a collection 
  #
  # col - collection whose matrix holds the item ids
  # message - string, will be displayed above collection information
  #-------------------------------------------------------------------------------------------
  def displayCollectionHash(col,message)
      # check dimensions of collection
      dims=col.dimensions
      if dims.empty? 
          note "DIMENSIONS ARRAY IS EMPTY!!!"
          return false
      end
      if !(dims.all? {|dim| dim>0})  || !(dims.length==2) 
          note "DIMENSIONS ARRAY HAS BAD DIMS!!!"
          return false
      end
      
      # get matrix, holds item ids as integers
      mat=col.matrix
    
      # get list of parameters associated with each item 
      info_names=Item.find(col.id).get("item_info_names")
      addInfo = !info_names.nil? # boolean flag, true if there is info to add to printout
      hash=Item.find(col.id).get("item_info")
    
      # build printout string 
      rowstr="Item ID".ljust(20,"_") 
      
      if(addInfo)
          showMat=Array.new(info_names.length,"") # array of empty strings for displaying associated info
      end
      
      dims[0].times do |r|
        dims[1].times do |c|
            # build row string - all info for display
            rowstr=rowstr + mat[r][c].to_s.ljust(10,"_") 
            
            if(addInfo) # add item info to display string
                (info_names.length).times do |ii|
                    if(mat[r][c]>0) # uninitialized wells have -1
                        #nm=Item.find(mat[r][c]).get(info_names[ii])
                        nm=hash.fetch("R#{r}C#{c}_#{info_names[ii]}")
                        if (nm.class == Fixnum)
                            nm=nm.to_s # convert numbers to strings
                        end
                        showMat[ii]=showMat[ii] + nm.ljust(10,"_")
                    else
                        showMat[ii]=showMat[ii] + "-1".ljust(10,"_")  # place holder
                    end
                end
            end
            
            # reached last column, add all info to rowstr
            if c == (dims[1]-1)
                rowstr=rowstr + "<br/>"
                if(addInfo)  # add item info to display string
                    (info_names.length).times do |jj|
                        rowstr=rowstr + info_names[jj].ljust(20,"_") + showMat[jj] + "<br/>"
                        showMat[jj]="" # ready for new row 
                    end
                end
                if !(r == dims[0]-1) # will have another row
                    rowstr=rowstr+"Item ID".ljust(20,"_") 
                end
            end
        end
      end
      
      # printout
      show{
        note "collection.matrix " + message
        if(addInfo)
            note "item associations: #{info_names.join(",")}"
        end
        note rowstr
      }
  end # dislayCollectionHash
  
  #-------------------------------------------------------------------------------------------
  # prepare tip boxes with odd rows only for 24-well pippetting with 8-channel pippette 
  #
  # n - number of odd-row-only boxes you need 
  # vol - tip volume in µL (e.g. 10, 200, 1000) 
  #-------------------------------------------------------------------------------------------
  def oddRowOnlyTips(n, vol)
    # make sure n is a positive integer
    ok=(Integer(n) > 0 rescue false)
    if not ok  
        return false
    end
    
    # ask if the boxes are already prepared
    ans1 = show do
        title "Check for <b>#{vol} µL</b> odd-row-only tip boxes"
        select [ "Yes", "No"], var: "choice", label: "Do you have <b>#{n}</b> odd-row-only box(es) of <b>#{vol} µL</b> tips?", default: 0 # default is "Yes" so test will run
    end 
    if(ans1[:choice]=="Yes")
        return true
    end 
    
    # prepare boxes
    show do
        title "Prepare odd-row-only tips"
        check "Gather #{(n.to_f/2).ceil} autoclaved <b>#{vol}</b> µL <b>FULL</b> tip box(es)"
        check "Gather #{(n.to_f/2).ceil} autoclaved <b>#{vol}</b> µL <b>EMPTY</b> tip box(es), with tip rack(s)"
        check "Using multi-channel pippette, transfer the tips from the even rows of the FULL boxes to the odd rows of the EMPTY boxes (see below)"
        image "Actions/Induction_High_Throughput/odd-row-only_cropped.jpg"
        note "You should have #{2*(n.to_f/2).ceil} odd-row-only boxes when you are finished" 
    end
    return true
  end # oddRowOnlyTips
  
end #HighThroughputHelper