eval Library.find_by_name("ControlBlock").code("source").content
extend ControlBlock

# Generic response block that is fully paramaterizable from the planner. Asks user for a response,
# waits for the response before continuing, then once the response is recieved: associates
# response to the item being passed through this operation and continues the workflow 
def precondition(_op)
    # gain access to operation instance methods 
    op = Operation.find(_op.id)
    
    # get params
    response_request = op.input("Response Request Message").val
    response_regex = op.input("Response Regex Format").val
    response_tag = op.input("Response Tag").val
    response_status_tag = "Response Block status"
    response_level = op.input("Response Level").val
    
    case response_level
    when "Plan"
        obj = _op.plan
        response_tag += " [#{_op.id}]"
        response_status_tag += " [#{_op.id}]"
    when "Operation"
        obj = _op
    when "Item"
        obj = _op.input("Sample").item
    end
    
    # library method from ControlBlock (Could this interface be improved?)
    user_response = get_user_response(op, response_request_message: response_request, response_regex: response_regex)
    
    # if the user hasn't responded yet, fail and keep downstream operations in waiting
    return false if user_response.nil?
    
    # Response recieved!
    
    # associate response to the item being passed through
    obj.associate(response_tag, user_response)
    
    # associate note on operation to indicate that you cant retroactively change response
    op.associate "Response Block status", "Your response was successfully recorded as \"#{user_response}\""
    
    # pass input, allowing downstream operations to begin
    op.pass("Sample", "Sample")

    # set status to done, so this block will not be evaluated again
    op.status = "done"
    op.save
    
    return true
end