# Library code here

module TwistOrder
    
    TWIST_USER = Parameter.get("TWIST User")
    TWIST_PW =  Parameter.get("TWIST Password")
    URL = "https://twistbioscience.com/"
    
    def get_shipment_content(order_number)
        
        show do 
            title "Navigate to website and log in"
            note "Open in a new tab: <href = #{URL}>Twist Website</href}"
            note "Click 'Log in' in the top right hand corner"
            check "Enter User name: #{TWIST_USER}, Password: #{TWIST_PW}"
        end
        
        show do 
            title "Download Shipment content"
            note "In the panel on the left hand side select 'Orders & Drafts'"
            check "Choose 'Past orders' and select order number #{order_number}"
            check "Select 'Download Shipment Content"
        end
    end
end