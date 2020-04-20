# SG
#
# Transfer input sample (in eppi tube) to output part of stripwell, for fragment analyzing of DNA/RNA.
# Concentrations must be 1) measured 2) >= 10 ng/uL.
# According to Qiagen handbook, need 10uL of 10-100ng/uL. Protocol aims for 50 ng/uL max.
needs "Library Cloning/PurificationHelper"

class Protocol
    
    include PurificationHelper
    
    # I/O
    INPUT="PCR tube"
    OUTPUT="Stripwell"
    
    # other
    SAMPLES_PER_STRIPWELL=12
    FINAL_VOLUME=10.0 # ul
    MAX_CONCENTRATION=50.0 # ng/ul

    def main
        
        # assign random concentrations if in test mode
        if(debug)
            operations.each { |op| op.input(INPUT).item.associate "concentration", (Random.rand(200) + 10) } 
        end
        
        # return if concentration not defined for an input
        measureConcentration(INPUT,"input")
        
        # make stripwells, number and associations will be sorted by aquarium
        operations.make
        
        # all output stripwells
        stripwells = operations.output_collections[OUTPUT]
        
        # get stripwells and label
        show do
            title "Grab stripwells"
            check "Grab <b>#{stripwells.length}</b> #{SAMPLES_PER_STRIPWELL}-well stripwell(s)"
            check "Label stripwell(s) as follows:"
            stripwells.each { |ss|
                note "#{ss}" 
            }
        end
        
        # find correct volume to take from each
        vol=0
        operations.each { |op|
            conc=op.input(INPUT).item.get(:concentration).to_f
            if(conc <= MAX_CONCENTRATION)
                vol=FINAL_VOLUME
            else
                vol=(FINAL_VOLUME*MAX_CONCENTRATION/conc).round(1)
            end
            op.input(INPUT).item.associate "transfer_volume_uL", vol
        } 
        
        # transfer sample, water if needed to stripwell
        show do
            title "Transfer sample volumes from tube(s) to stripwell(s)"  
            note "Add sample and molecular grade water volumes, as follows:"
            table operations.start_table
              .input_item(INPUT)
              .custom_column(heading: "<b>Sample</b> volume (uL)") { |op| op.input(INPUT).item.get(:transfer_volume_uL).to_f.round(1) }
              .custom_column(heading: "<b>Water</b> volume (uL)") { |op| (FINAL_VOLUME-op.input(INPUT).item.get(:transfer_volume_uL).to_f).round(1) }
              .output_collection(OUTPUT, heading: "Stripwell ID")
              .custom_column(heading: "column") { |op| op.output(OUTPUT).column+1 }
              .end_table
              note "All total volumes should be <b>#{FINAL_VOLUME} ul</b>"
        end

        return {}
        
    end # main
end # protocol
