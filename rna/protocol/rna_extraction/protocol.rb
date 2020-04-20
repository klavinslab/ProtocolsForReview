# RNA Extraction
# Written by Hieu Do
# modified by EL
# C µl

# Used for printing out objects for debugging purposes
needs "Standard Libs/Debug"
needs 'RNA/RNA_ExtractionHelper'
needs 'RNA/RNA_ExtractionPrep'
needs 'RNA/RNAkits'

class Protocol
    include Debug
    include RNA_ExtractionHelper, RNAkits, RNA_ExtractionPrep
    
    INPUT = "Yeast Pellet"
    OUTPUT = "Total RNA"
    
    METHOD = "RNA Kit" # Type of kit used determines the protocol used
    CELL_LYSIS = "Lysis Method" # method of breaking cells open
    
    def main
        operations.make
        
        intro
        
        # Prepares tubes, buffers, and other equiptment to extract RNA either mechanical/enzymaticall and takes into account the RNA kit used(RNeasy/miRNeasy)
        rna_extraction_prepartion(INPUT, OUTPUT, METHOD, CELL_LYSIS)
        
        # Fresh overnights/cells need to be quenched and pelleted before extraction
        over_ops = operations.select { |op| op.input(INPUT).object_type.name == 'Yeast Overnight Suspension'}
        (!over_ops.empty?) ? quenching(over_ops, INPUT) : nil
        
        # Assumption is that samples that are not overnights will be in the -80 freezer - this gathers the remaining samples that will be processed in this experiment
        remaining_ops = operations.select { |op| op.input(INPUT).object_type.name != 'Yeast Overnight Suspension'}
        
        # Retrieves the remaining operations that are NOT overnights
        (!remaining_ops.empty?) ? show {warning "<b> If you are gathering your samples from the freezer, keep them on ice from this step until noted.</b>"} : nil
        (!remaining_ops.empty?) ? (take remaining_ops.map {|op| op.input(INPUT).item}, interactive: true): nil
        
        # Groups operations by cell lysing method and processes them by method
        group_by_lysis = operations.map.group_by {|op| op.input(CELL_LYSIS).val}.sort
        group_by_lysis.each {|lys_arr| cell_lysis(lys_arr) }
        
        # Return chemicals back to appropriate storage
        clean_fumehood
        
        # Directs tech to use Qiagen kits - Once cell have been processed to lysates 
        qiagen_kit
        
        delete_input_items 
        
        nanodrop_rna_extracts(INPUT, OUTPUT)
        
        delete_input_items
        
        operations.store
        return {}
    end
    
    def delete_input_items
        operations.running.each {|op| 
            op.input(INPUT).item.mark_as_deleted
            op.input(INPUT).save
        }
    end
    
end #Class
