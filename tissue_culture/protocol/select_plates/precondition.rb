eval Library.find_by_name("TemporaryExtensions").code("source").content
extend TemporaryExtensions

def precondition(op)
  
  
    successors ||= []
    requestors = []
    successors.each do |s|
        rs = s.successors || []
        if requestors.empty?
            op.associate :no_requestors, "Operation #{s.id} #{s.operation_type.name} operation has no requestors"
        end
        requestors += rs
    end
    op.temporary[:requestors] = requestors
    op.temporary[:successors] = successors
        
    rc = requestors.map { |r| r.required_cells if r.is_a?(Operation) }.reduce(:+)
    rc =  rand(0.1..10) * 10**5 if rc.nil? or rc == 0
    # op.temporary[:req_cells] = rc
    op.associate :req_cells, rc
    # op.associate :requestors, requestors.map { |r| r.operation_type.name if r.is_a?(Operation) }.compact.join(';')
    return true
  # only run if check cell densities has been run today
  # if not, then create a plan and schedule it
end