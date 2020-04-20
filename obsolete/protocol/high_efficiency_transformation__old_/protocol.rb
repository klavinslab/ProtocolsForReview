# Devin Strickland
# dvn.strcklnd@gmail.com
#
# SG added batching. if there are multiple transformations, they need to be done 1 at a time.

needs 'Yeast Display/YeastDisplayHelper'
needs 'Standard Libs/Debug'
 
class Protocol
    
    include YeastDisplayHelper, Debug
    
    # I/O
    DNA_MIXES = 'DNA Mix %d'
    COMP_CELLS = 'Comp Cells %d'
    TRANSFORMED = 'Yeast Culture %d'
    PLATES = 'Dilution Plates %d'
    
    # media
    SORBITOL_YPD = 'prewarmed 1M Sorbitol:YPD 1:1'
    DILUTION_MEDIA = 'YPD (peptone)'
    DILUTION_PLATE= "C-His-Trp-Ura plate"
    SELECTION_MEDIA="SDO-His-Trp-Ura"
    
    # labware 
    INCUBATION_FLASK = '250 ml <b>non-baffled</b> flask'
    CUVETTE = '2 mm electroporation cuvette' 
    CONICAL = '50 ml conical tube'
    FLASK_250B="250 mL <b>baffled</b> flask"
    FLASK_250NB="250 mL <b>non-baffled</b> flask"
    FLASK_500B="500 mL <b>baffled</b> flask"
    
    # locations
    SHAKER = '30 C shaker'
    INCUBATOR = '30 C incubator'
    
    WARMED = "#{INCUBATOR}"
    ROOM_TEMP = "AT BENCH"
    ON_ICE = "ON ICE (ON BENCH) OR IN SMALL FREEZER"
    
    # quantities
    SORBITOL_YPD_PER_OP={ qty: 20, units: 'ml'}
    DILUTION_VOL={ qty: 900, units: 'µl'}
    TRANSFER_VOL={ qty: 100, units: 'µl'}
    PLATE_VOL={ qty: 100, units: 'µl'}
    TRANSFORMATIONS_PER_OP=2
    FLASKS_PER_OP=2
    CUVETTES_PER_OP=2
    SERIAL_DILS=3 
    PIPETTES_PER_OP=12
    CONICALS_PER_OP=4
    DILUTION_TUBES_PER_OP=SERIAL_DILS*TRANSFORMATIONS_PER_OP # 3 per transformation
    DILUTION_PLATES_PER_OP=SERIAL_DILS*TRANSFORMATIONS_PER_OP # 3 per transformation

    def main
        
        # no need for retrieve, everything on bench
        operations.make
        
        gather_materials
        
        prepare_dilution_tubes
        
        prepare_flasks
        
        electroporate(DNA_MIXES, COMP_CELLS, TRANSFORMED, PLATES)
        
        incubate_transformations 
        
        dilute_and_plate
        
        # update locations
        operations.each { |op|
            (1..TRANSFORMATIONS_PER_OP).to_a.each do |i| 
                op.input("#{COMP_CELLS % i}").item.mark_as_deleted
                op.input("#{DNA_MIXES % i}").item.mark_as_deleted
                op.output("#{TRANSFORMED % i}").item.move_to(SHAKER)  
                op.output("#{PLATES % i}").item.move_to(INCUBATOR) 
            end
        }
        
        cleanup
        
        prepare_overnight
        
        # no operations.store - everything in place already
        
        return {}
        
    end
    
    def prepare_dilution_tubes
        tab=[]
        tab[0]=["Plate label","Additional Plate ID"]
        operations.each_with_index { |op, ii|
            TRANSFORMATIONS_PER_OP.times do |jj|
                tab[TRANSFORMATIONS_PER_OP*ii + jj + 1] = [{content: "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}A", check: true},
                        "#{op.output("#{PLATES % (jj + 1)}").item}"] 
            end
        }
        
        show do
            title "Prepare dilution tubes for efficiency analysis"
            check "Grab #{DILUTION_TUBES_PER_OP*operations.length} 1.5 mL tubes and a rack to hold them"
            check "Label the tubes: <b>1A, 1B, 1C, 2A, 2B, 2C,</b> etc. (The final label should be <b>#{TRANSFORMATIONS_PER_OP*operations.length}C</b>)"
            check "Organize the tubes in threes on the rack: <b>1A, 1B, 1C</b> together, etc."
            check "Pipet #{DILUTION_VOL[:qty]} #{DILUTION_VOL[:units]} of #{DILUTION_MEDIA} into each tube"
        end
         
        show do
            title "Label plates for efficiency analysis"
            check "Grab #{DILUTION_PLATES_PER_OP*operations.length} #{DILUTION_PLATE}s (from the bench)"
            check "Label the plates: <b>1A, 1B, 1C, 2A, 2B, 2C,</b> etc. (The final label should be <b>#{TRANSFORMATIONS_PER_OP*operations.length}C</b>)"
            check "Additionally label all plates with <b>A</b> according to the following table:"
            table tab
            check "Organize the tubes in stacks of three according to <b>numerical index</b> (<b>1A, 1B, 1C</b> together, etc.)" 
        end
    end
    
    def prepare_flasks
        show do
            title "Prepare flasks"
            check "Grab #{TRANSFORMATIONS_PER_OP*operations.length} #{FLASK_250NB} flasks and label them <b>1</b> to <b>#{TRANSFORMATIONS_PER_OP*operations.length}</b>"
            check "Grab #{TRANSFORMATIONS_PER_OP*operations.length} #{FLASK_500B} flasks and label them <b>1</b> to <b>#{TRANSFORMATIONS_PER_OP*operations.length}</b>"
        end
    end
    
    def dilute_and_plate
        
        tab2=[]
        tab2[0]=["Transformation","tube <b>A</b>","tube <b>B</b>","tube <b>C</b>"]
        operations.each_with_index { |op, ii|
            TRANSFORMATIONS_PER_OP.times do |jj|
                tab2[TRANSFORMATIONS_PER_OP*ii + jj + 1] = [{content: "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}", check: true},
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}A", 
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}B", 
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}C"] 
            end
        }
        
        show do
            title "Serially dilute for efficiency analysis"
            note "Serially dilute samples in tube <b>A</b> into tubes labeled <b>B,C</b>. Use the following table to keep track!"
            table tab2
            note "Use the following table to keep track of serial dilutions:"
            check "Vortex tube <b>A</b>"
            check "Transfer #{TRANSFER_VOL[:qty]} #{TRANSFER_VOL[:units]} from tube <b>A</b> to tube <b>B</b>"
            check "Vortex tube <b>B</b>"
            check "Transfer #{TRANSFER_VOL[:qty]} #{TRANSFER_VOL[:units]} from tube <b>B</b> to tube <b>C</b>"
            check "Vortex tube <b>C</b>"
        end
        
        show do
            title "Plate dilutions for efficiency analysis"
            check "Plate #{PLATE_VOL[:qty]} #{PLATE_VOL[:units]} of tubes <b>A,B,C</b> to plates <b>A,B,C</b>, according to the following table:"
            table tab2
            check "Tape each #{SERIAL_DILS} plates <b>A,B,C</b> with the same <b>numerical index</b> together, with plate <b>A</b> on top"
            check "Place all plates in the #{INCUBATOR}"
        end
        
        # associate 'source' culture with dilution plates
        operations.each { |op|
            TRANSFORMATIONS_PER_OP.times do |jj|
                op.output("#{PLATES % (jj + 1)}").item.associate :source, op.output("#{TRANSFORMED % (jj + 1)}").item.id
            end 
        }
    end
     
    def gather_materials
        show do
            title 'Gather the following additional materials'
            warning "The materials should be located on the bench closest to the large centrifuge" 
            
            note "Retrieve from #{WARMED}"
            check "#{SORBITOL_YPD} (you will need #{SORBITOL_YPD_PER_OP[:qty]*operations.length} #{SORBITOL_YPD_PER_OP[:units]})"

            note "Locate #{ROOM_TEMP}"
            check "#{operations.length*FLASKS_PER_OP} #{INCUBATION_FLASK}s"
            check "#{operations.length} #{INCUBATION_FLASK}s"
            check "#{DILUTION_PLATES_PER_OP*operations.length} #{DILUTION_PLATE}s"
            
            note "Locate #{ON_ICE}"
            check "#{operations.length*CUVETTES_PER_OP} #{CUVETTE}s" 
            check "Competent cells "
            check "Dna Mixes "
        end
    end
    
    def electroporate(dna_str, cc_str, flask_str, plates_str)
        tab=[]
        tab[0]=["Transformation","Comp Cells ID","DNA Mix ID","#{FLASK_250NB}","1.5 mL tube"]
        operations.each_with_index { |op, ii|
            TRANSFORMATIONS_PER_OP.times do |jj|
                tab[TRANSFORMATIONS_PER_OP*ii + jj + 1] = [{content: "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}", check: true},
                        "#{op.input("#{cc_str % (jj + 1)}").item}", 
                        "#{op.input("#{dna_str % (jj + 1)}").item}", 
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}",
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}A"]
            end
        }
        show do
            title "Electroporate cells"
            check 'Set the electroporator to 2.5 kV' # and 25 µF - we do not have this option 
            warning "Perform ALL of the steps on this slide for each row in table before advancing to the next row"
            table tab
            check "Transfer the entire aliquot of <b>Comp Cells</b> to the <b>DNA Mix</b> using a chilled tip."
            check 'Mix gently by pipetting. <b>Do not vortex</b>.'
            check "Transfer the entire volume to a <b>chilled</b> #{CUVETTE} and place the mixture on ice"
            timer initial: { hours: 0, minutes: 5, seconds: 0}
            check 'Place the cuvette in the electroporator and push <b>Pulse</b>.'
            check "1 ml at a time, pipette a total of 8 ml of #{SORBITOL_YPD} into the cuvette, then pipet it into the <b>Output Flask</b>. <b>Use a new tip for each ml of #{SORBITOL_YPD}.</b>"
            check "Transfer #{TRANSFER_VOL[:qty]} #{TRANSFER_VOL[:units]} from the <b>Output Flask</b> into the 1.5 tube labeled with the same row number and the letter <b>A</b> (from <b>Output Flask</b> in row <b>1</b> into <b>1A</b>, etc.)"
            check "Place the <b>Output Flask</b> in the #{SHAKER}."
        end
    end 
    
    def incubate_transformations
        show do 
            title 'Incubate transformations (recovery step)'
            timer initial: { hours: 1, minutes: 0, seconds: 0}
            note "Proceed to next step while you are waiting"
        end
    end 
    
    def cleanup
        cc_ids=[operations.map{|op| op.input("#{COMP_CELLS % 1}").item},operations.map{|op| op.input("#{COMP_CELLS % 2}").item}].flatten
        mix_ids=[operations.map{|op| op.input("#{DNA_MIXES % 1}").item}, operations.map{|op| op.input("#{DNA_MIXES % 2}").item}].flatten
        show do
            title "Intermediate Cleanup (while waiting for recovery)"
            note "Trash the following:"
            check "All used cuvettes"
            check "All used #{CONICAL}s"
            check "All 1.5mL tubes that contained comp cells (#{cc_ids.to_sentence}) and DNA mixes (#{mix_ids.to_sentence}) "
            check "All used 1.5mL tubes used for serial dilution (labeled <b>A,B,C</b>)"
            check "Take any used flasks to the washing station" 
        end
    end
    
    def prepare_overnight
        tab=[]
        tab[0]=["Transformation","#{FLASK_250NB}","#{FLASK_500B}","final #{FLASK_500B} label"]
        operations.each_with_index { |op, ii|
            TRANSFORMATIONS_PER_OP.times do |jj|
                tab[TRANSFORMATIONS_PER_OP*ii + jj + 1] = [{content: "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}", check: true},
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}", 
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}", 
                        "#{op.output("#{TRANSFORMED % (jj + 1)}").item}"]
            end
        } 
        show do 
            title 'Final Step'
            check "Grab the #{FLASK_500B}(s) labeled <b>1</b> to <b>#{TRANSFORMATIONS_PER_OP*operations.length}</b>"
            check "Transfer 100mL #{SELECTION_MEDIA} to each #{FLASK_500B}"
            check "When the timer is finished, pour cultures into #{CONICAL}s labeled  <b>1</b> to <b>#{TRANSFORMATIONS_PER_OP*operations.length}</b>"
            check "Spin at 3000rpm for 3min. Pour off supernatant"
            note "Resuspend each transformation into the #{FLASK_500B} using the media in the flask, and label the #{FLASK_500B} as follows:"
            table tab
        end
    end 
    
end