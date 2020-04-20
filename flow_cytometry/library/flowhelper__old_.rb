# Library containing helper functions for Flow Cytometry
# SG      
#  
# TO DO: 
# 1. error if not enough volume? 
# 2. do we need save on all runs?
# 3. what happens to 2nd cleaning? do we see both files?

needs "Standard Libs/Debug" 

module FlowHelper
    include Debug
    # current list of allowed types of cytometers     
    CYTOMETER_NAMES=["BD Accuri"]
    
    # constant prefixes, used as keys for uploads (reason: if have multiple uploads with same filename, e.g. A0.fcs, can differentiate using prefix)
    PRE_SAMPLE="SAMPLE_"
    PRE_BEADS="BEADS_"

    # ------- start of BD ACCURI related stuff ----------  
    # template files directory - all template filenames MUST end in .c6t
    TEMPLATE_DIR="Documents/AQ_TEMPLATES"
    
    # clean
    CLEAN_VOL_mL=0.5 # minimum volume in eppendorfs to run clean      
    CLEAN_ADD_VOL_mL=1 #  how much to add 
    CLEAN_HOLDER="24 tube rack"
    CLEAN_LABELS=['C','D','S'] # eppendorf labels
    CLEAN_POS=['D4','D5','D6'] # eppendorf positions - for display purposes. IF CHANGED, MUST CHANGE samplePositions IN cleanCytomoeter()
    JAR_LABELS=['Cleaning','Decontamination','Sheath'] # stock labels
    CLEAN_TEMPLATE="CleanRegular.c6t" # name of file for clean 
    CLEAN_SETTINGS={"Run Limits" => "2 Min", "Fluidics" => "Slow", "Set Threshold" => "FSC-H less than 80,000", "Wash Settings" => "None", "Agitate Plate" => "None"}     
   
    # bead calibration
    BEAD_VOL="1 drop"  
    BEAD_MEDIA="PBS"
    BEAD_MEDIA_VOL="1 mL"
    BEAD_HOLDER="24 tube rack"
    BEAD_POS=['A1'] # position of eppendorf in BD 24 eppendorf holder - for display purposes. IF CHANGED, MUST CHANGE samplePositions IN beadCalibration()
    BEAD_TEMPLATE="calibration_beads_template.c6t" # name of file for calibration
    BEAD_SETTINGS={"Run Limits" => "30 µL", "Fluidics" => "Slow", "Set Threshold" => "FSC-H less than 300,000, SSC-H less than 250,000", "Wash Settings" => "None", "Agitate Plate" => "None"}   
    
    # allowed sample types X, and their corresponding template filenames and settings X_SETTINGS
    SAMPLE_HOLDER="96 well plate: Flat Bottom (Black)"
    SAMPLE_TYPES=["E coli","Yeast"]
    SAMPLE_TEMPLATES={"E coli"=>"Ecoli.c6t","Yeast"=>"Yeast_gates.c6t"} # names of template files     
    #SAMPLE_POS={"E coli" => ["all wells in 96-well plate"], "Yeast" => ['A','B','C','D','E','F','G','H']} # not needed! collection holds existing item ids
    # ---------
    Ecoli_SETTINGS={"Run Limits" => "10,000 events, 1 Min, 50 µL", "Fluidics" => "Medium", "Set Threshold" => "FSC-H less than 8,000", "Wash Settings" => "None", "Agitate Plate" => "None"}
    Yeast_SETTINGS={"Run Limits" => "30,000 events", "Fluidics" => "Fast", "Set Threshold" => "FSC-H less than 400,000", "Wash Settings" => "None", "Agitate Plate" => "1 Cycle Every 12 Wells"}   
    SAMPLE_SETTINGS={"E coli"=>Ecoli_SETTINGS,"Yeast"=>Yeast_SETTINGS}
    # ------- end of ACCURI related stuff ----------
    
    #-------------------------------------------------------------------------------------------
    # export and save FCS and associate to input sample or collection
    #
    # cytstr - string that defines cytometer,  must match one of the strings in CYTOMETER_NAMES
    # input - sample or collection to which uploaded fcs file will be associated. 
    #         IMPORTANT: pass in form that enables input.associate!!!
    # op - operation to which uploaded files will be associated
    # prefix - optional string to be added as prefix to filenames
    # expUploadNum - expected number of files to upload
    #-------------------------------------------------------------------------------------------             
    def exportFCS(cytstr, input, op, prefix="", expUploadNum=1)
        case cytstr
        when "BD Accuri" 
            # export
            show do
                title "Export Data from Flow Cytometer #{cytstr}"
                check "Make sure that flow cytometer run is <b>DONE!</b>"
                check "Press <b>CLOSE RUN DISPLAY</b>"
                check "Select <b>File</b> => <b>Export ALL Samples as FCS...</b> (see below)"
                image "Actions/FlowCytometry/saveFCS_menu_cropped.png"
            end
            ui = show do
                title "Export Data from Flow Cytometer #{cytstr}"
                warning "Look for the name of the FCS directory that is created, as in example below. Your directory name will be different!"
                image "Actions/FlowCytometry/saveFCS_dirname_cropped.png"
                get "text", var: "dirname", label: "Enter the name of the export directory in <b>Desktop/FCS Exports/</b>"
            end
            dirname = ui[:dirname]
            
            # upload interactively - 3 tries to get right number of files
            uploads={} 
            numUploads=0
            attempt=0  # number of upload attempts
            loop do
                break if ( (attempt>=3) or (numUploads==expUploadNum) ) # stopping condition
                attempt=attempt+1;
                uploads = show do
                    title "Select <b>#{expUploadNum}</b> file(s) from #{dirname}"
                    if(attempt>1)
                        warning "Number of uploaded files (#{numUploads}) was incorrect, please try again! (Attempt #{attempt} of 3)"
                    end
                    upload var: "fcs_files"
                end
                if(!uploads[:fcs_files].nil?)
                    numUploads=uploads[:fcs_files].length
                end
            end
            
            # associate uploads. association key will be prefix followed by original upload id
            ups=Array.new # array of upload hashes, will be associated with item
            if (!uploads[:fcs_files].nil?)
                uploads[:fcs_files].each_with_index do |upload_hash, ii|
                    up=Upload.find(upload_hash[:id])
                    
                    # populate array - to associate upload item with input item  
                    ups[ii]=up
                    
                    # associate with plan - so users can download without navigating into job->item
                    op.plan.associate "#{prefix}#{upload_hash[:id]}", "#{prefix} #{upload_hash[:id]} #{upload_hash[:name]} plan note", up
                end
                # associate array of upload hashes to item
                input.associate "#{prefix}uploads", ups
            end
            
        else # other cytometers
            show {note "Chosen cytometer #{cytstr} does not exist (#{__method__.to_s})"} 
        end # case
    end # export FCS
    
    
    # String: BD Accuri
    # String: E coli
    # Float: 98.0
    # Collection: 116849
    # Operation: 50137 Flow Cytometry 96 well
    
    #-------------------------------------------------------------------------------------------
    # run 96-well collection and associate data
    # inputs:
    # cytstr - string that defines cytometer, must match one of the strings in CYTOMETER_NAMES
    # samplestr - string that defines sample, must match one of the strings in SAMPLE_TYPES
    # well_vol - well volume in µL
    # col - 96-well collection to which data will be associated (e.g., input(INPUT).item.collection)
    # returns: 
    # string , the key of the uploads associated to the collection
    #-------------------------------------------------------------------------------------------            
    def runSample96(cytstr, samplestr, well_vol, col, op)
        log_info 'checkpoint_1'
        case cytstr
        
        when "BD Accuri"
            log_info 'checkpoint_2'
            # get settings hash, make sure there is more in wells than in settings
            # if (well_vol < settings.fetch("min_vol"))
            #     show {warning "volume in wells is too low! (#{__method__.to_s})"}
            # end
            log_info 'col', col
            if(col.nil?)
                show {"No collection given! (#{__method__.to_s})"}
                return
            end
            
            dims=col.dimensions
            log_info 'dims', dims
            
            if dims.empty? 
               show {note "96 well DIMENSIONS ARRAY IS EMPTY!!! (#{__method__.to_s})"}
               return false
            end
            
            log_info 'checkpoint_3'
            if !(dims.all? {|dim| dim>0})  || !(dims.length==2) 
              show {note "96 well DIMENSIONS ARRAY HAS BAD DIMS!!! (#{__method__.to_s})"}
              return false
            end
            log_info 'checkpoint_4'
            # count positions within plate that contain samples 
            numSamples=0
            dims[0].times do |rr|
                dims[1].times do |cc|
                    # log_info 'col.matrix[rr][cc]', col.matrix[rr][cc]
                    if(col.matrix[rr][cc] > 0)
                        numSamples=numSamples+1;
                    end
                end
            end
            log_info 'runSamples', numSamples
            log_info 'checkpoint_5'
            if(numSamples<1) # should never happen
                show {"No samples to run! (#{__method__.to_s})"}
                # return  ### This what causes it to end function and complete job without crashing
            end
            
            
            #runTemplate(cytstr, templatefile, settingshash, titlestr, holder, samplePositions=nil, itemNum="")
            runTemplate(cytstr, SAMPLE_TEMPLATES.fetch(samplestr), SAMPLE_SETTINGS.fetch(samplestr), "#{samplestr} measurement", SAMPLE_HOLDER, col.matrix, Item.find(col.id) )
            exportFCS(cytstr, Item.find(col.id), op, PRE_SAMPLE, numSamples) # pass collection item in format that can be used with .associate
        else # other cytometers
            show {note "Chosen cytomter #{cytstr} does not exist (#{__method__.to_s})"}      
        end # case
        
        return "#{PRE_SAMPLE}uploads" # return
    end # runSample    

    #-------------------------------------------------------------------------------------------
    # run bead calibration sample on cytometer and associate data
    #
    # cytstr - string that defines cytometer
    # bead_stock - bead item, stock of calibration beads 
    # returns:
    # bead_item - diluted bead item to which calibration data is associated
    #-------------------------------------------------------------------------------------------            
    def beadCalibration(cytstr, bead_stock, op)
        # create new diluted bead item, same beads as bead stock, in aquarium 
        bead_diluted = produce new_sample bead_stock.sample.name, of: "Beads", as: "Diluted beads"
        #pos=produce new_sample posname, of: "E coli strain", as: "E coli plate well (Sub item)" 
        
        case cytstr
        when "BD Accuri" 
            # bead sample setup
            show do
                title "Prepare Calibration sample"
                check "Add #{BEAD_VOL} of #{bead_stock.sample.name}, brown cap to #{BEAD_MEDIA_VOL} of #{BEAD_MEDIA}" 
                check "Add #{BEAD_VOL} of #{bead_stock.sample.name}, white cap to <b>same</b> #{BEAD_MEDIA_VOL} of #{BEAD_MEDIA}" 
                check "Place eppendorf containing calibration sample in #{BEAD_HOLDER} at position(s) #{BEAD_POS.join(",")} of #{BEAD_HOLDER}"
            end
            # samplePositions
            samplePositions=Array.new(8){Array.new(12, -1)}
            samplePositions[0][0]=bead_diluted.id # A1
            # run
            #runTemplate(cytstr, templatefile, settingshash, titlestr, holder, samplePositions=nil, itemNum="")
            runTemplate(cytstr, BEAD_TEMPLATE, BEAD_SETTINGS, "Calibration Template on #{cytstr}", BEAD_HOLDER, samplePositions, bead_diluted.id) 
            exportFCS(cytstr, bead_diluted, op, PRE_BEADS, 1)
        else # other cytometers
            show {note "Chosen cytomter #{cytstr} does not exist (#{__method__.to_s})"}
        end # case
            
        # return bead item 
        return bead_diluted
    end # beadCalibration

    #-------------------------------------------------------------------------------------------
    # run clean cycle on cytometer  (no data associations)
    #
    # cytstr - string that defines cytometer
    #-------------------------------------------------------------------------------------------            
    def cleanCytometer(cytstr)   
        case cytstr   
        when "BD Accuri" 
            # check that there is sufficient volume of cleaning reagent
            show do
                title "Check Levels of Cleaning Reagents" 
                check "Locate the #{CLEAN_HOLDER}. It should contain #{CLEAN_LABELS.length} eppendorfs."
                CLEAN_LABELS.length.times do |ii|
                    check "Check that eppendorf labeled  <b>#{CLEAN_LABELS[ii]}</b> at position  <b>#{CLEAN_POS[ii]}</b> contains at least #{CLEAN_VOL_mL} mL. If not, add <b>#{CLEAN_ADD_VOL_mL}</b> mL from jar labeled <b>#{JAR_LABELS[ii]}</b> located in cabinet above cytometer."
                end
            end
            # samplePositions
            samplePositions=Array.new(8){Array.new(12, -1)}
            samplePositions[3][3]=1 # D4
            samplePositions[3][4]=1 # D5
            samplePositions[3][5]=1 # D6
            # run   
            #runTemplate(cytstr, templatefile, settingshash, titlestr, holder, samplePositions=nil, itemNum="")
            runTemplate(cytstr, CLEAN_TEMPLATE, CLEAN_SETTINGS, "Cleaning Template on #{cytstr}",CLEAN_HOLDER, samplePositions, "")  # no item number  
            # special for clean    
            show do
                note "Cytometer does not require supervision while Cleaning template is running."  
            end
        else # other cytometers 
            show {note "Chosen cytomter #{cytstr} does not exist (#{__method__.to_s})"}
        end # case
    end # cleanCytometer
    
    #-------------------------------------------------------------------------------------------
    # instructions for setting up template and running it
    #
    # cytstr - string that defines cytometer
    # templatefile - string, name of template file
    # settingshash - hash of settings for this run
    # titlestr - string, title for show window
    # samplePositions - an 8x12 matrix containing sample ids for occupied wells, 0 otherwise (use item.collection)
    # itemNum - number that is useful to user (e.g. item.id), used in name of .c6 file only
    #-------------------------------------------------------------------------------------------            
    def runTemplate(cytstr, templatefile, settingshash, titlestr, holder, samplePositions=nil, itemNum="")
        
        if(samplePositions.nil?) # should never happen
            show {note "samplePositions is nil, nothing to measure! (#{__method__.to_s})"}
            return
        end
        
        case cytstr
        when "BD Accuri"
            # build string, .c6 filename
            c6str=File.basename(templatefile,".c6t") + "_#{itemNum}_" + "#{Time.zone.now.to_date}" + ".c6" 
            c6str.gsub!("__", "_")  # replace "__" with "_" (for case of empty itemNum), edit original string
            
            # visually check culture positions 
            show do 
                    title "Check new sample #{titlestr}"
                    note "Only the shaded positions should contain samples:"
                    # display depends on type of samplePositions: y/n String
                    table displayPositionTable(samplePositions)
            end 
            
            # choose template (erase old data)
            show do
                title "Select #{titlestr}"
                check "Open the BD Accuri software BD CSampler if not already open"
                check "If the program is open and displaying <b>DONE!</b>, press <b>CLOSE RUN DISPLAY</b>" 
                check "Go to <b>File</b> => Select <b>Open workspace or template</b>"
                warning "Do not save changes to workspace"
                check "Under <b>#{TEMPLATE_DIR}</b>, find and open <b>#{templatefile}</b>"
                warning "The filename should end in <b>.c6t</b>!"
                check "Make sure the <b>Plate Type</b> is <b>#{holder}</b>"
                
                # deleting events no longer needed!!! .c6t hold no events!!!
                #check "Select the <b>Manual Collect</b> tab towards the top of the window"
                #check "If there are any events saved in wells <b>#{samplePositions.join(",")}</b>, select these wells and click <b>Delete Events</b> towards the bottom of the window. (This must be done one well at a time.)"
            end
            
            # load samples
            show do 
                title "Load sample #{titlestr}"
                warning "Beware of moving parts! Keep black tray beneath cytometer free!"
                check "Press <b>Eject Plate</b>"
                check "Remove the plate from the cytometer arm and place it on cytometer lid"
                check "For <b>#{holder}</b> containing <b>#{titlestr}</b>: remove all seals or lids, uncap any capped samples"
                check "Place <b>#{holder}</b> containing <b>#{titlestr}</b> on cytometer arm"
                warning "Make sure well <b>A1</b> is aligned with the red sticker on the cytometer arm!"
                check "Press <b>Load Plate</b>"
            end
            
            # settings
            show do
                title "Settings for #{titlestr}"
                check "Select the <b>Auto Collect</b> tab towards the top of the window"
                note "You will be using the settings listed below"
                warning "You may enter settings manually, <b>OR</b> press Control+left mouse button click to select a well that already has these settings"
                warning "A red box will appear around the selected well"
                # display settings here: loop over hash
                if !(settingshash.nil?)
                    settingshash.each do |key, value|
                        check "Make sure that <b>#{key}</b> is set to <b>#{value}</b>"
                    end
                end
            end
            
            # run
            show do
                title "Select wells and run #{titlestr}"
                check "Using the left mouse button (or the Select/Deselect All links), click on all plate positions to be measured:"
                table displayPositionTable(samplePositions)
                warning "Only the well(s) that are listed in the Aquarium table should be checked"
                check "Click <b>Apply Settings</b> to apply the seetings to all checked wells. You will be prompted to save the workspace"
                check "Save file as <b>#{c6str}</b>"
                check "Click <b>OPEN RUN DISPLAY</b>"
                check "Click <b>AUTORUN</b>"
            end
        else
            show {note "Chosen cytomter #{cytstr} does not exist (#{__method__.to_s})"}
        end # case
    end # runTemplate
    
    #-------------------------------------------------------------------------------------------
    # displays table with cells colored depending on contents:
    # >0 - cell contains culture => shaded, with label
    # -1 - no culture => black (with black text)
    # anything else (should not occur) => red, with label
    #
    # input:
    # tab, >1 if well or position contains culture, else 0
    # 
    # returns:
    # newTab - table with style info, to be used in show block using "table newTab"
    #-------------------------------------------------------------------------------------------            
    def displayPositionTable(tab)
        # deep copy of array before we change it (dup and clone give pointer to the same array)
        newTab= Marshal.load Marshal.dump(tab)
        tab.each_with_index { |row, rr|
            tab[rr].each_with_index { |well, cc|
                #show {note "tab rr=#{rr}, cc=#{cc}, well=#{well}"}
                rrWell="A".ord.to_i + rr # asscii value for A-H, use .chr to convert to asscii character
                ccWell=cc+1 # number
                if(well>0)
                    newTab[rr][cc]={ content: "#{rrWell.chr}#{ccWell}", style: {background: "#e6e6ff" } } #  light purple, white is "#ffffff" 
                else(well==-1)
                    newTab[rr][cc]={ content: "#{rrWell.chr}#{ccWell}", style: {background: "#000000" } } # black
                #else   # not sure if default for unpopulated matrix is -1 or 0, so making both black
                #    newTab[rr][cc]={ content: "#{rrWell.chr}#{ccWell}", style: {background: "#ff0000" } } # red
                end
            }
        }
        return newTab
    end # displayPositionTable
    
end # library
