needs "Tissue Culture Libs/TissueCultureConstants"

module SafetyLib
    include TissueCultureConstants
    
    def lentivirus_warning
        show do
            title "LENTIVIRUS IS HAZARDOUS"
            warning "This protocol uses lentivirus. Lentivirus is an infectious but non-replicative retrovirus. It can \
            cause harm if it contacts your skin, eyes, mouth, etc. Treat it as a BSL2 hazardous substance."
            separator
            warning "Always use #{ENVIROCIDE} to clean up spills. #{ETOH} DOES NOT WORK!"
            separator
            warning "By continuing you verify you have undergone proper safety training for BSL2 hazards."
        end
    end
end