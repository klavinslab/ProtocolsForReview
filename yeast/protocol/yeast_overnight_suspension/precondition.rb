# Returns true if the `Yeast Strain` input to the operation has passed QC.
#
# @param op [Operation]  the operation

# Precondition for making sure that Yeast Overnight Suspension passes in expected values and ensures that
# it will either pass/fail depending on if it requires QC/passed QC
# 
# Pseudocode:
# if QC is not required, automatically pass
#
# if input is a Yeast Plate, then check for faulty :correct_colonies values
#   if :correct_colonies is is either nil, an empty string, or an empty array
#       fail
#
# if QC is required or dependent on previous QC, check if it has passed QC
#   if passed QC, pass
#   if not passed, fail
require 'json'

def precondition(op)
 
    strain = op.input('Yeast Strain')
    strain.make
    # if QC is not required, automatically pass
    return true if op.input('Require QC?') && op.input('Require QC?').val.strip.downcase == 'no'
                                                                        #.strip.casecomp?('no')
    
    # if input is a Yeast Plate, then check for faulty :correct_colonies values
    if (strain.object_type.description == 'Yeast Plate')
        #   if :correct_colonies is is either nil, an empty string, or an empty array
        colony_array = strain.item.get(:correct_colonies)
        if colony_array.instance_of?(String)
            colony_array = JSON.parse(colony_array)
        end
    
        if colony_array.blank?
          op.associate("Precondition Failed", "correct_colonies is empty")
          return false
        end
        
        colonies = colony_array.flatten
        if colonies.empty?
          op.associate("Precondition Failed", "correct_colonies is empty")
          return false
        end
    end
    
    return false unless op.input('Require QC?')

    # QC is required or dependent on previous QC, check if it has passed QC
    pass_QC = strain.sample.properties['Has this strain passed QC?']
    return false unless pass_QC
    return true if pass_QC.strip.downcase == 'yes'
        
    #   not passed, fail
    op.associate("Precondition Failed", "QC is required or requires only previous QC, but QC has not passed")
    false
end