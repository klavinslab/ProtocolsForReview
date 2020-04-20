# By: Eriberto Lopez 03/30/18
# elopez3@uw.edu
# °C µl

# QIAxcel Quick Ref Guide
# Sample and RNA size marker preparation:
# https://www.labviva.com/pub/static/frontend/Ueg/new/en_US/images/docs/HB-2326-001_1105695_IAS_QX_RNA_Quality_Control_0117_WW.pdf


# This protocol is used to prepare RNA samples for the QIAxcel to determine the RNA Integrity Score of a sample for RNA Seq downstream
needs "Standard Libs/Debug"
needs "Tissue Culture Libs/CollectionDisplay"
needs 'RNA/RNA_QIAxcelPrepHelper'
class Protocol
    include Debug
    include CollectionDisplay
    include RNA_QIAxcelPrepHelper
    
    #I/O
    INPUT = "Total RNA"
    OUTPUT = "Denatured RNA"
    
    def main
        
        intro
        
        # May be a good place to also equlibrate the QX RNA Cartridge
        equlibrate_QX_cartridge
        
        # Create a virtual operation for the ladder before making the outputs
        stripwells = make_fill_stripwells
        tot_num_stripwells = stripwells.length
        
        # Creates and associates a map of the sample in a stripwell to the item it came from
        item_to_well(INPUT, OUTPUT)
        
        # Gather RNA samples from freezer and equlibrate at room temp
        operations.retrieve
        show {note "<b>Let samples thaw at room temperature 25°C - continue to the next step.</b>"}
        
        gather_materials(tot_num_stripwells)
        
        # TODO: Sort RNA samples by concentration from nanodrop association
        preparing_denaturing_samples(stripwells)
        
        denature_dilute
        
        release(operations.reject { |op| op.virtual? }.map {|op| op.output(OUTPUT).item}.uniq, interactive: true)
        return {}
        
    end # main
    
    
    def sort_ops_by_concentration()
        
        # This function should sort RNA extract by concentration in order to use the corret method on the RNA bioanalyzer
        # CM-RNA => 300–1000 ng/ul
        # CL-RNA => 50–300 ng/ul
    end
    
    
    
    # Creates a place holder for the RNA ladder in the at [0,0] in the first collection created by .make
    #
    # @returns colls [Array] an array of stripwells/collection objects
    def make_fill_stripwells()
        operations # Must use this in order for the insert_operation to work :/
        insert_operation(0, VirtualOperation.new)
        # TODO: sort RNA extracts by concentration to use the correct rna bioanalyzer measurement method
        # sort_ops_by_concentration
        
        # Make stripwells with placeholder
        operations.make
        
        # Then, fill virual spot in output collection matrix with QX RNA ladder sample
        colls = operations.reject { |op| op.virtual? }.map {|op| op.output(OUTPUT).collection}.uniq
        
        # Adding ladder
        colls.first.add_one(Sample.find_by_name('QX RNA Size Marker (200-6000nt)'))
        colls.each {|c| log_info "coll #{c.id} matrix", c.matrix}
        return colls
    end
    
    
    # Directs tech to prepare output stripwells by adding denaturation buffer and sample to coresponding well
    #
    # @params stripwells [Array] an array of stripwells/collection objects
    def preparing_denaturing_samples(stripwells)
        show do
            title 'Preparing RNA Samples'
            separator
            warning "Use RNA pipettes & filter pipette tips for the rest of this experiment."
            note 'Label and dispense <b>1µl</b> of <b>QX RNA Denaturation Buffer</b> into each highlighted well'
            stripwells.each { |strip|
                note "Label: <b>#{strip.id}</b>"
                table highlight_non_empty(strip){|r,c| "1µl"}
                separator
            }
        end

        rna_ladder = find(:item, sample: { name: 'QX RNA Size Marker (200-6000nt)'}, object_type: {name: 'Screw Cap Tube'}).first
        take [rna_ladder], interactive: true

        # group operations by collection
        group_by_collection = operations.reject { |op| op.virtual? }.group_by {|op| op.output(OUTPUT).collection}
        count = 1
        group_by_collection.each { |coll, ops|
            # Filling place holder in the first stripwell collection with rna ladder
            count > 1 ? items = ops.map {|o| o.input(INPUT).item.id} : items = [rna_ladder.id].concat(ops.map {|o| o.input(INPUT).item.id})
            # log_info 'ops', ops
            # log_info 'stripwell', coll, 'matrix', coll.matrix
            show do
                title 'Preparing RNA Samples'
                separator
                warning "Use RNA pipettes & filter pipette tips."
                note "Follow the tables below to place <b>1µl</b> of RNA item into the correct well."
                note "<b>Make sure that the sample gets mixed with Denaturation Buffer</b>"
                note "Stripwell: <b>#{coll.id}</b>"
                table highlight_non_empty(coll) {|r,c| "#{items[c]}"} #ops[c].input(INPUT).item.id
            end
            count += 1
        }
        release([rna_ladder], interactive: true)
        
        show do
            title "Spin Down Stripwells"
            separator
            note "To ensure that the sample and the denaturation buffer are mixed"
            check 'Cap & give stripwells a quick spin down.'
            note "Continue to the next step."
        end
    end
    
    
end # class
