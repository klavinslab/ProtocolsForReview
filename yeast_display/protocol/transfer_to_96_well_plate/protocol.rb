needs "Standard Libs/Debug"
needs "Tissue Culture Libs/CollectionDisplay"
needs "Yeast Display/YeastDisplayHelper"

class Protocol

    include Debug
    include CollectionDisplay
    include YeastDisplayHelper
    
    INPUT_NAME = "Labeled Yeast Library"
    
    OUTPUT_NAME = "96 well plate"
    PLATE_TYPE = "96 well U-bottom plate"
    
    RESUSPEND_VOL = { qty: 500, units: 'µl' }
    TRANSFER_VOL = { qty: 100, units: 'µl' }
    
    def main
    
        operations.retrieve.make
        
        @op = operations.first
        col_96 = @op.output(OUTPUT_NAME).collection
        
        # set_test_labels(@op.input_array(INPUT_NAME).items) if debug
        
        show do
            title "Prepare empty plate"
            check "Take an empty #{PLATE_TYPE}."
            check "Label the plate #{col_96.id} + (your initials) + #{Time.zone.now.to_date}"
        end
        
        show do
            title "Resuspend cell pellets"
            note "Resuspend each cell pellet in #{qty_display(RESUSPEND_VOL)} PBSF."
        end

        rcx_list = fill_collection(col_96)
        
        show do
            title "Transfer to #{PLATE_TYPE}"
            note "Pipet #{qty_display(TRANSFER_VOL)} of each cell suspension to the #{PLATE_TYPE} according to this map:"
            table highlight_rcx col_96, rcx_list
        end
        
        operations.store
        
        return {}
    
    end
    
    def fill_collection(col)
        rcx_list = []

        @op.input_array(INPUT_NAME).items.each_with_index do |item, i|
            sample_name = item.sample.name
            sample_type_name = item.sample.sample_type.name
            object_type_name = item.object_type.name
            
            aliquot = produce new_sample sample_name, of: sample_type_name, as: object_type_name
            col.set 0, i, aliquot.id
            
            item.associate(:aliquot_of_item, aliquot.id)
            rcx_list << [0, i, get_grid_label(item)]
        end
        
        rcx_list
    end
    
    def get_grid_label(item)
        label = item.associations[:library_tube_label]
        label ? label : item.id
    end

end