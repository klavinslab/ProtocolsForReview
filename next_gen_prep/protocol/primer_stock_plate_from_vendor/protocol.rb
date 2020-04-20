# Devin Strickland
# dvn.strcklnd@gmail.com
#
# makes 96-well Primer Plate collection item from IDT spreadsheet (saved as .csv)

needs "Standard Libs/UploadHelper"
needs "Standard Libs/Debug"
needs "Standard Libs/MatrixTools"
needs "Standard Libs/AssociationManagement"
needs "Next Gen Prep/PrimerPlateHelper"

class Protocol

    include UploadHelper, Debug, MatrixTools, AssociationManagement
    include PrimerPlateHelper

    # upload stuff
    DIRNAME = "Unknown"
    TRIES = 3
    NUM_FILES = 1

    # IDT file format stuff
    NAME = "Sequence Name"
    POS = "Well Position"
    SEQ = "Sequence"

    # Sample
    PROJECT = "Primer Plate" # project description in Sample definition
    PRIMER = "Primer" # type of Sample
    PRIMER_PLATE = "96-Well Primer Stock Plate"

    MY_DEBUG = false

    def main
        
        operations.each do |op|
            
            if debug && MY_DEBUG
                upload = nil
                vendor_description = CSV.parse(CSV_DEBUG)
            else
                uploads = uploadData(DIRNAME, NUM_FILES, TRIES)
                upload = uploads.first
                vendor_description = CSV.read(open(upload.url))
            end
            
            vendor_description = format_data(vendor_description)
            
            find_or_create_primers(vendor_description)
            
            primer_plate = Collection.new_collection(PRIMER_PLATE)
            
            matrix = WellMatrix.create_empty(96, Collection::EMPTY)
            
            vendor_description.each do |md|
                matrix.set(md[POS], md["Sample"].id)
            end
            
            primer_plate.associate_matrix(matrix.to_array)
            associate_data(primer_plate, 'vendor_description', upload)

            show {
                title "Primer Plate Creation Successful!"
                note "Please label the #{PRIMER_PLATE} with Item ID #{primer_plate}."
            }
            
        end
        
        operations.store
        
        return {}

    end

    def find_or_create_primers(vendor_description)
        sample_type = SampleType.find_by_name(PRIMER)
            
        vendor_description.each do |md|
            sample = Sample.where(name: md[NAME], sample_type: sample_type).first
            if sample
                found_sequence = sample.properties["Overhang Sequence"].to_s + sample.properties["Anneal Sequence"].to_s
                unless found_sequence =~ /^#{md[SEQ]}$/i
                    raise "Aq entry found for #{md[NAME]}, but sequences do not match."
                end
            else
                desc = "Created automatically by Primer Stock Plate From Vendor protocol."
                sample_attr = {
                    sample_type_id: sample_type.id,
                    description: desc,
                    name: md[NAME],
                    project: PROJECT,
                    field_values: [
                      { name: "Anneal Sequence", value: md[SEQ] },
                      { name: "Overhang Sequence", value: "" },
                      { name: "T Anneal", value: md["Tm"] }
                    ]
                }
                sample = Sample.creator(sample_attr, op.plan.user)
            end
            md["Sample"] = sample
        end
    end

    def format_data(vendor_description)
        headers = vendor_description.shift
        formatted = []
        
        vendor_description.each do |row|
            row = row.map do |cell|
                cell.gsub("\"","").gsub('\xEF\xBB\xBF','').gsub("[","").gsub("]","").strip if cell.respond_to?(:strip)
            end
            row = Hash[headers.zip(row)]
            
            if row['Sequence'].blank? || row[NAME].blank?
                raise "Name or Sequence Missing:\n#{row}"
            end
            
            row['Sequence'] = row['Sequence'].gsub(/\s+/, '')
            formatted.append(row)
        end
        
        formatted
    end

end
