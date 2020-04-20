needs "Standard Libs/Units"
needs "Standard Libs/Debug"
needs "Standard Libs/PlanParams"
needs "Standard Libs/CommonInputOutputNames"
needs "Standard Libs/TemporaryTubeLabels"

class Protocol

  include Units, Debug, PlanParams, CommonInputOutputNames, TemporaryTubeLabels

  attr_accessor :plan_params

  MICROLITERS_TO_PROCESS = "Microliters To Process"
  RETENTION_LIMIT = "Retention Limit"

  TUBE_MICROFUGE = "1.5 ml microfuge tube"

  BEAD_RATIOS = {
    "1000 bp" => 0.5,
    "450 bp" => 0.6,
    "350 bp" => 0.7,
    "300 bp" => 0.8,
    "250 bp" => 0.9,
    "150 bp" => 1.5,
    "100 bp" => 3
  }

  ########## DEFAULT PARAMS ##########

  # Params that are applied equally to all operations. Can be overridden by
  #   associating a list of key, value pairs to the `Plan`.
  #
  # @example my_plan.associate("options", "{"ml_needed": 10}")

  def default_plan_params
    {
      binding_time_minutes:      15,
      elution_vol_microliters:   50,
      elution_time_minutes:      2,
      elution_buffer:            "Qiagen EB Buffer"
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

    equilibrate_and_vortex_beads

    add_beads_to_dna

    capture_beads

    wash_beads

    elute_dna

    capture_beads

    transfer_to_clean_tubes

    check_remaining_volume

    operations.store

    {}

  end

  # 1. Ensure that KAPA Pure Beads has been equilibrated to room temperature and
  #    that the beads are fully resuspended before proceeding.
  def equilibrate_and_vortex_beads
    show do
      title "Warm Up and Vortex Beads"

      note "Remove the KAPA Pure Beads from the refrigerator."
      note "Let the beads warm up on the bench."
      note "Once the beads are at room temperature, vortex them briefly."
    end
  end

  # 2. Add 80 L of KAPA Pure Beads to the 100 L fragmented DNA sample.
  # 3. Mix thoroughly by vortexing and/or pipetting up and down multiple times.
  # 4. Incubate the plate/tube(s) at room temperature for 5  15 min to bind the DNA to the beads.
  def add_beads_to_dna
    dna_hed = "DNA Volume (#{MICROLITERS})"
    bead_hed = "Bead Volume (#{MICROLITERS})"
    binding_time_qty = @plan_params[:binding_time_qty]


    show do
      title "Add Beads to DNA"

      note "Get #{operations.length} #{TUBE_MICROFUGE}s."
      note "Label the tubes #{tube_label_display('sample', DNA)}"
      note "Pipet the indicated volumes of #{DNA} and KAPA Pure Beads into the tubes."
      table operations.start_table
        .input_item(DNA)
        .custom_column(heading: "Label") { |op| sample_tube_label(op, DNA) }
        .custom_column(heading: dna_hed, checkable: true ) { |op| dna_volume(op) }
        .custom_column(heading: bead_hed, checkable: true) { |op| bead_volume(op) }
        .end_table

      note "Incubate the tube(s) at room temperature for #{qty_display(binding_time_qty)} to bind the DNA to the beads."
    end
  end

  # 5, 17. Place the plate/tube(s) on a magnet to capture the beads. Incubate until the liquid is clear.
  def capture_beads
    show do
      title "Capture Beads"

      note "Place the tube(s) on a magnet to capture the beads."
      note "Incubate until the liquid is clear."
    end
  end

  # 6. Carefully remove and discard the supernatant.
  # 7. Keeping the plate/tube(s) on the magnet, add 200 L of 80% ethanol.
  # 8. Incubate the plate/tube(s) on the magnet at room temperature for 30 sec.
  # 9. Carefully remove and discard the ethanol.
  # 10. Keeping the plate/tube(s) on the magnet, add 200 L of 80% ethanol.
  # 11. Incubate the plate/tube(s) on the magnet at room temperature for 30 sec.
  # 12. Carefully remove and discard the ethanol. Try to remove all residual ethanol without disturbing the beads.
  def wash_beads
    add_ethanol = "Keeping the tube(s) on the magnet, add 200 #{MICROLITERS} of 80% ethanol."
    incubate_beads = "Incubate the tube(s) on the magnet at room temperature for 30 #{SECONDS}."
    remove_ethanol = "Carefully remove and discard the ethanol."

    show do
      title "Wash 2X With Ethanol"

      note "Carefully remove and discard the supernatant."
      note add_ethanol
      note incubate_beads
      note remove_ethanol

      note add_ethanol
      note incubate_beads
      note remove_ethanol

      warning "Try to remove all residual ethanol without disturbing the beads."
    end
  end

  # 13. Dry the beads at room temperature for 3  5 min, or until all of the ethanol has evaporated. Caution: over-drying the beads may result in reduced yield.
  # 14. Remove the plate/tube(s) from the magnet.
  # 15. Resuspend the beads in an appropriate volume of elution buffer (10 mM Tris-HCl, pH 8.0  8.5) or PCR-grade water, depending on the downstream application.
  # 16. Incubate the plate/tube(s) at room temperature for 2 min to elute the DNA off the beads. The elution time may be extended up to 10 min if necessary to improve DNA recovery.
  def elute_dna
    elution_vol = qty_display(@plan_params[:elution_vol_qty])
    elution_buffer = @plan_params[:elution_buffer]
    elution_time = qty_display(@plan_params[:elution_time_qty])

    show do
      title "Elute DNA"

      note "Leaving the tube caps open, dry the beads at room temperature for 3–5 min, or until all of the ethanol has evaporated."
      warning "Do not dry more than 5 minutes."
      note "Remove the tube(s) from the magnet."
      note "Resuspend the beads in #{elution_vol} of #{elution_buffer}."
      note "Incubate the tube(s) at room temperature for #{elution_time} to elute the DNA off the beads."
    end
  end

  # 18. Transfer the clear supernatant to a new plate/ tube(s). Proceed with your downstream application, or store DNA at 4oC for 1  2 weeks, or at -20oC.
  def transfer_to_clean_tubes
    show do
      title "Transfer Supernatant to Clean Tube"

      note "Get #{operations.length} #{TUBE_MICROFUGE}s and label them according to the output column."
      note "Transfer the clear supernatant to the new tube(s)."
      table operations.start_table
        .custom_column(heading: "Label") { |op| sample_tube_label(op, DNA) }
        .output_item(DNA)
        .end_table
    end
  end

  def check_remaining_volume
    show do
      title "Check the Remaining Volume of the Input DNA"

      note "Indicate whether the following tubes are empty"
      table operations.start_table
        .input_item(DNA)
        .get(:empty, heading: "Empty?", type: "text", default: "N")
        .end_table
      note "You may discard the empty tubes"
    end

    if debug
      operations[1].temporary[:empty] = "Y"
    end

    operations.each do |op|
      op.input(DNA).item.mark_as_deleted if op.temporary[:empty] =~ /y/i
    end
  end

  def dna_volume(op)
    op.input(MICROLITERS_TO_PROCESS).value
  end

  def bead_volume(op)
    ret_limit = op.input(RETENTION_LIMIT).value
    ratio = BEAD_RATIOS[ret_limit]
    dna_volume = op.input(MICROLITERS_TO_PROCESS).value.to_f
    (ratio * dna_volume).round
  end

end
