def precondition(_op)
    #   this is done so that Operation instance methods are available
    _op = Operation.find(_op)
#-----------------------------------------------------------------------------------------

    #   pass input, allowing downstream operations to begin
    _op.pass("Input", "Output")

    #   set status to done, so this block will not be evaluated again
    _op.status = "done"
    _op.save
    
    return true
end