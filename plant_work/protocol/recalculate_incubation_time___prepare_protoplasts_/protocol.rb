#To recalcuate incubation time properly because it wasn't being recorded before

class Protocol
    OUTPUT = "Digesting Cells"

  def main
    
    thing

    {}

  end
    def thing
        operations.each do |op|
            
            date1 = Time.parse(op.input(OUTPUT).item.associations["enzyme_end"].to_s)
            date2 = Time.parse(op.input(OUTPUT).item.associations["enzyme_start"].to_s)
            incubationTime = date1 - date2            
            
            op.input(OUTPUT).item.associate :enzyme_incubation_time, incubationTime
        end
        
        show do
            title "Recalculating incubation time"
            operations.each do |op|
                note " #{op} incubation time is now recorded as #{op.input.(OUTPUT).item.associations["enzyme_incubation_time"]}"
            end
        end
    end

end

