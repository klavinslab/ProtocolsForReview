
# SG
# Refactored by Devin Strickland 2/17/18

needs "Standard Libs/Debug"
needs "Yeast Display/YeastDisplayHelper"
needs "Yeast Display/YeastDisplayShows"

class Protocol
    
    include Debug, YeastDisplayHelper, YeastDisplayShows
    
    attr_accessor :low_growth_ops, :ready_ops

    INPUT = "Yeast Culture"
    OUTPUT_PREFIX = "Stored sample rep"
    OUTPUT_1 = "#{OUTPUT_PREFIX} 1"
    OUTPUT_2 = "#{OUTPUT_PREFIX} 2"
    
    MIN_OD = 0.2
    
    OD_ML_NEEDED = 9.0
    NUMBER_OF_REPLICATES = 2 # 2 stored samples for each input
    CENTRIFUGE_TUBE = "15 ml <b>polypropylene</b> tube"
    CENTRIFUGE_TIME = 5 # min
    CENTRIFUGE_G = 4696 # g
    RESUSPENSION_BUFFER = "Zymoprep Digestion Buffer (Solution 1)"
    RESUSPENSION_VOL = { qty: 200, units: 'µl'}
    CONCENTRATED_VOL = { qty: 225, units: 'µl'}
    

    def main   
        
        operations.running.retrieve
        
        set_od_ml_needed
        
        measure_ods
            
        @low_growth_ops, @ready_ops = partition_ops_by_growth
        
        put_back
        
        return {} unless @ready_ops.present?
        
        gather_additional_materials
        
        # TODO: should only make ready operations
        # since i push some back to pending, i shouldnt make the outputs to those operations
        
        
        pushed_back = false
        pushed_back = check_volumes
        @ready_ops.make
        
        if @ready_ops.length > 0
        
          spin_down
          
          resuspend
          
          clean_up pushed_back
          
          @ready_ops.store
          
          # if post-sort, save bin info
          @ready_ops.each { |op|
              if( !(op.input(INPUT).item.get(:bin).nil?) ) # sorted sample
                  op.output(OUTPUT_1).item.associate(:bin, op.input(INPUT).item.get(:bin))
                  op.output(OUTPUT_2).item.associate(:bin, op.input(INPUT).item.get(:bin))
              end
          }
        else 
          clean_up_pushed_back
        end
          
        return {} 
        
    end
    
    def set_od_ml_needed
        set_test_od_mls if debug
        
        operations.each do |op|
            op.associate(:od_ml_needed, OD_ML_NEEDED) unless op.associations[:od_ml_needed]
        end
    end
    
    def gather_additional_materials
        min_resuspension_vol = RESUSPENSION_VOL[:qty] * NUMBER_OF_REPLICATES * @ready_ops.length
        
        show do
            title "You will also need"
            check "#{self.ready_ops.length} #{CENTRIFUGE_TUBE}(s)"
            check "#{RESUSPENSION_BUFFER} (#{min_resuspension_vol} #{RESUSPENSION_VOL[:units]})"
            warning "Make sure you take polypropylene and not polystyrene tubes!"
        end
    end
    
    def measure_ods
        unique_culture_operations = operations.uniq { |op| op.input(INPUT).item }.extend(OperationList)
        
        measure_culture_ods(unique_culture_operations)
        
        set_test_ods if debug
        
        unique_culture_operations.each { |op| op.set_input_data(INPUT, :od, op.temporary[:od]) }
    end
    
    def partition_ops_by_growth
        operations.running.each do |op|
            op.temporary[:growth] = op.input(INPUT).item.get(:od).to_f < MIN_OD ? :low_growth : :ready 
        end
        
        grouped_ops = operations.running.group_by { |op| op.temporary[:growth] }
        
        [grouped_ops[:low_growth], grouped_ops[:ready]]
    end
    
    def put_back
        return unless @low_growth_ops.present?
        
        @low_growth_ops.each { |op| op.change_status("pending") }
        
        show do
            title "Return low-growth cultures to shaker"
            
            note "Return the following cultures to the shaker for additional growth:"
            table self.low_growth_ops.start_table
              .input_item(INPUT)
              .end_table
        end
    end
    
    def spin_down
        show do
            title "Transfer cultures"
            
            note "Get #{self.ready_ops.length} #{CENTRIFUGE_TUBE}s."
            note "Label the tubes according to the #{INPUT} column in the table."
            note "Transfer the indicated volume of each culture to the corresponding tube:"
            table self.ready_ops.start_table
              .input_item(INPUT)
              .custom_column(heading: "Culture (ml)", checkable: true) { |op| library_culture_volume(op).round(1) }
              .end_table
        end
        
        show do
            title "Spin down cultures"
            
            check "Centrifuge the #{CENTRIFUGE_TUBE}(s) for #{CENTRIFUGE_TIME} min at #{CENTRIFUGE_G} g"
            warning "Make sure tubes are balanced!"
            check "Pour off supernatant. Knock tube(s) on a kimwipe to dry remaining liquid."
        end
    end
    
    def resuspend
        vol_to_add = NUMBER_OF_REPLICATES * RESUSPENSION_VOL[:qty]
        
        show do
            title "Resuspend and aliquot cells"
            
            check "Add #{vol_to_add} #{RESUSPENSION_VOL[:units]} of #{RESUSPENSION_BUFFER} to each #{CENTRIFUGE_TUBE}."
            check "Vortex each #{CENTRIFUGE_TUBE} until cells are fully resuspended."
            note "Label 1.5 mL tubes according to the <b>#{NUMBER_OF_REPLICATES}</b> #{OUTPUT_PREFIX} columns in the table."
            note "Transfer #{qty_display(CONCENTRATED_VOL)} from each resuspended #{INPUT} to the labeled tubes according to the table."
            
            table self.ready_ops.start_table
                .input_item(INPUT)
                .output_item(OUTPUT_1, checkable: true)
                .output_item(OUTPUT_2, checkable: true)
                .end_table
        end
    end 
    
    def clean_up pushed_back
        @ready_ops.each { |op| op.input(INPUT).item.mark_as_deleted }
        
        show do
            title "Cleanup"
            
            check "Dispose of any input sample cultures remaining on bench."
            check "Return the #{RESUSPENSION_BUFFER} to the kit."
            
            if pushed_back
                note "Please notify a lab manager that one or more of the operations were pushed back to pending"
            end
        end
    end
    
    def library_culture_volume(op)
        NUMBER_OF_REPLICATES * op.associations[:od_ml_needed].to_f / (op.input(INPUT).item.get(:od) * 10.0)
    end
    
    def set_test_od_mls
        test_od_mls = [0.89, 4.5, 3.0, 2.0, 1.33]
        operations.running.each { |op| op.associate(:od_ml_needed, test_od_mls.rotate![0]) }
    end
    
    def set_test_ods
        test_ods = [0.3] #[0.5, 0.15, 0.3, 0.4, 0.2]
        operations.running.each { |op| op.temporary[:od] = test_ods.rotate![0] }
    end
    
    def check_volumes
        
    # ask tech if there is enough volume
      vol_checking = show do 
        title "Checking Volumes"
        operations.each do |op|
           select ["Yes", "No"], var: "#{op.input("Yeast Culture").item.id}", label: "Does #{op.input("Yeast Culture").item.id} have at least #{library_culture_volume(op).round(1)} mL?", default: 0
        end
      end
        
      low_vol_ops_items = []  
      operations.each do |op|
        if vol_checking["#{op.input("Yeast Culture").item.id}".to_sym] == "No"
          # delete the op from ready_ops, so we don't keep using this operation later on.
          # for example, we shouldn't delete the inputs for this operation.
          @ready_ops.delete(op)
          op.change_status("pending")
          low_vol_ops_items.push(op.input("Yeast Culture").item.id)
          #op.error :not_enough_volume, "#{op.input("Yeast Culture").item.id} didn't have enough volume. Please talk to the lab manager."
        end
      end
      
     # ask the tech to add SDO -His-Trp-Ura to items w/o enough volume and return to shaker
        if low_vol_ops_items.length > 0  
          show do
            title "Add solution and return to shaker"
            
            note "For each item in #{low_vol_ops_items}, adding 1ml of SDO -His-Trp-Ura and return to 30c shaker"
          end
        end
      
      return low_vol_ops_items.length > 0
        
    end
    
    def clean_up_pushed_back
      show do
        title "No More Operations"
        
         note "Please notify a lab manager that one or more of the operations were pushed back to pending"
      end
    end
    
end