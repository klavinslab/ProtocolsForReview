needs "Standard Libs/Debug"
needs "SynAg/Dilute to defined density"

class Protocol
    require 'active_support'
    include Debug
    include DilutionProtocol
    
    PARAMETER = "Density goal (events per ul)"
    
    def main
        operations.each do |op|
            goal = op.input(PARAMETER).val
            op.associate :density_goal, goal
        end
        dilute_to_defined_density operations
        {}
    end

end
