# By: Eriberto Lopez
# elopez3@uw.edu
# 06/14/18

# This protocol is used to Save, Export, and upload a timeseries measurement from the Biotek Plate Reader
# The location/directory of the file should be manually set to '_UWBIOFAB' directory in the template protocol

needs "Plate Reader/PlateReaderHelper"
needs "Standard Libs/Debug"

class Protocol
    
    include PlateReaderHelper
    include Debug
    
    # I/O
    INPUT = "Plate"
    
    # Parameters
    KEEP_PLT = 'Keep Plate?'
    # Constants


#!#!#!#!# Issue is that the timeseries filename is the experiment name so, lets associate that info with the plate that will be measured on the plate reader
#!#!#!#!# Then get it with the key used to associate 'timeseries_filename'
#!#!#!#!# And the other issue is that the protocol template sends the file to Novel_chassis directory not to _UWBIOFAB

    def main
        
        operations.each do |op|
           in_collection = op.input(INPUT).collection
           keep_plt = op.input(KEEP_PLT).val.to_s
           
        #   export_filename(collection=in_collection, method='timeseries', timepoint=20) # timepoint is duration of timeseries plate reader
           filename = Item.find(in_collection.id).get('timeseries_filename')
           
           # Directs tech through biotek plate reader software in order to export time series measurements
           export_timeseries_data(filename)
           
           # Find measurements and upload
           show {
               title "Locating Upload"
               separator
               note "The file you just exported should be in the <b>'_UWBIOFAB'</b> directory"
               note "It is called: #{filename}"
           }
            # Show block upload button and retrieval of file uploaded
            up_show, up_sym = upload_show(filename)
            if (up_show[up_sym].nil?)
                show {warning "No upload found for Plate Reader measurement. Try again!!!"}
                up_show, up_sym = upload_show(filename)
            else
                upload = find_upload_from_show(up_show, up_sym)
                key = "#{filename}"
                associate_to_plans(key, upload)
                associate_to_item(in_collection, key, upload)
            end
            
            (keep_plt == 'No') ? (in_collection.mark_as_deleted) : (in_collection.location = 'Bench')
            in_collection.save
            if (keep_plt == 'No')
                show {
                    title "Cleaning Up..."
                    separator
                    note "Rinse out Plate <b>#{in_collection}</b> with DI H2O and bleach"
                    note "Then rinse once more with EtOH"
                }
            else
                show {
                    title "Cleaning Up..."
                    separator
                    note "Move <b>#{in_collection}</b> to <b>#{in_collection.location}</b>"
                }
            end
        end
        
    end # Main
    
end # Class
