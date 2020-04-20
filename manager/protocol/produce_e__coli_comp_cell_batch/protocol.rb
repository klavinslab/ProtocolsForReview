#   abemill@uw.edu

needs "Standard Libs/Debug"
needs "Standard Libs/Centrifuge"
needs "Standard Libs/Feedback"
require 'enumerator'
class Protocol
  include Debug
  include Centrifuge
  include Feedback
  
  #protocol run
  def main

    operations.retrieve interactive: false
    operations.make
    
    warm_LB
    
    show do 
        title "wait while LB warms"
        timer initial: { hours: 1, minutes: 0, seconds: 0}
    end

    # much of the preparation is done in this method
    first_innoculate
    
    # allow some time for culture growth, then make sure all culture flasks are above 0.04 before continuing
    show do 
        title "wait while culture grows"
        timer initial: { hours: 0, minutes: 45, seconds: 0}
    end
    operations.each do |op|
        op.temporary[:good_OD?] = check_OD_initial op
    end
    low_od_ops = operations.reject{ |op| op.temporary[:good_OD?] }
    sufficient_od_ops = operations.select { |op| op.temporary[:good_OD?] }
    
    # for the ops with cultures that were measured >= .04 OD, put them in tubes on ice
    # transfer_to_tubes sufficient_od_ops if sufficient_od_ops.any? 
    # !! This is now instead done inside the centrifuge_resuspend_cycle method
    
    # for the ops with cultures that were measured < .04 OD, wait 20 min for extra growth and remeasure
    while(low_od_ops.any?) do
        show do 
            title "OD too low, additional grow time required"
            timer initial: { hours: 0, minutes: 20, seconds: 0}
        end
        low_od_ops.each do |op|
            op.temporary[:good_OD?] = check_OD_initial op
        end
        low_od_ops = operations.reject{ |op| op.temporary[:good_OD?] }
        sufficient_od_ops = operations.select { |op| op.temporary[:good_OD?] }
        # transfer_to_tubes sufficient_od_ops if sufficient_od_ops.any?
    end

    
    # at this point, all cultures are chilled and ready for staggered centrifuge cycling
    opts = Hash.new()
    opts[:items] = operations.map { |op| op.input("Overnight").item}
    opts[:start_vol] = 800
    opts[:tube_vol] = 225
    opts[:centrifuge_slots] = 4
    opts[:cycles] = [
                      {cent_temp: 4, cent_rpm: 2500, cent_time: 15, sus_media: "DI water", sus_volume: 200, combine: false},
                      {cent_temp: 4, cent_rpm: 2500, cent_time: 20, sus_media: "10% Glycerol", sus_volume: 100, combine: true},
                      {cent_temp: 4, cent_rpm: 2500, cent_time: 20, sus_media: "10% Glycerol", sus_volume: 8, combine: true},
                      {cent_temp: 4, cent_rpm: 2500, cent_time: 20, sus_media: "GYT", sus_volume: 3.2, combine: false}
                    ]
    opts[:cold] = true
    opts[:cb_extra_instructions] = "callback"
    # variablize_options opts
    centrifuge_resuspend_cycle(opts)
    
    
    
    
    #at this point all operations have undergone 4 centrifuge-resuspend cycles
    #The only thing left to do is check the optical density,
    #dilute the cultures if necessary 
    #aliquot finished cultures, and label produced batches
    
    operations.each do |op|
        #OD_value will be nil if the OD is acceptable
        op.temporary[:OD_value] = check_OD_post op
    end
    high_od_ops = operations.reject{ |op| op.temporary[:OD_value].nil? }

    # for the ops with cultures that were measured <= .1 OD, dilute
    while(high_od_ops.any?) do
        
        #dilute cultures down to acceptable density
        culture_dilution high_od_ops
        
        #remeasure OD of diluted cultures
        make_GYT_tubes high_od_ops.length
        high_od_ops.each do |op|
            #OD_value will be nil if the OD is acceptable
            op.temporary[:OD_value] = check_OD_post op
        end 
        high_od_ops = operations.reject{ |op| op.temporary[:OD_value].nil? }
    end
    
    operations.each do |op|
        #put resulting comp cell cultures into 40ul aliquots by batch
        aliquot_cultures op
        
        #label each batch with strain name, date, your initials, and item ID; store in the m80
        label_and_store_batches op
    end
    clean_up
    
    operations.each do |op|
        op.input("Overnight").item.mark_as_deleted
        op.input("Water").item.mark_as_deleted
        op.input("Glycerol").item.mark_as_deleted
    end
    
    #nothing needs to be stored here, because all outputs have been stored and all inputs have been deleted    
    
    get_protocol_feedback
    
    return {}
  end
  
  #retrieves all the LB bottles needed and immerse them in heat bath
  def warm_LB
    agar_items = [];
    operations.length.times do
      agar = Item.where(sample_id: Sample.find_by_name("LB"), object_type_id: ObjectType.find_by_name("800 mL Liquid"))
                  .where("location != ?", "deleted").find {|i| !agar_items.member?(i)}
                  
      if agar.nil?
        raise "not enough 800 mL LB bottles available" 
      end
      agar_items.push agar
    end
    take agar_items
    #the 800ml LBs will each be completely used up
    agar_items.each { |i| i.mark_as_deleted }
    
    show do
      title "Place LB in heat bath."
      note "Set heat bath to 37C"
      note "Once temperature reaches 37C, immerse all the LB bottles in beads"
    end
  end
  
  #transfer overnight to 2L flask, add glycerol, label 2L flask with short id,  label 4 225ml tubes with same short id for each op
  def first_innoculate
    show do 
      title "Grab Inoculation ingredients"
      check "grab #{operations.length} 2000mL  #{"flask".pluralize(operations.length)}"
      check "grab #{operations.length} LB  #{"bottle".pluralize(operations.length)} from heat bath"
      check "grab  #{"overnight".pluralize(operations.length)}: #{operations.map { |op| op.input("Overnight").item}.to_sentence} from the 37C shaker incubater"
      check "grab #{operations.length * 4} 225mL tubes and place in freezer."
    end
    
    operations.retrieve interactive: false
    
    show do 
        title "Add LB, overnight, and label"
        warning "Tilt both bottles for sterile pouring during all transfers"
        note "NOTE: If you are confident with this protocol, and you are only making one batch then all future labeling instructions can be safely skipped."
        note "add one full bottle of liquid LB to each 2000 mL flask"
        note "label the 2000mL #{ "flask".pluralize(operations.length) } as #{operations.map { |op| op.input("Overnight").item.id}.to_sentence}"
        
        note "Transfer overnights to 2000mL flasks according to the following table"
        table operations.start_table
                    .input_item("Overnight")
                    .custom_column(heading: "Flask ID") { |op| op.input("Overnight").item.id }
                    .end_table 

        note "it is not necessary to pour out all overnight foam"
    end
    
    show do 
        title "Return things"
        note "Return 2000mL #{"flask".pluralize(operations.length)} to the 37C shaker incubator"
        note "bring empty baffled #{"flask".pluralize(operations.length)} and 800mL  #{"bottle".pluralize(operations.length)} to dishwasher"
    end
    
    show do 
        title "Prepare for spins"
        note "Set large centrifuge to 4C"
        note "Make sure you have #{operations.length * 4} 225mL tubes in freezer"
        note "Find #{operations.length} bottles of 500mL 10% glycerol and 1L sterile DI water, and place in fridge for later use"
    end
  end
  
  # get ice from bagely and transfer the cultures from large flasks into the corresponding chilled centrifuge tubes
  def transfer_to_tubes ops
    show do 
      title "Go to Bagley to get ice (Skip if you already have ice)"
      note "Walk to ice machine room on the second floor in Bagley with a large red bucket, fill the bucket  full with ice"
      note "If unable to go to Bagley, use ice cubes to make a water bath (of mostly ice) or use the chilled aluminum bead bucket (if using aluminum bead bucket place it back in freezer between spins)"
    end

    show do 
      title "Transfer culture to chilled centrifuge tubes"
      note "grab the 225 mL tubes from freezer labeled as: #{ops.map { |op| op.temporary[:centri_ID] }.to_sentence(last_word_connector: ", or ")}"
      note "Immerse the 225 mL tubes in the ice bath"
      note "grab the following 2000 mL cultures from shaker/incubator: #{ops.map { |op| op.temporary[:centri_ID] }.to_sentence}"
      note "Carefully pour 200 mL of culture into each centrifuge tube with the same label, keeping tubes immersed in ice as much as possible"
      note "bring empty 2000 mL #{"flask".pluralize(operations.length)} to dishwashing station"
    end
  end
  
  # While waiting for final centrifuge to finish, instructs the tech to prepare bench for aliquoting and tidy up 
  def prep_and_clean
    show do
      title "While tubes are centrifuging:"
      note "Place an appropriate amount of aluminum tube racks on an ice block, arrange open, empty, chilled 0.6 mL tubes in every other well, and place whole structure in freezer. Freeze an appropriate amount of additional unracked tubes as well" 
      note "Pour water out of ice bucket, and fill a smaller bucket with remaining ice."
      note "Move P1000 pipette, pipette tips, and tip waste to the dishwashing station. Set the P1000 pipette to 1000uL"
    end
  end
  
  def culture_dilution ops
      #If recorded OD > 0.1, add additional GYT according to this calculation:
            # recorded OD x 10 = actual OD
            # actual OD x 2.5 x 10^8 cells/mL = concentration of 1:100 dilution
            # concentration of 1:100 dilution x 100 = concentration of cells
            # (concentration of cells) x (1.6 mL) / 2.5 x 10 ^ 10 = final volume
            # Final volume - 1.6 = volume of GYT to add to cells
    ops.each do |op|
      od = op.temporary[:OD_value] * 10 #our nanodrop is reliably innacurate by 1/10
      cell_concentration = od * (2.5 * (10 ** 8)) * 100
      final_volume = (cell_concentration * 1.6) / (2.5 * (10 ** 10))
      op.temporary[:GYT_to_add] = final_volume - 3.2
    end
    
    show do 
      title "Dilute cultures to acceptable concentration"
      ops.each do |op|
        note "Dilute the 225mL culture tube labeled #{op.input("Overnight").item.id} by adding #{op.temporary[:GYT_to_add]} mL of GYT"
      end
    end
  end
  
  def aliquot_cultures op
    data = show do
      title "Aliquot cells into 0.6mL tubes"
      note "Take ice block, aluminum tube rack, and arranged 0.6 mL tubes out of the freezer."
      note "Aliquot 40 uL of cells from 225 mL culture tube #{op.input("Overnight").item.id} into each 0.6 mL tube until the tube is empty."
      note "Vortex the 225 mL tube and change tips periodically, adding more 0.6 mL tubes to the aluminum tube rack if required."
      note "record how many aliquots will be in this batch"
      get "number", var: "aliquots", label: "Aliquots made from culture #{op.input("Overnight").item.id}", default: 40
    end
    aliquots = data[:aliquots]
    batch = op.output("Comp Cell").collection
    strain = op.output("Comp Cell").sample
    aliquots.times do
      batch.add_one strain
    end
  end
  
  # steps to perform while last centrifuge batch is spinning to make use of time.
  def callback
    prep_and_clean
    make_GYT_tubes operations.length
  end
  
  def label_and_store_batches op
    op.output("Comp Cell").item.move "M80"
    show do
      title "Label and Store"
      note "Take an empty freezer box, and label it with sample id: #{op.output("Comp Cell").sample.name}, the date, your initials, and the item id: #{op.output("Comp Cell").item}."
      note "QUICKLY transfer the aliquoted tubes to the labeled box, then store them at #{op.output("Comp Cell").item.location}"
    end
    release [op.output("Comp Cell")], interactive: false
  end
  
  def clean_up
    show do 
      title "Clean Up"
      note "Dispose of all empty 225 mL centrifuge tubes"
      note "Pour remaining ice into sink at dishwashing station"
      note "Return ice block and aluminum tube rack"
    end
  end
  
####################################################
### Methods for checking culture optical density ###   
####################################################

  #returns true if the OD of the inoculated culture >= .04
  def check_OD_initial op
    show do 
        title "Grab the following items for OD check"
        note "2 L flask from 37 shaker: #{op.input("Overnight").item.id}"
        note "1.5 mL tube"
    end

    show do 
        title "Make Aliquot"
        note "carefully pipette 100 uL from culture flask into 1.5mL tube." 
        note "swirl the flask before pipetting out culture"
        note "Return 2 L flask to shaker incubator"
    end

    cc = show do 
        title "Nanodrop the 1.5mL tube containing the culture"
        note "Make sure nanodrop is in cell culture mode"
        note "blank with LB"
        note "measure OD 600 of aliquot"
        get "number", var: "conc", label: "Culture #{op.input("Overnight").item.id}", default: 0.05
        note "discard the used 1.5mL tube"
    end
    return cc[:conc] >= 0.04
  end
  
  #make tubes that are required to nanodrop cultures after they are made competent
  def make_GYT_tubes number
      show do
          title "make 1:100 GYT dilution for nanodrop"
          note "Take #{number} empty, sterile 1.5 mL #{"tube".pluralize(number)} and add 990 uL GYT#{number > 1 ? " to each" : ""}." 
          note "Label #{number > 1 ? "each " : ""}tube as 1:100 dilution. "
      end
  end
  
  # returns the OD measurement, and assigns op.temp[good_od?] to true if the od <= 0.1
  # this is run after cultures are made competent
  def check_OD_post op
    show do 
        title "Grab the following items for OD check"
        note "#{op.input("Overnight").item.id} 225mL tube of Resuspended Cells"
        note "a 1.5 mL 1:100 GYT dilution tube"
    end

    show do 
        title "Make Aliquot"
        note 'carefully pipette 10 uL of the resuspended cells into the 1.5mL tube labeled "1:100 dilution".' 
    end

    cc = show do 
        title "Nanodrop the 1.5mL tube containing the culture"
        note "Make sure nanodrop is in cell culture mode"
        note "blank with GYT"
        note "measure OD 600 of aliquot"
        get "number", var: "conc", label: "Culture #{op.input("Overnight").item.id}", default: 0.09
        note "discard the used 1.5mL tube"
    end
    
    if cc[:conc] <= 0.1
        return nil
    else
        return cc[:conc]    
    end
    
  end
end
