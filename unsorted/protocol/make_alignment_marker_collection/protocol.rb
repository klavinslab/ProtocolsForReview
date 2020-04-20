needs "Standard Libs/Debug"
class Protocol
    
  # I/O        
  SAMPLE_TYPE="Item"
  COLLECTION_TYPE="Same size as this collection"
  OUTPUT="Batch"
  
  # params
  LOCATION = "M20"
    include Debug
  def main
      
    op = operations.first
    
    # make output item
    operations.make    
    
    # build new collection matrix
    dims=op.input(COLLECTION_TYPE).collection.dimensions
    new_col=Array.new(dims[0]) { Array.new(dims[1]) { -1 } }
    dims[0].times do |r|
        dims[1].times do |c|
            new_col[r][c]=op.input(SAMPLE_TYPE).sample.id
        end
    end
    
    # op.add_input 'Alignment Marker', op.input(SAMPLE_TYPE).sample, ObjectType.find_by_name('Stripwell')
    # associate to output collection
    log_info op.output(OUTPUT)
    outcol=op.output(OUTPUT).collection
    
    outcol.matrix=new_col
    outcol.save
    op.output(OUTPUT).item.save
    
    # set output location 
    op.output(OUTPUT).item.move(LOCATION)
    op.output(OUTPUT).item.save
    
    show do 
        title "Collection (finished and ready to use)"
        note "Use the \'edit collection\' protocol to add or remove samples"
        note "Made new #{op.output(OUTPUT).item.object_type.name}"
        note "Collection link #{op.output(OUTPUT).item}"
        note "Location is #{op.output(OUTPUT).item.location}"
        table op.output(OUTPUT).collection.matrix
    end
    
    return {}
    
  end

end
