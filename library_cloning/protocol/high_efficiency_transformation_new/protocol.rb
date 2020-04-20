# Devin Strickland
# dvn.strcklnd@gmail.com
# SG added batching so that transformations could be split among multiple techs, if available.
needs 'Yeast Display/YeastDisplayHelper'
needs 'Standard Libs/Debug'
needs 'Standard Libs/SortHelper'
 
class Protocol
    
    include YeastDisplayHelper, Debug, SortHelper
    
    # I/O
    DNA_MIXES = 'DNA Mix %d'
    COMP_CELLS = 'Comp Cells %d'
    TRANSFORMED = 'Yeast Culture %d'
    PLATES = 'Dilution Plates %d'
    
    # media
    SORBITOL_YPD = 'prewarmed 1M Sorbitol:YPD 1:1'
    DILUTION_PLATE= "C-His-Trp-Ura plate"
    SELECTION_MEDIA="SDO-His-Trp-Ura"
    DILUTION_MEDIA = SELECTION_MEDIA
     
    # labware 
    CUVETTE = '2mm electroporation cuvette' 
    FLASK_250NB="250 mL <b>non-baffled</b> flask"
    FLASK_500B="500 mL <b>baffled</b> flask"
    
    # locations
    SHAKER = '30 C shaker'
    INCUBATOR = '30 C incubator'
    
    # instructions
    WARMED = "#{INCUBATOR}"
    ROOM_TEMP = "AT BENCH"
    ON_ICE = "ON ICE (ON BENCH) OR IN SMALL FREEZER"
    
    # quantities
    SORBITOL_YPD_PER_OP={ qty: 110, units: 'mL'}
    DILUTION_VOL={ qty: 900, units: 'µl'}
    TRANSFER_VOL={ qty: 100, units: 'µl'}
    PLATE_VOL={ qty: 100, units: 'µl'}
    CULTURE_VOL={ qty: 100, units: 'mL'}
    TRANSFORMATIONS_PER_OP=1
    CUVETTES_PER_OP=TRANSFORMATIONS_PER_OP #*1
    SERIAL_DILS=3
    PIPETTES_PER_OP=TRANSFORMATIONS_PER_OP #*6
    DILUTION_TUBES_PER_OP=SERIAL_DILS*TRANSFORMATIONS_PER_OP # 3 per transformation
    DILUTION_PLATES_PER_OP=SERIAL_DILS*TRANSFORMATIONS_PER_OP # 3 per transformation
    INCUBATION_TIME={ hr: 1, min: 0, sec: 0}
 
    def main
        
        
        # sort ops - this only helps there is 1 transformation per operation
        ops_sorted=sortByMultipleIO(operations, ["in"], ["DNA Mix 1"], ["id"], ["item"]) 
        operations=ops_sorted
        operations.make 
        
        # no need for retrieve, everything on bench
        operations.make
        
        gather_materials
        
        electroporate
        
        incubate_transformations 
        
        prepare_dilution_tubes
        
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
        
        prepare_overnight
        
        cleanup
        
        # no operations.store - everything in place
        
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
            title "Prepare the following while cells are recovering"
            check "Grab #{TRANSFORMATIONS_PER_OP*operations.length} #{FLASK_500B}(s) and label them <b>1</b> to <b>#{TRANSFORMATIONS_PER_OP*operations.length}</b>"
            check "Grab #{DILUTION_TUBES_PER_OP*operations.length} 1.5 mL tubes and a rack to hold them"
            check "Label the tubes: <b>1A, 1B, 1C, 2A, 2B, 2C,</b> etc. (The final label should be <b>#{TRANSFORMATIONS_PER_OP*operations.length}C</b>)"
            check "Organize the tubes in threes on the rack: <b>1A, 1B, 1C</b> together, etc."
            check "Pipet #{DILUTION_VOL[:qty]} #{DILUTION_VOL[:units]} of #{DILUTION_MEDIA} into each tube"
            check "Grab #{DILUTION_PLATES_PER_OP*operations.length} #{DILUTION_PLATE}s (from the bench)"
            check "Label the plates: <b>1A, 1B, 1C, 2A, 2B, 2C,</b> etc. (The final label should be <b>#{TRANSFORMATIONS_PER_OP*operations.length}C</b>)"
            check "Additionally label all plates with <b>A</b> according to the following table:"
            table tab
            check "Organize the plates in stacks of three according to <b>numerical index</b> (<b>1A, 1B, 1C</b> together, etc.)" 
            warning "Proceed immediately to the next step when the timer finishes"
        end
    end
    
    def dilute_and_plate
        tab2=[]
        tab3=[]
        tab2[0]=["Transformation","#{FLASK_250NB}","tube <b>A</b>","tube <b>B</b>","tube <b>C</b>"]
        tab3[0]=["Transformation","tube -> plate <b>A</b>","tube -> plate <b>B</b>","tube -> plate <b>C</b>"]
        operations.each_with_index { |op, ii|
            TRANSFORMATIONS_PER_OP.times do |jj|
                tab2[TRANSFORMATIONS_PER_OP*ii + jj + 1] = [{content: "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}", check: true},
                        "#{ii + jj + 1}",
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}A", 
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}B", 
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}C"] 
                tab3[TRANSFORMATIONS_PER_OP*ii + jj + 1] = [{content: "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}", check: true},
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}A", 
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}B", 
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}C"] 
            end
        }
        
        show do
            title "Serially dilute for efficiency analysis"
            check "Grab the #{FLASK_250NB}(s) labeled <b>1</b> to <b>#{operations.length}</b> from the #{SHAKER}"
            note "Serially dilute samples in tube <b>A</b> into tubes labeled <b>B,C</b> as indicated in the following table:"
            table tab2
            check "Transfer #{TRANSFER_VOL[:qty]} #{TRANSFER_VOL[:units]} from #{FLASK_250NB} to tube <b>A</b>"
            check "Vortex tube <b>A</b>"
            check "Transfer #{TRANSFER_VOL[:qty]} #{TRANSFER_VOL[:units]} from tube <b>A</b> to tube <b>B</b>"
            check "Vortex tube <b>B</b>"
            check "Transfer #{TRANSFER_VOL[:qty]} #{TRANSFER_VOL[:units]} from tube <b>B</b> to tube <b>C</b>"
            check "Vortex tube <b>C</b>"
        end
        
        show do
            title "Plate dilutions for efficiency analysis"
            check "Plate #{PLATE_VOL[:qty]} #{PLATE_VOL[:units]} of tubes <b>A,B,C</b> to plates <b>A,B,C</b>, according to the following table:"
            table tab3
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
        cc_ids=[]
        mix_ids=[]
        operations.each_with_index { |op, ii|
            TRANSFORMATIONS_PER_OP.times do |jj|
                cc_ids=[cc_ids, op.input("#{COMP_CELLS % (jj + 1)}").item].flatten
                mix_ids=[mix_ids, op.input("#{DNA_MIXES % (jj + 1)}").item].flatten
            end
        }
        
        show do
            title 'You will need these materials'
            warning "The materials have been prepared on the bench closest to the large centrifuge" 
            
            note "Locate #{ROOM_TEMP}"
            check "#{operations.length*TRANSFORMATIONS_PER_OP} #{FLASK_250NB}(s)"
            check "#{operations.length*TRANSFORMATIONS_PER_OP} #{FLASK_500B}(s)"
            check "#{DILUTION_PLATES_PER_OP*operations.length} #{DILUTION_PLATE}s"
            check "For serial dilutions: #{DILUTION_MEDIA} (at least #{(DILUTION_VOL[:qty].to_f/1000).ceil*SERIAL_DILS*operations.length*TRANSFORMATIONS_PER_OP} mL)"
            check "For culture: #{SELECTION_MEDIA} (at least #{operations.length*CULTURE_VOL[:qty]} #{CULTURE_VOL[:units]})"
            
            note "Locate #{ON_ICE}"
            check "#{operations.length*CUVETTES_PER_OP} #{CUVETTE}(s)" 
            check "Competent cell aliquot(s) " # previously #{cc_ids.to_sentence}. id does not matter - these are identical until used, and then trashed.
            check "DNA Mix(es) #{mix_ids.sort.to_sentence}"
            
            note "Retrieve from #{WARMED}"
            check "#{SORBITOL_YPD} (you will need #{SORBITOL_YPD_PER_OP[:qty]*operations.length} #{SORBITOL_YPD_PER_OP[:units]})"
        end
    end
    
    
    def electroporate
        tab=[]
        tab[0]=["Comp Cells","DNA Mix ID","#{FLASK_250NB}"]
        operations.each_with_index { |op, ii|
            TRANSFORMATIONS_PER_OP.times do |jj|
                tab[TRANSFORMATIONS_PER_OP*ii + jj + 1] = [{content: "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}", check: true},
                        "#{op.input("#{DNA_MIXES % (jj + 1)}").item}", 
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}"]
            end
        }
        show do
            title "Electroporate cells"
            check "Grab #{TRANSFORMATIONS_PER_OP*operations.length} #{FLASK_250NB}(s) and label them <b>1</b> to <b>#{TRANSFORMATIONS_PER_OP*operations.length}</b>"
            check 'Set the electroporator to 2.5 kV' # and 25 F - we do not have this option 
            warning "Perform <b>ALL</b> of the steps on this slide for each row in table before advancing to the next row"
            table tab
            check "Transfer the entire aliquot of <b>Comp Cells</b> to the <b>DNA Mix</b> using a chilled tip."
            check 'Mix gently by pipetting. <b>Do not vortex</b>.'
            check "Transfer the entire volume to a <b>chilled</b> #{CUVETTE} and place the mixture on ice"
            timer initial: { hours: 0, minutes: 5, seconds: 0}
            check 'Place the cuvette in the electroporator and push <b>Pulse</b>.'
            check "<b>1 ml</b> at a time, pipette a total of <b>8 ml</b> of #{SORBITOL_YPD} into the cuvette, then pipet it into the <b>#{FLASK_250NB}</b>. <b>Use a new tip for each ml of #{SORBITOL_YPD}.</b>"
            check "Place the <b>#{FLASK_250NB}</b> in the #{SHAKER}" 
        end
    end 
    
    def incubate_transformations
        show do 
            title 'Incubate transformations (recovery step)'
            timer initial: { hours: INCUBATION_TIME[:hr], minutes: INCUBATION_TIME[:min], seconds: INCUBATION_TIME[:sec]}
            warning "Proceed to the next step while cells are recovering!"
        end
    end 
    
    def cleanup
        cc_ids=[]
        mix_ids=[]
        operations.each_with_index { |op, ii|
            TRANSFORMATIONS_PER_OP.times do |jj|
                cc_ids=[cc_ids, op.input("#{COMP_CELLS % (jj + 1)}").item].flatten
                mix_ids=[mix_ids, op.input("#{DNA_MIXES % (jj + 1)}").item].flatten
            end
        }
        show do
            title "Cleanup"
            check "Trash all used cuvettes and serological pipettes"
            check "Trash all 1.5mL tubes that contained comp cells (#{cc_ids.to_sentence}) and DNA mixes (#{mix_ids.to_sentence})"
            check "Trash all 1.5mL tubes used for serial dilution (labeled <b>A,B,C</b>)"
            check "Take all used #{FLASK_250NB}(s) to the washing station"
        end 
    end 
    
    def prepare_overnight
        tab=[]
        tab[0]=["Transformation","from #{FLASK_250NB}","to #{FLASK_500B}","#{FLASK_500B} Aquarium ID"]
        operations.each_with_index { |op, ii|
            TRANSFORMATIONS_PER_OP.times do |jj|
                tab[TRANSFORMATIONS_PER_OP*ii + jj + 1] = [{content: "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}", check: true},
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}", 
                        "#{TRANSFORMATIONS_PER_OP*ii + jj + 1}", 
                        "#{op.output("#{TRANSFORMED % (jj + 1)}").item}"]
            end
        } 
        
        culture_ids=[]
        operations.each_with_index { |op, ii|
            TRANSFORMATIONS_PER_OP.times do |jj|
                culture_ids=[culture_ids, op.output("#{TRANSFORMED % (jj + 1)}").item].flatten
            end
        }
        
        show do 
            title 'Prepare overnight cultures'
            check "Grab the #{FLASK_500B}(s) labeled <b>1</b> to <b>#{TRANSFORMATIONS_PER_OP*operations.length}</b>"
            check "Transfer #{CULTURE_VOL[:qty]} #{CULTURE_VOL[:units]} #{SELECTION_MEDIA} to each #{FLASK_500B}"
            check "Pour the entire contents of each #{FLASK_250NB} into the indicated #{FLASK_500B}, and add an Aquarium ID to the #{FLASK_500B}, as follows:"
            table tab
            check "Transfer the #{FLASK_500B}(s) #{culture_ids.to_sentence} to the #{SHAKER}"
        end
    end 
    
end