needs "Yeast Display/YeastDisplayHelper"

module WashYeast
    
    include YeastDisplayHelper
    
    # A general method for washing yeast cultures or suspension.
    #
    def wash_yeast(args)
        args = wash_defaults.merge(args)
        
        unless args[:grouped_ops].present? && args[:grouped_ops].respond_to?(:keys)
            raise WashYeastInputError.new('Operations missing or incorrectly formatted.')
        end
        
        show do
            title "Begin washes"
            
            note "Now you will wash the samples #{args[:n_washes]} times."
            note "Be sure to check the boxes as you go so you don't lose track!"
        end
        
        args[:n_washes].times do |i|
            show do
                title "Wash #{i + 1} of #{args[:n_washes]}"
                note temp_instructions(args[:temp])
                
                note ADD_WASH_BUFFER % args[:wash_vol]
                note VORTEX_CELLS
                
                args[:grouped_ops].each do |bfr, ops|
                    note ""
                    table wash_buffer_table(ops, output_handle: args[:output_handle], buffer_handle: args[:buffer_handle])
                end
                
                check SPIN_CELLS
                check REMOVE_BUFFER
            end
        end
    end
    
    def wash_defaults
        {
            n_washes: 2,
            temp: ROOM_TEMP,
            wash_vol: { qty: 1.0, units: MILLILITERS }
        }
    end
end


# Error class for bad parameters.
class WashYeastInputError < StandardError
    
end