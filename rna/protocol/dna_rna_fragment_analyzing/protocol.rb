# modified by SG to accept:
# 1) either DNA or RNA
# 2) a range of lengths  
# 3) samples can be: yeast PCR
needs "Standard Libs/UploadHelper"
needs "RNA/FragmentAnalyzerHelper"
needs "Standard Libs/Debug"

class Protocol 
    
    include UploadHelper
    include FragmentAnalyzerHelper
    include Debug
    
    #I/O
    FRAGMENT="PCR" 
    MARKER_TYPE="sample type" # DNA or RNA
    EXPECTED_LENGTH="expected length (bp)" # in bp
    
    # other
    WELLS_PER_STRIPWELL=12
    
    def main
    
        # intro info 
        intro()
        
        sampleTypes = operations.map { |op| op.input(MARKER_TYPE).val } 
        expectedLengths = operations.map { |op| op.input(EXPECTED_LENGTH).val.to_f } 
 
        # can't run RNA and DNA together! error if attempted
        if( checkCompatibility(sampleTypes, expectedLengths) == 0 )
            show do
                title "Exiting..."
                warning "RNA and DNA were batched in the same Fragment Analyzer run. Operations returned to 'Pending'. Exiting now!"
            end
            operations.each { |op|
                op.status="pending"
                op.save
            }
            return
        end
        
        # get stuff
        operations.retrieve
        
        # determine marker, cartridge
        markerCartridge_hash=determineMarkerAndCartridge(sampleTypes, expectedLengths)

        # prior check of only DNA or RNA sampleTypes allows for which cartridge to use
        cartridge_type = sampleTypes.uniq.first # DNA or RNA

        # load cartridge
        cartridge = cartridgeLoad(cartridge_type)
      
        # load alignment marker
        alignmentMarkerLoad(markerCartridge_hash)
        
        # prep and load samples, including blank samples to complete last row
        num_samples = prepLoadSamples(FRAGMENT, cartridge_type) 
    
        # run
        runs_left = runAnalyzer(num_samples, markerCartridge_hash)
        
        # update runs_left in cartridge
        checkCartridge(cartridge, runs_left)
    
        # save PDF report, JPG images of gels
        saveReportAndGelImages(FRAGMENT, num_samples)
        
        if sampleTypes.uniq.first == 'DNA'
            # check length of band(s) in each well, associate Y/N answer
            checkLengths(FRAGMENT,EXPECTED_LENGTH)
            # save and upload raw data
            rawDataUpload()
        else # sampleType is RNA
            # Traces should be included in PDF report
            # Check RIS for each trace/sample 
            checkRIS(FRAGMENT)
            sample_stripwells = operations.map {|op| op.input(FRAGMENT).item}
            sample_stripwells.each {|s| s.mark_as_deleted}
        end
        
        # cleanup
        cleanup()
        
        # return stuff
        release [cartridge] if cartridge
        operations.store io: "input"
    
    end # main

end # Protocol