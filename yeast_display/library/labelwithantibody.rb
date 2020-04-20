needs "Yeast Display/YeastDisplayHelper"

module LabelWithAntibody
    
    include YeastDisplayHelper
    
    # Add diluted antibody to the samples and incubate for the specified time.
    # 
    def incubate_with_antibody(args)
        show do
            title 'Add diluted antibody to cell pellets'
            note temp_instructions(ON_ICE)
                
            note "Add #{qty_display(args[:antibody_qty])} diluted antibody to the each cell pellet."
            note VORTEX_CELLS
            note 'Place the tubes in a small ice-filled box on the nutating mixer.'
            note 'Set the timer and incubate the tubes for 10 minutes.'
        end
        
        show do
            title 'Spin down antibody-labeled cells and remove the supernatant'
            note temp_instructions(ON_ICE)
            
            note 'After incubating the tubes for 10 minutes.'
            check SPIN_CELLS
            check REMOVE_BUFFER
        end
    end
    
end