# Devin Strickland
# dvn.strcklnd@gmail.com


needs "Standard Libs/SortHelper" 
needs 'Yeast Display/YeastDisplayHelper'
needs 'Yeast Display/YeastDisplayShows'

class Protocol
    
    include YeastDisplayHelper, YeastDisplayShows, SortHelper
    
    # I/O
    INPUT_YEAST = 'Yeast Culture'
    OUTPUT_ARRAY = 'Yeast Culture'
    
    # other
    GLYCEROL = '50% glycerol'
    GLYCEROL_VOLUME = { qty: 0.5, units: 'ml' }
    CULTURE_VOLUME = { qty: 1, units: 'ml' }
    MAKE_EXTRA = 1.1
    
    DILUTION_MEDIA="YPAD (peptone)"
    DIL_VOL=100 # mL
    NANODROP_VOL=100 # uL, culture
    NANODROP_DIL_VOL=900 # uL, media
    DIL_FACTOR=100 # 10 for 1mm-1cm conversion, 10 for 1:10 dilution 
    
    CONICAL = '50 ml conical tube'
    SPLIT_INTO_CONICALS = "Use a serological pipette to transfer %{vol} of the %{liquid} into in each of two #{CONICAL}s."
    SPIN_CELLS = 'Spin the tubes for 3 minutes at 3000 RPM in a tabletop centrifuge.'
    REMOVE_MEDIA = 'Use a serological pipette to remove 30 ml of the media from each tube, being careful to not disturb the cell pellets.'
    RESUSPEND_CELLS = 'Resuspend the pellets in the remaining media.'

    def main
        # errors operation and adds association if input and output are not the same sample name
         operations.each do |op|
            input_sample = op.input(INPUT_YEAST)
            output_sample = op.output_array(OUTPUT_YEAST)
            
            if output_sample.length > 1 
                output_sample.each do |samp|
                    if samp.sample.name != input_sample.sample.name
                        op.associate("error:", "input and output sample names must be the same")
                        raise "input and output sample names must be the same"
                    end
                end
            else
                if output_sample.first.sample.name != input_sample.sample.name
                    op.associate("error:", "input and output sample names must be the same")
                    raise "input and output sample names must be the same"
                end
            end
        end
        
        # sort ops
        ops_sorted=sortByMultipleIO(operations, ["in"], [INPUT_YEAST], ["id"], ["item"]) 
        operations=ops_sorted
        operations.make 
        
        operations.retrieve 
        
        associate_efficiency_from_estimate_operation
        
        measure_od
        
        gather_materials
        
        prepare_stocks
        
        # needed so that stocks can be deleted/retained at QA step in Estimate Transformation Efficiency.
        # note that the item will be deleted!
        associate_stocks_to_culture

        operations.each { |op|
            op.input(INPUT_YEAST).item.mark_as_deleted 
        }
                
        operations.store 
        
        return {}
        
    end
    
    def associate_efficiency_from_estimate_operation
        # associate efficiency for outputs from input of estimate efficiency operation
        # debug breaks because it doesn't have any predecessors. only works in plan with a predecessor
        if (!debug)
            operations.each do |op|
                other_operations_from_predecessor = Operation.find(op.id).predecessors[0].successors
                if (other_operations_from_predecessor.length == 2)
                  estimate_operation = other_operations_from_predecessor.select { |op| op.operation_type_id == OperationType.find_by_name("Estimate Transformation Efficiency").id}[0]
                  if (estimate_operation.status == 'done')
                      op_outputs = op.output_array(OUTPUT_ARRAY)
                      op_outputs.each do | fv |
                        fv.item.associate(:efficiency, estimate_operation.input('Dilution Plates').item.get_association(:efficiency).value)
                      end
                  end
                end
            end
        end
    end
    
    # associate a list of output glycerol stock items to the input culture
    def associate_stocks_to_culture
        operations.each { |op|
            op.input(INPUT_YEAST).item.associate :glycerol_stocks, op.output_array(OUTPUT_ARRAY).item_ids
        }
    end
     
    def measure_od
        # measure od600 without a 1:10 dilution 
         show do
            title 'Measure OD600 of culture(s)'
            
            note 'Use the Nanodrop to measure the density of each yeast culture, and record the OD600.'
            warning 'Record the OD600 exactly as it is shown on the screen.'
            
            table operations.start_table
                .input_item(INPUT_YEAST)
                .get(:input_OD, type: 'number', heading: 'OD600')
                .end_table
        end
        
        # auto associate some numbers if in debug
        operations.each { |op| op.temporary[:input_OD]="0.045"} if debug
        
        operations.each { |op|
            op.input(INPUT_YEAST).item.associate :OD, op.temporary[:input_OD].to_f
            op.output_array(OUTPUT_ARRAY).items.each { |it|
                it.associate :OD_ml, op.temporary[:input_OD].to_f
                it.associate :vol_ml, 1  
                it.associate :source, op.input(INPUT_YEAST).item.id
            }
        }
    end
    
    def prepare_stocks
        show do
            title "Prepare glycerol stocks"
            check "Label the cryotubes as follows: #{operations.map { |op| op.output_array(OUTPUT_ARRAY).items}.flatten.to_sentence}"
            check "Transfer #{GLYCEROL_VOLUME[:qty]} #{GLYCEROL_VOLUME[:units]} of #{GLYCEROL} to each cryotube (you may use a single tip)"
            warning "In the following, use a fresh tip for each row!"
            check "Add culture to each cryotube, according to the following table:"
            table operations.start_table
                .input_item(INPUT_YEAST)
                .custom_column(heading: "transfer volume for <b>EACH</b> cryotube (#{CULTURE_VOLUME[:units]})") { |op| CULTURE_VOLUME[:qty] }
                .custom_column(heading: "number of cryotubes") { |op| op.output_array(OUTPUT_ARRAY).items.length }
                .custom_column(heading: "cryotube labels") { |op| "#{op.output_array(OUTPUT_ARRAY).items.to_sentence}" }
                .end_table
        end
    end
    
    def gather_materials
        total_cryotubes = operations.map { |op| op.output_array(OUTPUT_ARRAY).items.length}.sum
        total_glycerol = (total_cryotubes * GLYCEROL_VOLUME[:qty] * MAKE_EXTRA).round(2)
        show do
            title 'Gather the following additional materials'
            check "#{GLYCEROL} (at least #{total_glycerol} #{GLYCEROL_VOLUME[:units]})"
            check "#{total_cryotubes} cryotubes"
            check "1 box of 1000 µl pipette tips"
        end
    end
 
end
