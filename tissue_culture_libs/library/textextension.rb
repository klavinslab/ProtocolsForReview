module TextExtension
    include ActionView::Helpers::TagHelper
    
    def bold
        return content_tag(:b, self) 
    end
    
    def ital
        return content_tag(:i, self)
    end
    
    def strong
        return content_tag(:strong, self)
    end
end