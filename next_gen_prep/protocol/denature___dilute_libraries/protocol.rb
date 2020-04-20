# Devin Strickland and SG
# dvn.strcklnd@gmail.com
#
# 1) PhiX (if we have no fresh stock) is brought to 4nM
# 2) 4nM libraries are pooled according to pooling algorithm
# 3) pooled library and PhiX are diluted and denatured
# 4) PhiX is added to pool 
needs "Standard Libs/Debug"
needs "Standard Libs/SortHelper"

class Protocol
    
    include Debug
    include SortHelper
        
    TEST_CONCENTRATIONS = [0.5, 4.0, 1.0, 2.0]
    DEFAULT_SPIKE_IN_PCT = 1.0
    
    INPUT_LIBRARY = 'DNA Library Array' 
    OUTPUT_LIBRARY = 'Pooled DNA Library'
    PERCENT_PHIX = "Percentage PhiX"
    OUTPUT_4nM = "DNA Library Array 4nM"
    
    PHIX_EXPIRATION = 3*30*24*60*60 # 3 months ([sec]): MxDxHxMxS
    POOLING_ALGORITHM = "equal"
    LIBRARY_VOLUME = 5 # uL
    NAOH_VOLUME = 5 # uL
    TRIS_HCL_VOL = 5 # uL
    DENATURE_TIME_MIN = 5 # min
    HT1_VOL = 985 # uL
    HT1_VOL_2 = 1183 # uL
    DILUTED_20PM_PM_VOL = 117 # uL
    FINAL_VOL = 1300 # uL
    EQUAL_VOL=2 # uL
    

    def main

        operations.retrieve
        
        # display 
        show {
            title "List of pooled DNA Libraries (#{operations.length} pooled libraries total)"
            operations.each { |op|
                tab=[]
                tab[0]=["DNA Library ID","DNA Library name","bin","barcode"]
                op.input_array(INPUT_LIBRARY).items.each_with_index { |lib, i|
                    tab[i+1]=["#{lib}", "#{lib.sample.name}", "#{lib.get(:bin) || "N/A"}", "#{lib.get(:barcode) || "N/A"}"]
                }
                table tab
            }
        }
        
        
        # check that all have unique barcodes before pooling 
        operations.each { |op|
            barcodes=[] # new for each op = each pool
            problem=0
            op.input_array(INPUT_LIBRARY).items.each { |it|
                bc = it.get(:barcode)
                if(barcodes.include? bc)
                    show {
                        title "Problem with barcodes!"    
                        note "barcode '#{bc}' appears twice, please check!"  
                        problem==1
                    }
                end
                barcodes[barcodes.length] = bc
            }
            if(problem==1)
                op.error(:dupicate_barcode, "The library could not be pooled because of a duplicate barcode") 
            end
        }
        
        # barcodes ok, can make outputs  
        ops = operations.running
        operations = ops
        operations.make 
        
        set_test_concs(INPUT_LIBRARY) if debug
        
        # prepare/retrieve one 4nM phix stock for all operations (multiple pooled libraries)
        phix = prepare_materials 
        
        # pool 4nM libraries and PhiX
        pool_libraries(POOLING_ALGORITHM, INPUT_LIBRARY, OUTPUT_LIBRARY)
        
        denature_libraries(phix) 
        
        incubate_and_quench

        dilute_libraries_to_20pm
        
        dilute_libraries_to_loading

        operations.store(io: "input", interactive: true)
        show {
            title "Return additional items"
            note "Return PhiX 4 nM stock to #{phix} to #{phix.location}"
        } 

        return {}

    end
    
    def prepare_materials
        show do
            title "Thaw HT1 and RSB"
            check "Remove HT1 and RSB from the -20 ªC freezer and thaw at room temperature."
            note "If library preparation is delayed keep thawed HT1 and RSB on ice until you are ready to dilute denatured libraries."
        end
        
        show do
            title "Prepare a Fresh Dilution of NaOH"
            check "Combine the following in a microcentrifuge tube:"
            table [ ["Component" , "Volume (µl)"], 
                ["Laboratory-grade water", "800"],
                ["Stock 1.0 N NaOH", "200"]
            ]
            check "Invert the tube several times to mix."
            note "Use the fresh dilution within <b>12 hours</b>."
        end

        # find phix sample with correct concentration that has not expired
        phix = Item.where(sample_id: Sample.find_by_name("PhiX")).select {|s| (s.get(:concentration).to_f) == 4.0 }

        phix.each { |p|
                begin
                    tmp = DateTime.parse(p.get(:date)).to_i # test items error on this line 
                rescue # attach invalid date if there is no associated date
                    p.associate(:date, "2000-01-01 00:00:00 -0000")
                    #p.save
                #ensure
                    #show { note "#{p}, #{p.get(:concentration)}, #{p.get(:date)}" }
                end
        } if debug # for some reason debug invents phix items with no date
        
        phix = phix.select {|s| (DateTime.now.to_i - DateTime.parse(s.get(:date)).to_i) <  PHIX_EXPIRATION }.first
        
        if(!phix.nil?)
            show do
                title "Retrive PhiX"
                check "Grab PhiX 4 nM stock #{phix} from #{phix.location}"
            end
        else # no fresh 4nM phix ready
            phix_stock = Item.where(sample_id: Sample.find_by_name("PhiX")).select {|s| (s.get(:concentration).to_f) == 10.0 }.first
            phix = produce new_sample "PhiX", of: "DNA Library", as: "Illuminated Fragment Library"
            phix.associate :date, DateTime.now   
            show do 
                title "Dilute PhiX to 4 nM"
                check "Grab PhiX 10 nM stock #{phix_stock} from #{phix_stock.location}"
                check "Thaw the PhiX stock #{phix_stock} (10 µl/tube), vortex and spin down"
                check "Add 15 µl RSB"
                check "Vortex briefly and spin down"
                check "Label the tube #{phix}. Write <b>PhiX 4nM #{Time.zone.now.to_date}</b> on the side of the tube."
            end
            phix_stock.mark_as_deleted
            phix_stock.save
        end
        
        return phix 
    end
    
    def denature_libraries(phix)
        
        tab=Array.new
        tab[0] = ["20 pM library tube label" ,"pooled library", "4nM Sample volume (µl)", "0.2 N NaOH volume (µl)"]
        tab[1] = ["20 pM PhiX","PhiX #{phix}", LIBRARY_VOLUME, NAOH_VOLUME]
        operations.each_with_index { |op, i|
            tab[i+2] = ["20 pM","20 pM L #{op.output(OUTPUT_LIBRARY).item}", 5, 5]
        }
        
        # everything is 4nM at this point, libraries are pooled
        show do
            title "Denature PhiX and Libraries"
            check "Get #{1+operations.length} microcentrifuge tubes"
            check "Label a tube for the 4nM PhiX library <b>20 pM PhiX</b>"
            check "Label tube(s) for the pooled libraries <b>20 pM L</b>. Additionally label the pooled library tubes #{operations.map { |op| op.output(OUTPUT_LIBRARY).item.to_s}.to_sentence }"
            note "Transfer the following volumes of library and <b>freshly diluted</b> 0.2 N NaOH to the <b>20 pM PhiX</b>,  <b>20 pM L</b> tubes:"
            table tab
            check vortex_and_centrifuge
        end
    end
    
    def incubate_and_quench
        show do
            title "Incubate"
            note "Incubate at room temperature for 5 min. Proceed to next step when timer is finished."
            timer initial: { hours: 0, minutes: DENATURE_TIME_MIN, seconds: 0 }
        end
        
        tab=Array.new
        tab[0] = ["20 pM library tube label" , "Tris-HCl volume (µl)"]
        tab[1] = ["20 pM PhiX", TRIS_HCL_VOL]
        operations.each_with_index { |op, i|
            tab[i+2] = ["20 pM L #{op.output(OUTPUT_LIBRARY).item}", TRIS_HCL_VOL]
        }
        
        show do
            title "Quench Denaturation"
            note "<b>Add</b> the following volume of 200 mM Tris-HCl, pH 7 to the <b>20 pM</b> microcentrifuge tubes:"
            table tab
            check vortex_and_centrifuge
        end
    end
    
    def dilute_libraries_to_20pm
        
        tab=Array.new
        tab[0] = ["20 pM library tube label" , "Prechilled HT1 volume (µl)"]
        tab[1] = ["20 pM PhiX", HT1_VOL]
        operations.each_with_index { |op, i|
            tab[i+2] = ["20 pM L #{op.output(OUTPUT_LIBRARY).item}", HT1_VOL]
        }
        
        show do
            title "Dilute Denatured Libraries to 20 pM"
            note "<b>Add</b> the following volume of prechilled HT1 to the <b>20 pM</b> tubes:"
            table tab
            check "<b>Invert</b> to mix and centrifuge at 280 x g for 1 min"
            note "Place the 20 pM libraries on ice until you are ready to proceed to final dilution"
        end
    end
    
    def dilute_libraries_to_loading
        
        tab=Array.new
        tab[0] = ["1.8 pM tube label","From 20 pM library" , "transfer volume (µl)"]
        tab[1] = ["1.8 pM PhiX","20 pM PhiX", DILUTED_20PM_PM_VOL]
        operations.each_with_index { |op, i|
            tab[i+2] = ["1.8 pM #{op.output(OUTPUT_LIBRARY).item}", "20 pM L #{op.output(OUTPUT_LIBRARY).item}", DILUTED_20PM_PM_VOL]
        }

        show do
            title "Dilute Libraries to Loading Concentration (1.8 pM)"
            check "Get #{operations.length + 1} microcentrifuge tubes."
            check "Label a tube for the PhiX library <b>1.8 pM PhiX</b>"
            check "Label tube(s) for the pooled ibraries <b>1.8 pM L</b>. Additionally label the pooled library tubes #{operations.map { |op| op.output(OUTPUT_LIBRARY).item.to_s}.to_sentence }"
            check "Add #{HT1_VOL_2} µl prechilled HT1 to the <b>1.8 pM PhiX</b> tube and to each of the <b>1.8 pM L</b> tubes"
            note "Transfer the denatured <b>20 pM library</b> to the <b>1.8 pM</b> tubes containing HT1, as follows:"
            table tab
            check "<b>Invert</b> to mix and then pulse centrifuge at 280 x g for 1 minute."
        end
        
        # The library and PhiX mixture provides a PhiX spike-in of 0.5%–2.0%. Actual PhiX percentage varies depending upon the quality and quantity of the library pool.
        tab=Array.new
        tab[0] = ["Pooled DNA label", "1.8 pM L volume (µL)", "1.8 pM PhiX volume (µL)"]
        operations.each_with_index { |op, i|
            spike_in_pct = op.input(PERCENT_PHIX).val.to_f
            if(debug) 
                spike_in_pct=0.5 + rand(1) # %
            end
            spike_in_vol = FINAL_VOL * spike_in_pct/100
            library_vol = (FINAL_VOL - spike_in_vol)
            tab[i+1] = ["Pooled DNA #{op.output(OUTPUT_LIBRARY).item}", library_vol, spike_in_vol]
        }
        
        show do
            title "Combine Libraries and PhiX Control"
            check "Get #{operations.length} microcentrifuge tubes and write <b>Pooled DNA</b> on them. Additionally label the pooled DNA tubes #{operations.map { |op| op.output(OUTPUT_LIBRARY).item.to_s}.to_sentence }"
            check "Add denatured <b>1.8 PhiX</b> to the <b>Pooled DNA</b> tubes, as follows:"
            table tab
            #check "<b>Invert</b> to mix and then pulse centrifuge at 280 x g for 1 minute."
            note "Set aside on ice until you are ready to load it onto the reagent cartridge"
        end
    end
    
    # valid "algorithmStr" values: "equal" - take equal of all
    def pool_libraries(algorithmStr, inArray, outPool)
        case algorithmStr
        when "equal"
            volumes=Array.new()
            libs=Array.new()
            h = Hash.new()
            operations.each { |op|
                tab = Array.new()
                tab[0] = ["input library","volume (µL)"]
                op.input_array(inArray).items.each_with_index { |lib, i|
                    tab[i+1] = [lib.to_s, EQUAL_VOL]
                    sub_h = {"volume" => EQUAL_VOL , "barcode" => lib.get(:barcode) }
                    h.store(lib.id, sub_h)
                }
                op.output(OUTPUT_LIBRARY).item.associate(:pool_hash, h)
                
                show {
                    title "hash (in debug)"
                    h.each { |k,v|
                        note "key #{k}, val #{v}"
                    }
                } if debug
                
                show {
                    title "Pool 4nM libraries"
                    check "Grab a 1.5mL tube for the pooled library and label it <b>P</b> #{op.output(outPool).item}"
                    check "Transfer the following volumes from the listed input libraries to the tube <b>P</b> #{op.output(outPool).item}:"
                    table tab
                    check "Vortex and spin down the tube <b>P</b> #{op.output(outPool).item}"
                }
            } 
        else
            show { note "Bad algorithmStr #{algorithmStr} in #{__method__.to_s}, please check!" }
        end
    end
    
    def vortex_and_centrifuge
        return "Vortex all of the <b>20 pM</b> tubes briefly and then centrifuge at 280 × g for 1 minute."
    end
    
    def set_test_concs(inStr)
        operations.each { |op| op.input(inStr).item.associate(:concentration, TEST_CONCENTRATIONS.rotate!.first) }
    end

end