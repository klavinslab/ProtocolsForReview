require 'date'
require 'json'

def precondition(op)
    return true unless op.input('Options')
    
    opts = JSON.parse(op.input('Options').value, { symbolize_names: true })
    
    return true unless opts[:delay_until]
    
    if opts[:delay_until] =~ /\d{2}\/\d{2}\/\d{2}/
        frmt = "%m/%d/%y"
    elsif opts[:delay_until] =~ /\d{4}-\d{2}-\d{2}/
        frmt = "%Y-%m-%d"
    else
        return true
    end
    
    Time.now >= Time.strptime(opts[:delay_until], frmt)
end