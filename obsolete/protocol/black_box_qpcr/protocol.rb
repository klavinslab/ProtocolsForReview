# This is a default, one-size-fits all protocol that shows how you can 
# access the inputs and outputs of the operations associated with a job.
# Add specific instructions for this protocol!

class Protocol

  OUT = "NGS sample"
  OUT2 = "qPCR1 sample"
  LENGTH ="Length"
  BARCODE = "Barcoded Primer"
  
  INDEX_LENGTH = 6 # bp, length of illumina index

  def main

    operations.make
    
    tin  = operations.io_table "input"
    tout = operations.io_table "output"
    
    show do 
      title "Input Table"
      table tin.all.render
    end
    
    show do 
      title "Output Table"
      table tout.all.render
    end
    
    operations.each { |op|
        op.output(OUT).item.associate(:length, op.input(LENGTH).val.to_f)
        op.output(OUT).item.associate(:barcode, getBarcode(op.input(BARCODE).item.sample) ) 
        op.output(OUT).item.move("M20_Box_NGS_run#9")
        op.output(OUT2).item.move("M20_Box_NGS_run#9")
    }
    
    operations.store
    
    return {}
    
  end

  # get illumina barcode off of primer    
    def getBarcode(s)
        barcode=""
        h = s.properties 
        ohang=h.fetch("Overhang Sequence")
        if(! (ohang.nil?) )
            if(ohang.length >= INDEX_LENGTH)
                tmp = ohang[(ohang.length-INDEX_LENGTH)..(ohang.length-1)].downcase.reverse!
                barcode = tmp.gsub('a','T').gsub('t','A').gsub('c','G').gsub('g','C')
            end
        end

        return barcode
    end # def

end
