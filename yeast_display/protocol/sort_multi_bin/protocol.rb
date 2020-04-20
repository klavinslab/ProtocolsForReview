# SG
#
# skeleton protocol for multi-bin FACS 
# used to extract the expression profiles of single variants within an Agilent-like variant library
#
# data needed for analysis:
# 1) bin and variant identities of the sorted cells (obtained downstream using NGS)
# 2) expression distribution of mixed sample (percentage of total population in each bin - used for normalization)
# 3) bin edges (min, max expression in each bin)
#
class Protocol
    
    # I/O
    BINS="Binned Yeast Library (array)"
    LIB="Labeled Yeast Library"
    
    # other
    FACS_LOCATION="Pathology Cytometry Unit"
    FACS_TUBE="small FACS tube"
    NUM_PLACES=4 # number of tube positions in simultaneous sort
    EXPERIMENT="Experiment -> New Experiment -> from template -> "
    FACS_PARAMETERS=[["<b>Parameter</b>","<b>voltage</b>","<b>log</b>","<b>A</b>","<b>H</b>","<b>W</b>"],
                     ["SSC",250,"unchecked","checked","checked","checked"],
                     ["FSC",260,"unchecked","checked","checked","checked"],
                     ["FITC",475,{content: "checked", check: true},"checked","checked","checked"]] 
    COLLECT_EVENTS=30000 # events to collect for non-sorted samples
    COLLECT_LIB_EVENTS=1000000 # events to collect for library only
    SORT_EVENTS=500000 # events to sortt into each bin
    FLOW_RATE=10.0 # FACS parameter
    SAVE_DIR="/Data/Aria/dstrickland"
    MAX_ITER=6
    TEMPLATE={"2" => "biofab_sort_yeast_v3", "4" =>"BIOFAB_8bin_sort", "8" =>"BIOFAB_8bin_sort"} # key=num_samples, val=experimental template
    DEFAULT_TEMPLATE="8"

    def main
 
        operations.retrieve.make
        
        operations.each { |op|
        
            # number of sorted samples 
            num_samples=op.output_array(BINS).length
            num_samples=8 if debug
            valid_num_samples=TEMPLATE.keys.map { |k| k.to_f.round }
            if( ! (valid_num_samples.include? num_samples) )
                template=TEMPLATE.fetch(DEFAULT_TEMPLATE)
                show { note "There is no template for #{num_samples}-bin sorting! Valid values are #{valid_num_samples}. Using #{template}."}
            else
                template=TEMPLATE.fetch("#{num_samples}")
            end
            tube=FACS_TUBE
            time_now=Time.zone.now
            exp_name="PLAN_#{op.plan.id}_JOB_#{jid}_#{time_now.to_date}"
            
            # associate bin labels to output items 
            sorted_bins=op.output_array(BINS).item_ids.sort
            sorted_bins.each_with_index { |bin_id, i|
                it=Item.find(bin_id).associate :bin, "P#{i+1}"
            }
        
            # choose experiment based on number of outputs
            show {
                title "Experiment Setup"
                if(op==operations.first)
                    note "Login with username <b>dstrickland</b>, password <b>path_flow</b>"
                end
                check "Turn on sweet spot (purple and yellow in sweet spot icon should touch)"
                warning "MAKE SURE SWEET SPOT IS ON!"
                note "Open new experiment as follows:"
                note "<b>#{EXPERIMENT}#{template}</b>"
                note "Rename experiment <b>#{exp_name}</b>"
            }
            
            # check FACS parameters
            data = show {
                title "Check FACS parameters"
                note "Under the experiment folder, Double-click on <b>Cytometer Settings</b>. In the <b>Cytometer</b> window, <b>Parameters</b> tab, check that the settings match the following:"
                table FACS_PARAMETERS
            }
             
            # Collect data
            collect_table=[]
            collect_table[0]=["Item ID", "Sample", "Tube name (in software)", "Number of events", "Flow Rate"]
            collect_table[1]=[" ", "beads", "beads", {content: COLLECT_EVENTS, check: true}, FLOW_RATE]
            op.inputs.each_with_index { |inp, i|
                num_events = (inp.name==LIB) ? COLLECT_LIB_EVENTS : COLLECT_EVENTS
                collect_table[i+2]=["#{inp.item}", inp.sample.name, inp.name, {content: "#{num_events}", check: true}, FLOW_RATE]
            }
            show {
                title "Collect fluorescence data"
                table collect_table
                note "Collect data for each tube listed, as follows:"
                note "Load physical tube: place in holder and press <b>Upload</b>"
                note "Double click on software tube to make it active (green arrow icon)"
                note "Press <b>Acquire</b>"
                note "Press <b>Record Data</b>"
                note "When the events have been collected acquisition will stop. Press <b>Unload</b> to unload physical tube"
                warning "Make sure physical and software tube labels match!"
            }
            
            # choose bins and save screenshot
            show {
                title "Set up tubes, tube holder, and software gates for sort"
                note "Label #{num_samples} #{tube}s <b>P1-P#{num_samples}</b>"
                note "Check that the physical holder for the sorted cells has room for #{[num_samples,NUM_PLACES].min} #{tube}s. If not, ask the #{FACS_LOCATION} personnel to change the holder."
                note "Set up interval gates <b>P1-P#{num_samples}</b>:" 
                note "Gates <b>P1-P#{num_samples}</b> should cover the population in the <b>counts vs. FITC</b> plot. Intervals should be without gaps or overlap - the right edge of gate <b>P1</b> and the left edge of <b>P2</b> should be at the same FITC value, etc."
                note "Each of gates <b>P1-P#{num_samples}</b> should cover about #{(100.0/num_samples).round(1)}% of the population"
                note "Additional gates <b>P#{num_samples+1} and P#{num_samples+2}</b> are used to verify that there are very few cells that we are NOT collecting:"
                note "<b>P#{num_samples+2}</b> should cover the area from the right of <b>P#{num_samples}</b> to the right edge of the plot, about 1% of the population."
                note "<b>P#{num_samples+1}</b> should cover the area from 0 to the left of <b>P1</b>, about 1% of the population."
                note "When you are done positioning the gates, drag all tables and plots on the right screen to the 'math-paper' region. Export to pdf by clicking the pdf icon. Save under <b>#{SAVE_DIR}/#{time_now.day}#{time_now.month}#{time_now.year}/#{exp_name}</b>."
                warning "Do <b>NOT</b> change the gates from now on!"
            }
            
            # collect sorted cells iteratively, for 2 reasons:
            # 1) we want to average over time fluctuations of the samples/machine
            # 2) we want collect as much as possible, within the sample volume/time limits, but do not know what this number is in advance
            bins=op.output_array(BINS)
            finished=false
            iter=0
            now_sorting=SORT_EVENTS
            tot_cells=0
            # each iteration is a full sort
            loop do 
                iter=iter+1
                cur_bins=(1..[num_samples,NUM_PLACES].min).to_a
                break if ((finished) || (iter>MAX_ITER))
                sorts_per_iter=[(num_samples/NUM_PLACES),1].max # needed if num_samples > NUM_PLACES 
                sorts_per_iter.times { |j|
                    # bins in current sort
                    cur_bins=cur_bins.map{ |b| b+j*NUM_PLACES } 
                    # place tubes in holder
                    show {
                        title "Place collection tubes #{cur_bins.map{ |b| "P#{b}" }.to_sentence} in holder"
                        if(iter>1)
                            warning "You are collecting into the same tubes used previously. Make sure the tube labels and order match those in the sort panel!"
                        end
                        note "Locate #{tube}s <b>#{cur_bins.map{ |b| "P#{b}" }.to_sentence}</b>"
                        note "Place the labeled #{tube}s in the holder, with increasing number from left to right"
                    }
                    # sort
                    show {
                        title "Sort bin(s) #{cur_bins.map{ |b| "P#{b}" }.to_sentence}"
                        note "Select tube <b>sort_#{cur_bins.min}-#{cur_bins.max}</b> (arrow icon should be green)"
                        note "Choose sort profile <b>sort_#{cur_bins.min}-#{cur_bins.max}</b>"
                        note "Change number of cells to #{now_sorting}"
                        note "Select <b>4-way Purity</b> and <b>Save Sort Reports</b>"
                        note "Set software bins to <b>#{cur_bins.map{ |b| "P#{b}" }.to_sentence}</b>, from left to right"
                        note "Press on <b>Acquire</b> on tube panel, <b>Sort</b> on sort panel, and <b>OK</b> in dialog box"
                        note "Collect data for #{COLLECT_EVENTS} events while you are sorting (tube panel)"
                        warning "Check volume of input library #{op.input(LIB).item}. Make sure level is above turquoise filter!"
                        warning "Check volumes of #{tube}s <b>#{cur_bins.map{ |b| "P#{b}" }.to_sentence}</b>. Replace tubes as needed. Remember to label replacement tubes with same label as original tube!"
                        note "When #{now_sorting} cells have been collected for all bins, cap samples and place on ice"
                    }
                    # enough cells for additional sort?
                    if(j+1==sorts_per_iter) # full set of bins
                        tot_cells=tot_cells+now_sorting # update number of cells per bin
                        data = show {
                            title "Estimate remaining volume"
                            note "To get better statistics, we want to sort as many cells as possible. You will repeat the sort steps until you have run out of FACS time or input library #{op.input(LIB).item}."
                            get "text", var: :answer, label: "Is there enough volume for an additional sort?", default: "Y"
                            get "number", var: :sort_cells, label: "If yes, how many more cells you think you can collect?", default: SORT_EVENTS
                            note "If you are not sure, give a low estimate like 50,000 so that you will have enough for all #{num_samples} bins."
                            
                        }
                        finished = !(data[:answer]=="Y")  
                        now_sorting = data[:sort_cells].to_f.round
                    end
                } #
            end # loop
            
            # how many collected? 
            op.output_array(BINS).items.each_with_index { |it, i|
                it.associate :cells_sorted, tot_cells
            }
            
            # display mapping beteen outputs and tube labels
            mapping=[]
            mapping[0]=["tube label","library ID"]
            op.output_array(BINS).items.each_with_index { |it, i|
                mapping[i+1]=["#{it}",it.get(:bin)]
            }
            show {
                title "Mapping of samples to tubes"
                table mapping
            }
            
            if(op==operations.last)
                # cleanup
                show {
                    title "Shut down FACS"
                    warning "Make sure you have capped all sorted samples and placed them on ice"
                    note "Press <b>sweet spot off</b>"
                    warning "Do not forget to turn sweet spot off!"
                    note "Press <b>File->logout</b>"
                    note "Log in as <b>ShutdownDaily</b> (leave password blank)"
                    note "On left panel, select <b>daily shutdown 70u</b>. Double click on it to open."
                    note "Under <b>Specimen_</b>, select <b>bleach 4 min.</b> (arrow icon should be green)"
                    note "Place physical sample labeled <b>10% bleach</b> in sample holder (bleach sample should be in the rack to the right of the cytometer)"
                    note "Adjust flow rate to 10, load sample, record data. Overwrite existing data."
                    note "Notify the #{FACS_LOCATION} personnel that you are done (you do <b>not</b> need to wait for data to be collected)"
                    note "Take samples back to lab and notify lab manager that you are back"
                }
            end
            
        }
     
        # delete inputs
        operations.each { |op|
            op.inputs.each { |inp|
                inp.item.mark_as_deleted
            }
        }
        
        return {}
    
    end

end
