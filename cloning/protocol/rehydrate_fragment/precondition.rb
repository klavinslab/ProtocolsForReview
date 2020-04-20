def precondition(op)
  input = "Lyophilized Fragment"
  if op.input_data(input, :ng)
      return true
  else
      return false
  end
end