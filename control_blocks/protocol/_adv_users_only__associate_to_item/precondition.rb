def precondition(_op)
  #   this is done so that Operation instance methods are available
  _op = Operation.find(_op)
  _op.pass("Sample", "Sample")

  item = _op.input("Sample").item
  associations = _op.input("Associations").val
  associations.each do |k, v|
    item.associate(k, v)
  end

  _op.status = "done"
  _op.save
  return true
end