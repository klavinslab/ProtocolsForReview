module General
    def standard_PPE
        show do 
            title "Don the appropriate PPE"
            check "Lab coat"
            check "Overshoes"
            check "Gloves"
        end
    end
    
    def weeks_old i
        ((Time.zone.now - i.created_at) / 604800).round
    end
    
    def expected_leaves i
        ((Time.zone.now - i.created_at) / 604800).round
    end
    
    def days_old i
        ((Time.zone.now - i.created_at) / 86400).round
    end
    
    def hours_old i
        ((Time.zone.now - i.created_at) / 3600).round
    end
    
end