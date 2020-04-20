# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!
needs "Standard Libs/SortHelper"


class Protocol
    include SortHelper
    
    # I/O
    FWD = "Forward Primer"
    REV = "Reverse Primer"
    TEMPLATE = "Template"
    CONC = "Template Concentration (pg)"
    OUTPUT = "Amplified cDNA"
    
    
    KAPA_SAMPLE = "Kapa HF Master Mix"
    EVA_GREEN_SAMPLE = "Eva Green"
    EVA_GREEN_OBJECT = "Screw Cap Tube" 
    
    def main
        
        operations.retrieve
    
        
        # sort by template
        ops_sorted=sortByMultipleIO(operations, ["in", "in"], [TEMPLATE, CONC], ["id", ""], ["item", "val"])
        operations = ops_sorted
        
        # grab all necessary items
        eva_green_item = find(:item, { sample: { name: EVA_GREEN_SAMPLE }, object_type: { name: EVA_GREEN_OBJECT } } )[0]
        kapa_stock_item = find(:sample, name: KAPA_SAMPLE)[0].in("Enzyme Stock")[0]
        primers = [ operations.map{|op| op.input(FWD).item}, operations.map{|op| op.input(REV).item} ]
        templates = [ operations.map{|op| op.input(TEMPLATE).item} ]
        take [kapa_stock_item, eva_green_item, primers, templates].flatten.uniq, interactive: true  #,  method: "boxes"
    
        tin  = operations.io_table "input"
        tout = operations.io_table "output"
        
        dilute_template(operations)
    
        show do 
        title "Input Table"
        table tin.all.render
        end
    
        show do 
            title "Output Table"
            table tout.all.render
        end
    
        # operations.store
    
        return {}
    
    end
    
    def dilute_template(ops)
        ops.each do |op|
            conc = op.input(CONC).val
        end
    end

end
