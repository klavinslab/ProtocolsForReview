def precondition(_op)
  #   this is done so that Operation instance methods are available
  _op = Operation.find(_op)
  _op.pass("Input", "Output")
  _op.status = "done"
  _op.save
  return true
end