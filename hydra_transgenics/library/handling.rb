module Handling
  
  # returns true if the given sample is transgenic
  def transgenic? sample
    return sample.properties["type"] == "Transgenic"
  end
  
end