


# Use 15ng of fragment
# 15 cycles
# Find overlap temperatures - Make it a parameter



# This is a default, one-size-fits all protocol that shows how you can
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!


# needs "yg_EL/SOE_Lib"
needs "Standard Libs/Debug"


class Protocol
    include Debug
    # include SOE_Lib
    
    # DEF
    INPUT = "Fragment Mix"
    OUTPUT = "Template"
    
    # Parameters
    OVERLAP_Tm = "Overlap Annealing Temperature (C)"
    
    
  def main
    # Find input items and their concenctraions in order to create rxns
    operations.each {|op|
        frag_to_conc = Hash.new()
        op.input_array(INPUT).each{|o|
            frag_to_conc[o.item] = o.item.get('concentration')
        }
        op.temporary[:frag_to_conc] = frag_to_conc
    }
    
    # Calculates how many stripwells to create based on the number of operations
    stripwells_to_fill = produce_output_containers()
    
    # Create new stripwell for every 12 SOE operations
    # output_stripwell = produce new_collection "Stripwell"
    
    
    
    # def produce_new_adapter_plate()
    #     # Produce 96 Well Adapter Plate collection
    #     container = ObjectType.find_by_name('96 Well Adapter Plate')
    #     output_adapter_plt = produce new_collection container.name
    #     output_adapter_plt.location = "-20°C Freezer Illumina Section"
    #     log_info 'Produced adapter_plt collection', output_adapter_plt
    #     return output_adapter_plt
    # end


    
    
    # Calculate vol needed from each fragment sample needed to reach 15ng
    
    # Calculate volume of PCR master mix for each group of fragmens
    
    # 

    # operations.retrieve.make

    tin  = operations.io_table 'input'
    tout = operations.io_table 'output'

    show do
      title 'Input Table'
      table tin.all.render
    end

    show do
      title 'Output Table'
      table tout.all.render
    end

    operations.store

    {}

  end # main

    def produce_output_containers()
       if operations.length < 36
           stripwells_to_produce = (operations.length % 12).ceil
        else
            # produce 96 well plate
            raise "Produce a 96 Well plate instead"
        end
        stripwell_arr = stripwells_to_produce.times.map { stripwell_arr.push(produce new_collection "Stripwell")}
        # stripwells_to_produce.times do
        #     stripwell_arr.push(produce new_collection "Stripwell")
        # end
        return stripwell_arr
    end


end # class
