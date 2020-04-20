needs "Hydra Husbandry/UnverifiedHydra"
needs "Hydra Transgenics/HydraInformatics"

class Protocol

  include UnverifiedHydra
  include HydraInformatics
  require 'csv'
  
  def main

    operations.retrieve(interactive: false)
    
    electroporation_headers = ['Hydra ID', 'Electroporation Date', 'Cuvette Size', 'Pulse Length', 'Field Strength', 'Voltage', 'DNA Mass', 'DNA Modification']
    verification_headers = ['Hydra ID', 'Date Verified', 'Transgenic Cells Avg', 'Total Hydra', 'Transgenic Cells Total']
    
    e_csv = initializeCSV(electroporation_headers)
    v_csv = initializeCSV(verification_headers)
    e_wells = findByAttribute(:last_electroporated)
    v_wells = findWithAttribute("Verification")
    log_info(e_wells)
    
    e_csv = addElectroporationData(e_csv, e_wells)
    log_info(e_csv)
    e_file = CSV.parse(e_csv)
    log_info(e_file)
    
    v_csv = addVerificationData(v_csv, v_wells)
    log_info(v_csv)
    v_file = CSV.parse(v_csv)
    log_info(v_file)
    

    
    # Uploads
    # data = show do
    #     upload var: :my_uploads
    # end
    # upload_ids = data[:my_uploads]
    # upload = Upload.find_by_id(upload_ids.first[:id])
    # log_info(upload)
    # Offer to download file, or upload to server
    # TODO: What to associate the file with, object or user?
    
    return {}
    
  end
  
  # Add 
  def initializeCSV(headers)
    csv = ''
    headers.each{|label| csv << label << ','}
    csv = csv[0,csv.length-1]
    csv << "\n"
    return csv
  end
  
  # Add electroporation data to a specified csv from a list of Hydra Wells
  def addElectroporationData(csv, hydra_list)
    columns = ['last_electroporated', 'gap_size', 'pulse_length', 'field_strength', 'voltage', 'mass_dna']
    hydra_list.each do |hydra|
        csv << hydra.id.to_s
        csv << ", "
        columns.each{|key| csv << hydra.get(key.to_sym).to_s << ", "}
        csv = csv[0,csv.length-2]
        csv << "\n"
    end
    return csv
  end
  
  # Add verification data to a specified csv from a list of Hydra Wells
  def addVerificationData(csv, hydra_list)
      columns = ["date_verified", "avg_cells", "num_hydra", "transgenic_cells"]
      hydra_list.each do |hydra|
          verifications = getVerifications(hydra)
          verifications.each do |data|
              csv << hydra.id.to_s
              csv << ", "
              columns.each{|key| csv << data[key].to_s << ", "}
              csv = csv[0, csv.length-2]
              csv << "\n"
          end
      end
      return csv
  end
  
  def formatCSV(arr)
    row = ''
    arr.each{|element| row << element.to_s << ','}
    row << '\n'
    return row
  end
  
  # Format hash to remove extra spaces
  def formatData(data)
      data.keys.each{|key| data}
  end

end
