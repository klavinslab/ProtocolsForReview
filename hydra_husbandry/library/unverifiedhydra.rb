# UNVERIFIED HYDRA COLLECTIONS

=begin

Overview
The location management needed for Hydra:
	After any hydra has contacted a well, no other hydra may be added until the plate is bleached
	A hydra should be added in the first available well in the plate
	After all hydra have been removed from a plate, it should be bleached and reused

CONTAINERS
Managing unverified hydra will require two object types:
- Unverified Hydra Well (UVHW)
	This object type represents a single well in an unverified hydra plate
	It is of type "sample_container"
	It contains some number of hydra of a particular sample
- Unverified Hydra Plate (UVHP)
	This object type represents a plate of 3x4=12 Unverified Hydra Wells (UVHP)
	It is of type "collection", and thus is automatically associated with a matrix
		The matrix is a 3x4 array of numbers
			In an operation, the items can be indexed in one of two ways:
				1. by row and column c.matrix[row][col]
				2. by a single index of the flattened array c.matrix.flatten[index]
			To the lab technician, rows and columns are referenced by letter and numbers (starting at A and 1 respectively)
			e.g. the well at index (1, 0) is displayed as well B1
		Each number in the matrix is an item ID corresponding to a single UVHW item
		If a well does not contain any hydra, the matrix entry is set to -1
	In addition to the matrix of item IDs, we will also associate an integer with the key "next_clean_well"
		The additional integer records the index of the next uncontaminated well in the plate
		When new hydra are added to the next available well, the auxilliary integer is incremented

COLLECTIONS
The UVHP object_type is of type "collection"; this can be accessed from inside a protocol/library as follows:
	c = op.input("Name").collection # this returns the collection object
	c.matrix # this returns the matrix of item IDs
Data cannot be associated directly with the collection, since the .associate method was overwritten
	c.associate(:key, value) # DOES NOT WORK
Instead, data must be associated with the corresponding item:
  i = Item.find(c.id)
  i.associate(:key, value)
Likewise, the collection can be obtained from the corresponding item:
  c = Collection.find(i.id)

STATES
Every Hydra Strain *sample* is either transgenic or wild-type
	This state is stored in the sample field called "type"
	All hydra in UVHWs are transgenic
	This field does not affect the code in this library
Every Hydra Strain *item* is either verified or unverified;
	A hydra is unverified iff it is in a UVHW (NOT stored explicitly)
	Hydra are placed in UVHWs (and hence rendered unverified) by transformation protocols (e.g. electroporation)
	Hydra are removed from UVHWs (and hence rendered "verified" in verification protocols (e.g. visualization)
Every Hydra Strain *item* is either feedable or unfeedable
	A hydra is unfeedable iff it was transformed within the last 24 hrs (NOT stored explicitly)

=end

# Abbreviations:
  # UVHW = Unverified Hydra Well
  # UVHP = Unverified Hydra Plate

module UnverifiedHydra
  
  # returns a new UVHW item of the given sample
  def new_uvhw(sample)
    item = sample.make_item "Unverified Hydra Well"
    item.location = "Not Stored in Plate!"
    return item
  end
  
  # returns a new empty UVHP collection
  def new_uvhp()
    plate = Collection.new_collection "Unverified Hydra Plate"
    set_ncw(plate, 0)
    return plate
  end
  
  # returns the index of the next clean well of the given plate
  def get_ncw(plate)
    return Item.find(plate.id).get(:next_clean_well)
  end
  
  # sets the next clean well (ncw) of the given plate
  def set_ncw(plate, ncw)
    Item.find(plate.id).associate(:next_clean_well, ncw)
  end
  
  # return the plate collection object that contains the given well, in addition
    # to the row and column of the plate where the well is located
  # returns nil if the well is not in any plate
  def find_uvhw(well)
    # find the plate containing the well
    plate = find_all_uvhp.find{|plate| plate.matrix.flatten.include?(well.id)}
    return nil if plate == nil
    # find the row and column belonging to the well
    r, c = plate.find(well.id).first # NOTE: Collection class overrides find
    return plate, r, c
  end
  
  # returns an array of all active UVHP collections
  def find_all_uvhp()
    # find all UVHP items
    plates = find(:item, { object_type: { name: "Unverified Hydra Plate" } } )
    # convert items back to collections
    plates = plates.map{|plate| Collection.find(plate.id)}
    return plates
  end
  
  # stores the given UVHW in the next clean well of a UVHP
  # if no clean wells available, creates a new UVHP
  # returns the plate the well was stored in
  def store_uvhw(well)
    # choose the first non-full UVHP or a new UVHP if none available
    plate = find_all_uvhp.select{|plate| get_ncw(plate) != -1}.first || new_uvhp
    # find the next clean well of the plate
    ncw = get_ncw(plate)
    # calculate the corresponding position in the 2D array
    cols = plate.dimensions[1]
    r, c = ncw / cols, ncw % cols
    plate.set(r, c, well.id)
    # increment the plate's next clean well (-1 if no more clean wells)
    ncw = ncw < plate.matrix.flatten.size - 1 ? ncw + 1 : -1
    set_ncw(plate, ncw)
    # assign the well a new location
    well.location = name_of_uvhw(well)
    return plate
  end
  
  # removes the given UVHW from the UVHP containing it and marks it as deleted
  def remove_uvhw(well)
    # find the location of the new uvhw
    plate, r, c = find_uvhw(well)
    # set the item id pointer in the matrix to -1
    plate.matrix[r][c] = -1
    # mark the well as deleted
    well.mark_as_deleted
  end
  
  # instructs tech to bleach any empty UVHPs and marks them as deleted
  def bleach_empty_uvhp()
    plates = find_all_uvhp.select{|plate| plate.empty?}
    show do
      title "Bleach Unverified Hydra #{"Plate".pluralize(plates.size)}"
      plates.each do |plate|
        note "Bleach plate #{plate.id} with 10% dissociation medium"
        plate.mark_as_deleted
      end
    end if plates.any?
  end
  
  # returns a human-readable form of the given well's location
    # e.g. Well 123456(B3) is in well B3 of plate 123456
  def name_of_uvhw(well)
    plate, r, c = find_uvhw(well)
    return "Well #{plate.id}(#{'ABCD'[r]}#{c+1})"
  end
  
  # returns true iff the given UVHW was electroporated within the last 24 hours
  def is_feedable(well)
    tnow = Time.now.to_f
    tthen = well.get(:last_electroporated) || 0
    return tnow - tthen > 24 * 60 * 60
  end
  
  # returns a list of the human-readable names of UVHWs in the given UVHP that
    # are feedable (i.e. have not been electroporatedd within the last 24 hours)
  # returns nil if there are no feedable UVHWs in the given UVHP
  def feedable_wells(plate)
    feedables = plate.matrix.flatten.map do |id|
      next nil if id == -1
      well = Item.find(id)
      is_feedable(well) ? name_of_uvhw(well) : nil
    end
    return feedables.any? ? feedables.compact : nil
  end
  
  # returns a checkable table of which wells are feedable in the given plate
  # can be displayed with 'table feedable_wells_table(plate)' in show block
  def feedable_wells_table(plate)
    tab = plate.matrix.map do |row|
      row.map do |id|
        next "(empty)" if id == -1
        well = Item.find(id)
        {content: "#{well.id}", check: is_feedable(well) ? true : false}
      end
    end
    tab.unshift((1..6).to_a)
    ['', 'A', 'B', 'C', 'D'].each.with_index{ |str, i| tab[i].unshift(str) }
    return tab
  end
  
end
