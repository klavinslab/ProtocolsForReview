module TissueCultureConstants

  # Materials
  TRYPSIN = "TrypLE"
  PBS = "PBS -Ca -Mg"
  PFA = "PBS + 5% PFA"
  ETOH = "70% ethanol"
  ENVIROCIDE = "Envirocide"

  # Locations
  HOOD = "Biosafety Cabinet"
  TEMP_LOC = "Ethanol Spray Area"
  INCUBATOR = "37C C02 incubator"
  BSL2 = "BSL2 room"
  MAINLAB = "Main Lab"
  
  # Cell culture config
  TRYPSIN_PER_CM2 = 1.0/55.0 # mL / CM2   e.g. 1mL per 100mm plate
  MAX_CONFLUENCY = 100.0

  # Transfection config
  PEI = "PEI"
  L3000 = "Lipofectamine 3000"
  TRANSFECTION_REAGENT_TO_DNA_RATIO = {
      PEI => 3.0,
      L3000 => 1.5
  }
  TRANSFECTION_VOL_TO_WORKING_VOLUME = 0.1 # e.g. 100ul transfection mix per 1mL media in a 12-well dish
  TRANSFECTION_DNA_NG_PER_UL = 10.0 # ng / ul

  # Field/Property Names
  # ...a place to store field property name and data association keys for all protocols
  CELL_SIZE = "Cell Size (um^2)"
  GROWTH_RATE = "Growth Rate (hr/div)"
  OVERRIDE_GROWTH_RATE = "Override Growth Rate (hr/div)"
  CONFLUENCY = :confluency
  SEED = :seed_confluency
  SEED_DATE = :seed_date
  PASSAGE = :passage
  CONFLUENCY_RECORD = :confluency_history
  NUM_CELLS = :number_of_cells
  CELL_LINE = "Parent Cell Line"
  GROWTH_AREA = "growth_area"
  WORKING_VOLUME = "working_volume"
  CRYOMEDIA = "Cryopreservation Additive"
  GROWTH_MEDIA = "Growth Media"
  CELL_DENSITY = "cells_per_mL"

  # Sample definition names
  BASE_CELL_LINE_NAME = "Mammalian Cell Line"
  ACTIVE_CELL_LINE_NAME = "Active Cell Line"

  # Container definitions
  PLATE_CONTAINERS = [
      "T175",
      "T25",
      "T75"
  ]
  TRYPSINIZED_PLATE_CONTAINERS = [
      "Trypsinized T175",
      "Trypsinized T75",
      "Trypsinized T25",
      "Cell Suspension"
  ]
  MULTIWELL_CONTAINERS = [
      "12-Well TC Dish",
      "6-Well TC Dish",
      "24-Well TC Dish",
      "96-Well TC Dish"
  ]
  PLATE_REQUESTS = [
      "Plate Request"
  ]
  ALL_PLATES = PLATE_CONTAINERS + TRYPSINIZED_PLATE_CONTAINERS + MULTIWELL_CONTAINERS

  # PPE
  STANDARD_PPE = ["Lab Coat", "Latex Gloves", "Goggles"]
  CRYOSTOCK_PPE = ["Lab Coat", "Latex Gloves", "Goggles", "<b>Face Shield</b>", "<b>Freezer Gloves</b>"]

  # Transfection

  # Validations
  [BASE_CELL_LINE_NAME, ACTIVE_CELL_LINE_NAME].each do |name|
    raise "Sample Type #{name} not found" if SampleType.find_by_name(name).nil?
  end

  # validate_sample_type_names [BASE_CELL_LINE_NAME, ACTIVE_CELL_LINE_NAME]
end