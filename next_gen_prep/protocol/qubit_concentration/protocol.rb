# SG
# 
# measure sample concentration using Qubit before NGS run
needs "Standard Libs/SortHelper"
class Protocol

    include SortHelper

    # I/O
    IN="qPCR sample in"
    OUT="qPCR sample out"
    
    # other
    LAB="Biofab" # name of lab where Qubit is located
    BIOFAB="Biofab"
    Q_HS_BUFFER="Qubit 1x dsDNA HS Working Solution"
    NUM_STANDARDS=2
    Q_STANDARD_1="Qubit dsDNA HS Standard #1"
    Q_STANDARD_2="Qubit dsDNA HS Standard #2" 
    STANDARD_LOCATION="Media fridge"
    Q_TUBES="Qubit assay tube"
    STANDARD_VOL=10 #µL
    STANDARD_BUFFER_VOL=200-STANDARD_VOL #µL
    SAMPLE_VOL=2 #µL
    SAMPLE_BUFFER_VOL=200-SAMPLE_VOL #µL
    Q_ASSAY="dsDNA"
    Q_UNITS="ng/µL"
    
    def main
        
        operations.retrieve
        # NO MAKE - we are just passing
        
        # sort so that input ids and sample labels are in consecutive order
        ops = sortByMultipleIO(operations, ["in"], [IN], ["id"], ["item"])
        operations = ops
        
        # get more stuff
        show {
            title "Grab the following items"
            note "All items are located in #{STANDARD_LOCATION}"
            check "<b>#{Q_HS_BUFFER}</b>"
            check "<b>#{Q_STANDARD_1}</b>"
            check "<b>#{Q_STANDARD_2}</b>"
        }
        
        # prep standards
        show {
            title "Prepare standards"
            warning "In the following, make sure you are using #{Q_TUBES}s"
            warning "Label <b>lids</b> only"
            check "Grab #{NUM_STANDARDS} #{Q_TUBES}s, label their <b>lids</b> <b>S1</b> and <b>S2</b>"
            check "Add <b>#{STANDARD_BUFFER_VOL} µL</b> of <b>#{Q_HS_BUFFER}</b> to each of <b>S1</b>, <b>S2</b>"
            check "Add <b>#{STANDARD_VOL} µL</b> of #{Q_STANDARD_1} to <b>S1</b>"
            check "Add <b>#{STANDARD_VOL} µL</b> of #{Q_STANDARD_2} to <b>S2</b>"
        }
        
        # vortex and spin 
        show {
            title "Vortex and spin samples"
            check "Vortex and spin samples #{operations.map{|op| op.input(IN).item}.to_sentence } to mix contents thoroughly"   
        }
        
        # prep samples
        show {
            title "Prepare samples"
            warning "In the following, make sure you are using #{Q_TUBES}s"
            warning "Label <b>lids</b> only"
            check "Grab #{operations.length} #{Q_TUBES}(s), label their <b>lids</b> <b>D1</b> to <b>D#{operations.length}</b>"
            note "Prepare the following diluted samples:"
            table operations.start_table
                .custom_column(heading: "Dilute sample") { |op| "D#{operations.index(op) + 1}" }
                .custom_column(heading: "#{Q_HS_BUFFER} (µL)") { |op| SAMPLE_BUFFER_VOL }
                .input_item(IN)
                .custom_column(heading: "Sample volume (µL)") { |op| SAMPLE_VOL }
                .end_table
            check "Vortex diluted samples to mix contents thoroughly"   
            check "Incubate at room temperature for 2 minutes"
            if(LAB==BIOFAB)
                timer initial: { hours: 0, minutes: 2, seconds: 0}
            else
                note "In the meantime, take the standards <b>S1, S2</b> and samples <b>D1-D#{operations.length}</b> to the #{LAB} lab"
            end
        }
        
        # measure on Qubit
        show {
            title "Measure standards and samples on Qubit"
            if(LAB!=BIOFAB)
                warning "You will be using the #{LAB} lab's Qubit. Ask permission from someone in the lab!"
            end
            check "Turn on the machine and select the <b>#{Q_ASSAY}</b> assay on the home screen"
            check "Enter <b>original sample volume</b>: <b>#{SAMPLE_VOL} µL</b>"
            check "Enter <b>output sample units</b>: <b>#{Q_UNITS}</b>"
            check "You will be prompted to measure standards <b>S1</b> and <b>S2</b>. Do so."
            check "Measure samples <b>D1</b> to <b>D#{operations.length}</b>. Enter the results into the following table:"
            table operations.start_table
                .custom_column(heading: "Dilute sample") { |op| "D#{operations.index(op) + 1}" }
                .input_item(IN) 
                .get(:concentration, type: "number", heading: "Concentration (#{Q_UNITS})", default: 1.0)
                .end_table
        }
         
        operations.each { |op|
            op.input(IN).item.associate :concentration, op.temporary[:concentration]
            op.pass(IN,OUT)
        }
        
        # get more stuff
        show {
            title "Return the following items to #{STANDARD_LOCATION}"
            check "<b>#{Q_HS_BUFFER}</b>"
            check "<b>#{Q_STANDARD_1}</b>"
            check "<b>#{Q_STANDARD_2}</b>"
        }
        
        operations().store
        
    end # main

end
