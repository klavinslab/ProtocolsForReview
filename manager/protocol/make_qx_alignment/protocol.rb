needs "Cloning Libs/Cloning"

class Protocol
    
    include Cloning

  def main

    operations.retrieve interacive: true
    operations.make
    
    #ask aquarium to find following items
     alignment_marker = find(:item, sample: { name: "QX Alignment Marker (15bp/5kb)" })[0] 
     mineral_oil = find(:item, sample: { name: "QX Mineral Oil" })[0]

    
    operations.make
    alignment_marker_stripwells = operations.map { |op| op.output("Stripwell").item }

         marker_in_analyzer = find(:item, object_type: { name: "Stripwell" })
                            .find { |s| collection_from(s).matrix[0][0] == alignment_marker.sample.id &&
                                        s.location == "Fragment analyzer" }    
    
    date = (marker_in_analyzer.datum[:begin_date] || marker_in_analyzer.get(:begin_date)) if marker_in_analyzer
    
     marker_needs_replacing = date ? Date.today - (Date.parse date) >= 7 : true
     
     stripwell_data = show do 
      title "Prepare stripwell(s)"
      check "Grab #{operations.length} 12-well stripwell(s)."
      check "Label stripwell(s) with the following ids:"
      note alignment_marker_stripwells.map { |s| "#{s.id}" }.join(", ")
      check "Load 15 L of QX Alignment Marker into each tube."
      check "Add 5 L of QX Mineral Oil to each tube."
      note "Make sure to pipette against the wall of the tubes."
      note "The oil layer should rest on top of the alignment marker layer."
      warning "The current alignment marker has been in the fragment analyzer for over a week!" if marker_needs_replacing
      select ["Yes", "No"], var: "using_today", label: "Are you using a new alignment marker today?", default: 0
     end
     
     marker_needs_replacing = stripwell_data[:using_today] == "Yes"
     
     if marker_needs_replacing
      show do
        title "Place stripwell #{alignment_marker_stripwells[0].id} in buffer array"
        note "Move to the fragment analyzer."
        note "Open ScreenGel software."
        check "Click on the \"Load Position\" icon."
        check "Open the sample door and retrieve the buffer tray."
        warning "Be VERY careful while handling the buffer tray! Buffers can spill."
        check "Discard the current alignment marker stripwell (labeled #{marker_in_analyzer})."
        check "Place the alignment marker stripwell labeled #{alignment_marker_stripwells[0].id} in the MARKER 1 position of the buffer array."
        check "Place the buffer tray in the buffer tray holder"
        check "Close the sample door."
        check "Put machine in \"Park Position\""
     end
     
      alignment_marker_stripwells[0].move_to("Fragment Analyzer")
      alignment_marker_stripwells[0].associate(:begin_date, Date.today.strftime)
      alignment_marker_stripwells[0].save
      marker_in_analyzer.mark_as_deleted if marker_in_analyzer
      alignment_marker_stripwells.delete alignment_marker_stripwells[0]
    end 
    
     if alignment_marker_stripwells.any?
      show do
        title "Cap the stripwell(s) and store in SF2"
        check "Cap the stripwell(s) labeled with the following ids:"
        note alignment_marker_stripwells.map { |s| "#{s.id}" }.join(", ")
        check "Store the stripwell(s) in SF2."
       end
       
        alignment_marker_stripwells.each do |s|
          s.move_to("SF2")
        end
    operations.store interactive: true
    
    return {}
    
    end
    
  end

end