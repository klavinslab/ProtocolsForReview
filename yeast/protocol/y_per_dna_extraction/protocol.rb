needs "Standard Libs/Units"
needs "Standard Libs/Debug"
needs "Standard Libs/PlanParams"
needs "Standard Libs/CommonInputOutputNames"
needs "Standard Libs/TemporaryTubeLabels"

class Protocol

  include Units, Debug, PlanParams, CommonInputOutputNames
  include TemporaryTubeLabels

  attr_accessor :plan_params

  TUBE_50_ML_CONICAL = "50 ml conical tube"
  TUBE_15_ML_CONICAL = "15 ml conical tube"
  TUBE_MICROFUGE = "1.5 ml microfuge tube"

  ########## DEFAULT PARAMS ##########

  # Params that are applied equally to all operations. Can be overridden by
  #   associating a list of key, value pairs to the `Plan`.
  #
  # @example my_plan.associate("options", "{"ml_needed": 10}")

  def default_plan_params
    {
      culture_milliliters:       10,      # The ml of culture
    }
  end

  def main

    @plan_params = update_plan_params(
      plan_params: default_plan_params,
      opts: get_opts(operations)
    )

    # Takes _microliters and _milliliters keys and generates _vol keys for display purposes.
    @plan_params = add_qty_display(@plan_params)

    operations.retrieve.make
    
    associate_sample_tube_labels(DNA)

    pellet_cultures

    resuspend_in_yper

    add_dna_releasing_reagents

    add_protein_removal_reagent

    precipitate_in_isopropanol

    wash_pellet

    resuspend_dna

    operations.store

    {}

  end

  # 1. Pellet a 10mL S. cerevisiae culture grown overnight, resuspend the cells and transfer entire suspension
  #     to a 1.5mL microcentrifuge tube. Pellet cells by centrifugation at 3000-5000  g for 5 minutes at
  #     room temperature. Discard the supernatant. Typically this procedure will yield a 70-100mg pellet.
  def pellet_cultures
    culture_qty = @plan_params[:culture_qty]

    show do
      title "Label Tubes"

      note "Get #{operations.length} #{TUBE_MICROFUGE}s"
      note "Get #{operations.length} #{TUBE_15_ML_CONICAL}s"
      note "Label each set of tubes #{tube_label_display('sample', DNA)}"
    end

    show do
      title "Spin Down Cultures"

      note "Transfer #{qty_display(culture_qty)} of culture to "\
        "<b>#{TUBE_15_ML_CONICAL}s</b> according to the table"

      table operations.start_table
        .input_item(INPUT_YEAST)
        .custom_column(heading: "Tube label") { |op| sample_tube_label(op, DNA) }
        .end_table

      note "Pellet cells by centrifugation at 5000  g for 5 minutes at room temperature"
    end

    empty_weights = weigh_tubes

    show do
      title "Transfer to #{TUBE_MICROFUGE}s"

      note "When the centrifuge has stopped, retrieve the #{TUBE_15_ML_CONICAL}s"
      note "For each tube, remove the cap and pour off all of the supernatant"
      note "Using a pipettor, for each tube"
      bullet "Add 1 #{MILLILITERS} of water"
      bullet "Pipet up and down or vortex to resuspend the pellet"
      bullet "Transfer the resuspended pellet to the corresponding #{TUBE_MICROFUGE}"

      separator

      note "Pellet cells by centrifugation at 3000  g for 5 minutes at room temperature."
      note "Aspirate off all the supernatant from each tube"
    end

    pellet_weights = weigh_tubes

    associate_weights(empty_weights: empty_weights, pellet_weights: pellet_weights)

    # operations.each { |op| inspect op.output(DNA).item.associations }
  end

  # 2. Suspend cells in an appropriate amount of the Y-PER Reagent. Scale the amount of Y-PER Reagent accordingly,
  #     maintaining a ratio of 8µL/1mg pellet. Mix by gently vortexing or inverting the tube or pipetting
  #     up and down until the mixture is homogenous. Once a homogenous mixture is established,
  #     incubate at 65C for 10 minutes.
  def resuspend_in_yper
    show do
      title "Suspend cells in Y-PER Reagent"

      table operations.start_table
        .custom_column(heading: "Tube label") { |op| sample_tube_label(op, DNA) }
        .custom_column(heading: "Y-PER (#{MICROLITERS})") { |op| yper_volume(op) }
        .end_table

      note "Mix by gently vortexing until the mixture is homogenous."
      note "Incubate at 65 #{DEGREES_C} for 10 #{MINUTES}."
    end
  end

  # 3. Centrifuge at 13,000  g for 5 minutes, discard supernatant, add 400L of DNA Releasing Reagent A,
  #     and 400L of DNA Releasing Reagent B to the pellet for a total volume that should equal
  #     approximately 800L. Mix to produce a homogenous mixture and incubate at 65C for 10 minutes.
  def add_dna_releasing_reagents
    show do
      title "Spin down samples"

      note "Pellet cells by centrifugation at 13,000  g for 5 minutes at room temperature."
      note "Aspirate off all the supernatant from each tube"
    end

    show do
      title "Add DNA Releasing Reagents"

      check "Add 400 #{MICROLITERS} of DNA Releasing Reagent <b>A</b> to each #{TUBE_MICROFUGE}."
      check "Add 400 #{MICROLITERS} of DNA Releasing Reagent <b>B</b> to each #{TUBE_MICROFUGE}."
      note "Mix by gently vortexing until the mixture is homogenous."
      note "Incubate at 65 #{DEGREES_C} for 10 #{MINUTES}."
    end
  end

  # 4. Add 200L of Protein Removal Reagent to mixture and invert several times.
  #     Centrifuge at least 13,000  g for 5 minutes and transfer supernatant to a
  #     new 1.5mL centrifuge tube.
  def add_protein_removal_reagent
    show do
      title "Add Protein Removal Reagent"

      check "Add 200 #{MICROLITERS} of Protein Removal Reagent to each #{TUBE_MICROFUGE}."
      note "Mix by inverting each tube several times."
      note "Centrifuge at 13,000  g for 5 minutes at room temperature."

      separator

      note "While you are waiting, get #{operations.length} clean #{TUBE_MICROFUGE}s"
      note "Label the tubes according to the table"

      table operations.start_table
        .output_item(DNA)
        .end_table
    end

    show do
      title "Transfer Supernatant to Clean Tubes"

      note "Once the centrifuge has stopped, remove the tubes."
      note "Using a pipettor, transfer the supernatant to the corresponding clean #{TUBE_MICROFUGE}s."

      table operations.start_table
        .custom_column(heading: "Tube label") { |op| sample_tube_label(op, DNA) }
        .output_item(DNA)
        .end_table
    end
  end

  # 5. Add 600L isopropyl alcohol to fill tube. Mix gently by inversion. Precipitate genomic DNA by
  #     centrifuging the mixture at 13,000  g for 10 minutes.
  def precipitate_in_isopropanol
    show do
      title "Precipitate DNA in Isopropanol"

      check "Add 1 #{MICROLITERS} of glycogen to each tube."
      check "Add 600 #{MICROLITERS} isopropanol to each tube."
      note "Mix by inverting each tube several times."
      note "Centrifuge at 13,000  g for 10 minutes at room temperature."
    end
  end

  # 6. Remove supernatant, being careful not to discard any of the pellet, which is clear and
  #     hard to see. Add 1.5mL of 70% ethanol to the pellet, invert several times and centrifuge at
  #     13,000  g for 1 minute to wash off any residual salts or cellular debris clinging to the
  #     DNA or tube. Invert the tube to dry any residual ethanol before proceeding to Step 7.
  #     Alternatively, the dry sample in a vacuum centrifuge.
  def wash_pellet
    show do
      title "Wash Pellets"

      note "Aspirate off all the supernatant from each tube."
      warning "Be careful not to disturb the pellet, which can be hard to see."
      note "Add 1.5 #{MILLILITERS} of 70% ethanol to each tube."
      note "Mix by inverting each tube several times."
      note "Centrifuge at 13,000 #{TIMES_G} for 1 #{MINUTES} at room temperature."
    end

    show do
      title "Dry Pellets"

      note "Aspirate off all the supernatant from each tube."
      warning "Be careful not to disturb the pellet, which can be hard to see."
      note "Open the tubes and leave them in a rack on the bench for 15 #{MINUTES} to dry."
    end
  end

  # 7. Resuspend in 50L TE buffer or sterile water. Pellet should solubilize completely within 5 minutes.
  #     Flick the bottom of the tube carefully, or pipette solution up and down. Wash the sides of
  #     the tubes until all the genomic DNA is in solution.
  def resuspend_dna
    show do
      title "Resuspend DNA"

      note "Add 50 #{MICROLITERS} sterile water to each tube."
      note "Close the tubes and let them sit on the bench for 5 #{MINUTES}."
      note "After 5 #{MINUTES} gently flick each tube to make sure the pellet is dissolved."
    end
  end

  def weigh_tubes
    show do
      title "Weigh tubes"

      note "Weigh each of the <b>#{TUBE_MICROFUGE}s</b>"
      note "Record the weight in grams to <b>three decimal places</b>."

      table operations.start_table
        .custom_column(heading: "Tube label") { |op| sample_tube_label(op, DNA) }
        .get(:tube_weight, type: "number", heading: "Weight (g)")
        .end_table
    end
  end

  def associate_weights(empty_weights:, pellet_weights:)
    operations.each do |op|
      if debug
        pw = rand(0.07..0.1).round(3)
        op.output(DNA).item.associate(:pellet_weight, pw)
      else
        ew = empty_weights.get_table_response(:tube_weight, op: op)
        pw = pellet_weights.get_table_response(:tube_weight, op: op)
        op.output(DNA).item.associate(:pellet_weight, pw - ew)
      end
    end
  end

  def yper_volume(op)
    pellet_weight(op) * 1000 * 8
  end

  def pellet_weight(op)
    op.output(DNA).item.get(:pellet_weight)
  end

end