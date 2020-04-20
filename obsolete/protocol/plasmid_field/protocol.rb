class Protocol

  def main
    operations.retrieve.make
    #similar expressions
    #sample_type.where(name: "Plasmid")
    plasmid = SampleType.find_by_name("Plasmid") 
    
    #sample_type.where(name: "Plasmid")
    st_plasmid = Sample.where(sample_type_id: plasmid.id) #active record
    #s_ids = st_plasmid.map { |s| s.id }
    st_2 = st_plasmid[1..10]
    #s_tmp = FieldValue.where(parent_id: st_plasmid[0].id, parent_class: "Sample", name: "Transformation Temperature").first
    #s_tmp = st_plasmid[0].properties["Transformation Temperature"]
    
    #show do
    #    note "#{s_tmp.id}"
    #    note "#{st_plasmid.size}"
    #end
    
    #fvs = FieldValues.where(parent_class: "Sample", parent_id: s_ids, name: "Transformation Temperature")
    #s_tmp = FieldValue.where(parent_id: st_plasmid[0].id, parent_class: "Sample", name: "Transformation Temperature").first
    #raise(s_tmp.inspect) #("Transformation Temperature")
    #raise(FieldValues.inspect)
    
    #fvs = FieldValues.where(parent_class: "Sample", parent_id IN s_ids, name: "Transformation Temperature")

    #fvs.length => 5

    #st_plasmid.each do |s|
        #does any in fvlist belong to s?
        #if fvs.contains(s)
            #yes: set that fv to 37
            #fv[i] = 37
        #else
            #create fv
            #fv.add[new fv]
            

    #s2 = st_plasmid[1..3]
    #then for each sample of sample type plasmid, edit, and modify 'Transformation Temperature' to equal 37 degrees Celcius.
    st_plasmid.each do |sample|
        #Item.find_by_id(i.id)
        #show do 
        #    note "#{sample.id}"
        #    note "#{sample.properties["Transformation Temperature"] == 37}"
        #end
        
        s_tmp =  FieldValue.where(parent_id: sample.id, parent_class: "Sample", name: "Transformation Temperature").first
        if s_tmp == nil
            x = sample.field_values.create(name: "Transformation Temperature", value: 37)
            x.save
        else
            s_tmp.value = 37
            s_tmp.save 
        end
        
        #sample.properties["Transformation Temperature"] = 37
        #sample.save
        # if sample.properties["Transformation Temperature"] != 37
        #     raise "EEEEE"
        # end
    end
      {}
  end
end