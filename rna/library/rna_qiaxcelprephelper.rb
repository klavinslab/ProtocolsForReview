# By: Eriberto Lopez
# elopez3@uw.edu
# Updated: 08/15/18


module RNA_QIAxcelPrepHelper
    
    REAGENTS_LOC = {'12-Well Stripwell(s)'=>'Bench', 'QX RNA Dilution Buffer'=>'Bench', 'QX RNA Denaturation Buffer'=>'R4 Fridge', 'QX RNA Alignment Marker (15bp)'=>'20C Freezer'}
    THERMO_TEMPLATE = 'QX_RNA' # For denaturing RNA samples
    
    
    def intro()
        show do
            title "Introduction - RNA Quality Control"
            separator
            note "In this protocol you will prepare <a href=https://www.labviva.com/pub/static/frontend/Ueg/new/en_US/images/docs/HB-2326-001_1105695_IAS_QX_RNA_Quality_Control_0117_WW.pdf>RNA samples for analysis on the QIAxcel Bioanalyzer</a>."
            note "1. Gather materials and reagents"
            note "2. Mix and place samples on thermocycler"
            note "3. Dilute"
        end
    end
    
    # Directs tech to equilibrate QX RNA Cartridge
    def equlibrate_QX_cartridge()
        cartridge = find(:item, object_type: { name: "QX RNA Screening Cartridge Container" }).first
        log_info cartridge
        if cartridge.location != 'Fragment analyzer'
            # Gather materials for cartridge incubation 
            img1 = 'Actions/RNA/QXCartridge_incubation.png'
            show do
                title 'Equilibrate QX RNA Cartridge'
                separator
                note "<b>1.</b> Gather the QX Cartridge stand with the blue cover."
                note "<b>2.</b> Add <b>10mL</b> of <b>QX Wash Buffer</b> to a reservoir."
                note "<b>3.</b> Cover QX Wash Buffer with <b>2mL</b> of <b>Mineral Oil</b>"
            end
            
            take([cartridge], interactive: true)
            cartridge.location = 'QX Cartridge Stand at Bench'
            cartridge.save
            
            show do
                title 'Equilibrate QX RNA Cartridge'
                separator
                note "Remove the QIAxcel RNA gel cartridge from its packaging and carefully wipe off any soft gel debris from the capillary tips using a soft tissue"
                bullet "<b>Place the cartridge like the image below and incubate for 20 mins</b>"
                bullet "Start a <b>20 min</b> timer"
                image img1
            end
        end
    end

    # Creates and associates (to ouput stripwell) a matrix that maps the input item to the well in the output item
    # ie: {[0, 1]=>148110, [0, 2]=>148111, [0, 3]=>148112, [0, 4]=>148113, [0, 5]=>148114, [0, 6]=>148115, [0, 7]=>148116, [0, 8]=>148117, [0, 9]=>148118, [0, 10]=>148119, [0, 11]=>148120}
    def item_to_well(input_str, output_str)
        group_by_output_coll = operations.reject { |op| op.virtual? }.group_by {|op| op.output(output_str).collection}
        group_by_output_coll.each { |out_coll, ops|
            mapping = Hash.new(0)
            ops.each do |op|
                mapping[[op.output(output_str).row, op.output(output_str).column]] = op.input(input_str).item.id
            end
            Item.find(out_coll.id).associate('well_to_item', mapping)
            log_info mapping
        }
        
    end

    # Directs tech to gather materials for the experiment
    def gather_materials(tot_num_stripwells)
        show do
            title "Gather the Materials"
            separator
            note "Gather the following materials:"
            REAGENTS_LOC.each do |mat, loc|
                if mat.include? 'Stripwell'
                    check "Gather <b>#{tot_num_stripwells}</b> - <b>#{mat}</b> at Location: <b>#{loc}</b>"
                else
                    check "Gather <b>#{mat}</b> at Location: <b>#{loc}</b>"
                end
            end
            separator
            check "If item/reagent is frozen, let it thaw at room temperature while preparing samples in the next step."
        end
    end    

    def denature_dilute()
        show do
            title "Denature RNA Samples"
            separator
            note "Next, take prepared stripwells to thermocycler and choose template: <b>#{THERMO_TEMPLATE}</b>"
            check "Start timer for <b>4 mins</b>"
            note "Continue to the next step."
        end
        
        release(store_working_rna_extracts, interactive: true) # Stores working RNAs in to Sequencing box 
        
        show do
            title "Dilute RNA Samples"
            separator
            check "Gather QX RNA Dilution Buffer"
            check "Once thermocycler timer is done, give stripwells a quick spin down to collect condensation."
            check "Next, dilute RNA samples with <b>8µl</b> of <b>QX RNA Dilution Buffer</b>"
            check "If there are empty wells, then fill them with <b>10µl</b> of <b>QX RNA Dilution Buffer</b>"
        end
    end

    # Should store RNA extracts into the the -20C RNA-Seq Staging box
    def store_working_rna_extracts()
        operations.reject { |op| op.virtual? }.each {|op| op.input('Total RNA').item.location = '-20°C RNA-Seq Staging Box'}
        return operations.select { |op| !op.virtual? }.map {|op| op.input('Total RNA').item}
    end


end # module