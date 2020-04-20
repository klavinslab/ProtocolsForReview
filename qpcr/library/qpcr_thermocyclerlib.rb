# By: Eriberto Lopez
# elopez3@uw.edu
# Production 10/05/18

# This module is used to setup the BioRad qPCR thermocycler to quantify illumina indexed libraries
module QPCR_ThermocyclerLib
    
    QPCR_THERMO_CONDITIONS = "illumina_qPCR_quantification_v1.prcl"
    QPCR_THERMO_PLATE_LAYOUT = "illumina_qPCR_plate_layout_v1.pltd"
    EXPERIMENTAL_FILEPATH = "/Desktop/_qPCR_UWBIOFAB"
    EXPORT_FILEPATH = "Desktop/BIOFAB qPCR Exports" 
    
    def todays_date
        DateTime.now.strftime("%m%d%Y")
    end

    def setup_biorad_qpcr_thermocycler_workspace(q_coll_id)
        
        image_path = "Actions/BioRad_qPCR_Thermocycler/"
        img1 = image_path + "open_biorad_thermo_workspace.JPG"
        img2 = image_path + "setup_workspace.JPG"
        img3 = image_path + "setting_up_qPCR_thermo_conditions.png"
        img4 = image_path + "setting_up_plate_layout_v1.png"
        img5 = image_path + "open_lid.png"
        img6 = image_path + "close_lid.png"
        img7 = image_path + "start_run.png"
        
        show do 
            title "Setting Up BioRad qPCR Thermocycler"
            separator
            warning "The next steps will be done on the qPCR computer"
        end
        show do 
            title "Setting Up BioRad qPCR Thermocycler"
            separator
            note "Click the icon shown below to launch the BioRad qPCR workspace."
            image img1
        end
        show do 
            title "Setting Up BioRad qPCR Thermocycler"
            separator
            note "Next, click on the <b>PrimePCR</b> and choose <b>SYBR</b>."
            image img2
        end
        show do 
            title "Setting Up Thermocycler Conditions"
            separator
            note "To setup the thermocycler conditions, select: <b>#{QPCR_THERMO_CONDITIONS}</b>."
            image img3
        end
        show do 
            title "Setting Up BioRad qPCR Thermocycler Plate Layout"
            separator
            note "To setup the thermocycler plate layout, select: <b>#{QPCR_THERMO_PLATE_LAYOUT}</b>."
            image img4
        end
        
        take [Item.find(q_coll_id)], interactive: true
        
        experiment_name = "jid_#{jid}_item_#{q_coll_id}_#{todays_date}_qpcr"
        show do 
            title "Starting qPCR Run"
            separator
            note "In the <b>Start Run</b> tab:"
            note "<b>1.</b> Click the <b>Open Lid</b> button."
            image img5
            note "<b>2.</b> Place qPCR Plate_#{q_coll_id} on the thermocycler."
            bullet "MAKE SURE THAT THE PLATE IS IN THE CORRECT ORIENTATION"
            note "<b>3.</b> Click the <b>Close Lid</b> button."
            image img6
            note "<b>4.</b> Finally, click the <b>Start Run</b> button."
            bullet "Save experiment as ==> <b>#{experiment_name}</b> to the <b>#{EXPERIMENTAL_FILEPATH}<b>"
            image img7
        end
        return experiment_name
    end
    
    def export_qpcr_measurements(experiment_name)
        image_path = "Actions/BioRad_qPCR_Thermocycler/" 
        img1 = image_path + "exporting_qPCR_quantification.png"
        show do
            title "Exporting qPCR Measurements"
            separator
            note "Once the run has finished, we need to export our measurements"
            note "<b>1.</b> Click the <b>Export</b> tab."
            note "<b>2.</b> Select <b>Export All Data Sheets</b>."
            bullet "Export all sheets as CSV"
            note "<b>3.</b> Save files to the <b>#{EXPORT_FILEPATH}/b> directory."
            image img1
        end
    end
    
    def uploading_qpcr_measurments(experiment_name)
        upload_filename = experiment_name + " - Quantification Summary_0.csv" # Suffix of file will always be the same
        up_show, up_sym = upload_show(upload_path=EXPORT_FILEPATH, upload_filename)
        if debug
            upload = Upload.find(11278) # Dummy data set
        else
            upload = find_upload_from_show(up_show, up_sym)
        end
        return upload
    end
    
end # Module QPCR_Thermocycler# Library code here