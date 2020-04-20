

needs "Standard Libs/Debug"

class Protocol
    
    include Debug
    
    def print_labels ops
    show do
      title "Print out labels"
      
      note "On the computer near the label printer, open Excel document titled 'Glycerol Stock label template'." 
      note "(We use the same template to make Glycerol Stocks as we do to make Agar Stabs)"
      note "Copy and paste the table below to the document and save."
      
      table ops.start_table 
          .output_item("Agar Stab") 
          .custom_column(heading: "Sample ID") { |op| op.output("Agar Stab").sample.id } 
          .custom_column(heading: "Sample Name") { |op| op.output("Agar Stab").sample.name[0,16] }
      .end_table

      note "Ensure that the correct label type is loaded in the printer: B33-181-492 should show up on the display. 
        If not, get help from a lab manager to load the correct label type."
      note "Open the LabelMark 6 software and select 'Open' --> 'File' --> 'Glycerol Stock.l6f'"
      note "A window should pop up. Under  'Start' enter #{ops.first.output("Agar Stab").item.id} and set 'Total' to #{ops.length}. Select 'Finish.'"
      note "Click on the number in the top row of the horizontal side label and select 'Edit External Data'. A window should pop up. Select 'Finish'."
      note "Select 'File' --> 'Print' and set the printer to 'BBP33'."
      note "Collect labels."
    end
  end
    
    # a function to formalize marker name to be like Amp, Kan, Chlor
    def formalize_marker_name marker
        if marker
          marker = marker.delete(' ')
          marker = marker.downcase
          marker = marker.capitalize
        end
        return marker
    end
    
    def get_batch media, ops
        #TODO make this if logic into the precondition
        if media.nil?
            ops.each do |op| 
                op.error :needs_marker, "The marker associated with sample: #{op.input("Strain").sample.id} does not correspond to any known media samples. Make sure that the first Marker listed is the marker you want in your stab media, and that marker names are seperated by commas." 
                op.output("Agar Stab").item.mark_as_deleted
            end
        else
            batch = Collection.where(object_type_id: ObjectType.find_by_name("Agar Vial Batch").id).find { |col| (!col.deleted?) && (col.matrix[0].include? media.id) }
            if batch.nil?
                ops.each do |op| 
                    op.error :no_vials, "There are not enough Agar vials for #{media.name}. Use \'Pour Vials\' Protocol." 
                    op.output("Agar Stab").item.mark_as_deleted
                end
            end
            return batch
        end
    end
    
    def grab_vials ops, media
        media = Sample.find_by_name(media)
        batch = get_batch media, ops
        ops.running.each do |op|
            if batch.empty?
                batch.mark_as_deleted
                batch = get_batch media, ops
            end
            batch.remove_one
        end

        print_labels ops.running if ops.running.any?

        show do 
            title "Grab Vials"
            note "Please grab #{ops.length} #{media.name} vials from vial batch #{batch} in #{batch.location}"
            note "Place the newly made labels on each vial"
        end if ops.running.any?
    end
    
    def stab_vials ops
      media = Sample.find_by_name(media)


      ops.running.retrieve

      show do 
        title "Stab Vials"
        
        note "For each Plate, place a sample into an agar vial according to the table."
        note "Use a 10 uL pipette tip to pick up the colony, and then stab the tip directly into the unused agar."
        note "Wiggle the tip around a little before removing it. "
        table ops.start_table
                    .input_item("Strain")
                    .output_item("Agar Stab", checkable: true)
                    .end_table
        
      end

      show do 
        title "Put Away"
        note "For each of the freshly made Agar Stabs, loosely screw on the cap and put in the 37 C incubator"
      end
      
      ops.each { |op| op.output("Agar Stab").item.move "37 C incubator" }
  end

  def main
    
    operations.make
    
    # sort by media
    ops_by_media = Hash.new { |h, k| h[k] = [] }
    operations.running.each do |op|
        media = ""
        if op.input("Strain").sample_type.name == "Plasmid" 
            media += "LB"
            op.input("Strain").sample.properties["Bacterial Marker"].split(',').each do |m|
                m = "chlor" if m == "chl"
                media = media + " + " + formalize_marker_name(m)
            end
        else
            first_marker = op.input("Strain").sample.properties["Integrated Marker(s)"].split(',').first
            if first_marker.nil?
                media += "SDO"
            else
                media += "SDO -" + formalize_marker_name(first_marker)
            end
        end

        ops_by_media[media] += [op]
    end
    
    ops_by_media.each do |m, ops|
        ops = operations.running.select { |op| ops.include? op } # make Array into OperationList
        
        grab_vials ops, m
    end
    stab_vials operations.running if operations.running.any?
    
    operations.store io: "input"
    
    return {}
    
  end

end