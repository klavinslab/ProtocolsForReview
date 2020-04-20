# Abe modified this to remove active record mutators

# Loads necessary libraries for mammlian cell protocols
category = "Tissue Culture Libs"
needs "#{category}/ManagerHelper"
needs "#{category}/CollectionDisplay"
needs "#{category}/TemporaryExtensions"
needs "#{category}/TissueCultureConstants"
needs "#{category}/CentrifugeLib"
needs "#{category}/SafetyLib"

module Conversion
  # Big number string formating
  # Large integers to scientific notation string
  def to_scinote(x, decimal=3)
    if not x.nil?
      "%.#{decimal}E" % x
    end
  end

  # Scientific notation string to float
  def from_scinote(s)
    if not s.nil?
      eval(s)
    end
  end
end #Conversion

module CellGrowth
  # Logistic growth equations
  # Find a seeding density such that it reaches confluency after t hours
  # Returns 0 if there is no starting density that satisfies the conditions
  def find_starting_density(nt, t, k, d)
    r = Math.log(2) / d
    s = k / ((k/nt - 1)*Math.exp(r*t)+1)
    if nt == s
      s = nil # this means that there is no starting density
    end
    s.to_f
  end

  # Find amount of time it will take to reach a goal density
  def find_culture_time(nt, n0, k, d)
    if nt == n0
      return 0.0
    end
    r = Math.log(2) / d
    a = k/nt - 1
    b = k/n0 - 1
    Math.log(a/b)/-r
  end

  # Estimate density at time t
  def est_cell_density(n0, t, k, d)
    r = Math.log(2) / d
    k / (1 + (k/n0 - 1) * Math.exp(-r*t))
  end
end

# TODO: extend all items so that by default, they transform strings to floats to ints

# Generic Krill methods
# will be loaded in into TissueCulture and CellCulture libraries
module TissueCultureKrill
  include TissueCultureConstants
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::TagHelper
  include ManagerHelper

  def growth_area_of(container)
    data = JSON.parse(container.data)
    data[GROWTH_AREA].to_f
  end
  
  def get_time_now
    Time.zone.now
  end
  
  def get_timestamp_now
    get_time_now.utc.iso8601.gsub(":", "_")
  end

  # Gets the working volume of the container/plate
  def working_volume_of(container)
    data = JSON.parse(container.data)
    data[WORKING_VOLUME].to_f
  end

  # Whether a confluency is valid
  def valid_confluency?(confluency)
    confluency.to_f.between?(0.0, MAX_CONFLUENCY) and !confluency.nil?
  end
end # MyKrill

module CellCulture
  include TissueCultureConstants
  include TissueCultureKrill
  include Conversion
  include CellGrowth

  ######## CONFLUENCY ########
  # Gets confluency from record
  def confluency
    get_latest_confluency
  end

  # Sets the confluency
  def confluency= conf
    update_confluency conf
  end

  # Updates confluency with Time.now and some options
  def update_confluency conf, opts={upload: nil, notes: nil, buffer_color: nil}
    _update_confluency conf, self.get_time_now(), opts
  end

  # Used to update the confluency after seeding
  def update_seed conf, new_passage
    r = get_latest_record
    raise "#{self.id} has a record already! #{r} Cannot set seed." if r
    self.confluency = conf
    self.passage = new_passage
    self.seed = conf
    self.seed_date = self.get_time_now()
  end

  def seed_date
    d = self.get(SEED_DATE)
    begin
      d = d.to_time
    rescue
      # nothing
    end
    d
  end

  def seed_date= d
    self.associate SEED_DATE, DateTime.parse(d.to_s).to_time
  end

  def seed
    self.get SEED
  end

  def seed= s
    self.associate SEED, s
  end

  def _update_confluency(conf, time, opts={upload: nil, notes: nil, buffer_color: nil})
    raise ArgumentError, "Confluency #{conf} is not valid. Must be between 0.0 and #{MAX_CONFLUENCY}" if !valid_confluency?(conf)
    notes = opts[:notes]
    upload = opts[:upload]
    buffer_color = opts[:buffer_color]
    r = {
        time: self.get_time_now(),
        CONFLUENCY => conf,
    }
    r[:image_key] = upload.name if upload
    r[:notes] = notes if notes
    r[:buffer_color] = buffer_color if buffer_color
    now = self.get_time_now()
    cr = record || []
    cr.push r
    associate CONFLUENCY_RECORD, cr
    associate CONFLUENCY, conf
    associate_confluency_image(upload) if !upload.nil?
    self.cell_number
  end

  # Associates confluency image using the upload.name as a key
  def associate_confluency_image(upload)
    self.associate upload.name, nil, upload=upload
  end

  def confluency
    r = get_latest_record
    get_latest_record[CONFLUENCY] if r
  end

  def passage= p
    self.associate PASSAGE, p.to_i
  end

  def passage
    self.get(PASSAGE).to_i
  end

  def record
    confluency_record = self.get CONFLUENCY_RECORD
    if confluency_record
      confluency_record.map { |r|
        if r.is_a?(Hash)
          time_string = r[:time]
          begin
            r[:time] = DateTime.parse(r[:time]).to_time
          rescue
            r[:time] = nil
          end
          image = self.upload(r[:image_key])
          # if image.nil
          #     raise KeyError, "Could not find associated image for #{r[:image_key]}"
          # end
          r[:image] = self.upload(r[:image_key])
        end
        r
      }
    end
    confluency_record
  end

  def clear_record
    self.associate CONFLUENCY_RECORD, nil
  end

  def get_latest_record
    record.last if record
  end

  def split_from(from_plate, seed_confluency)
    cell_num = from_plate.cell_number
    p = from_plate.passage || 1

    self.update_seed seed_confluency, p + 1

    cell_number / from_plate.cell_number
  end

  ######## CELL SIZE, CONTAINER SIZE, & CELL NUMBER ########
  # Gets the growth area of the container/plate
  def growth_area
    growth_area_of(self.object_type)
  end

  # Gets the working volume of the container/plate
  def working_volume
    working_volume_of(self.object_type)
  end

  # Maximum cell number for this container
  def max_cell_number
    _cell_number MAX_CONFLUENCY
  end

  # Gets estimated cell size from sample type definition
  def cell_size
    cell_size = self.cell_line.properties[CELL_SIZE].to_f
    if cell_size.nil?
      raise ArgumentError, "Cannot find property #{CELL_SIZE}"
    end
    cell_size
  end

  def _cell_number c
    begin
      container_size = growth_area
      if container_size.nil?
        raise ArgumentError, "Cannot get growth area for #{self.object_type}"
      end
      return nil if c.nil?

      if c < 0.0
        raise ArgumentError, "Cannot get association \"#{CONFLUENCY}\" for item #{self}. Confluency was less than 0 (#{c})."
      end

      plate_sample = Sample.find_by_id(self.sample.id)
      if plate_sample.nil?
        raise ArgumentError, "Cannot find #{ACTIVE_CELL_LINE_NAME} sample for #{self}"
      end

      if self.cell_line.nil?
        raise ArgumentError, "Cannot find #{CELL_LINE} for sample #{plate_sample}"
      end

      (container_size * 1E-2**2)/(self.cell_size*(1E-6**2)) * c / MAX_CONFLUENCY
    rescue TypeError
      # nothing
    end
  end

  # Gets estimated cell number based on container size, cell size, and confluency
  def cell_number
    cn = nil
    if self.confluency
      cn = _cell_number confluency
    else
      if self.volume and self.cell_density
        cn = self.volume * self.cell_density
      end
    end
    self.associate NUM_CELLS, to_scinote(cn) if cn
    cn
  end

  def _sample_is_a s, type_name
    st = SampleType.find_by_id(s.sample_type_id)
    raise "Cannot find sample type for #{s.name}." if st.nil?
    st.name == type_name
  end

  def _sample_is_a_cell_line s
    self._sample_is_a s, BASE_CELL_LINE_NAME
  end

  def _sample_is_an_active_cell_line s
    self._sample_is_a s, ACTIVE_CELL_LINE_NAME
  end

  def is_a_base_cell_line
    st = SampleType.find_by_id(self.sample.sample_type_id)
    st.name == BASE_CELL_LINE_NAME
  end

  def parent
    _parent_sample self.sample
  end

  def cell_line
    self._cell_line_recursion self.sample, 0
  end

  def _parent_sample s
    s.properties[CELL_LINE]
  end

  def _cell_line_recursion s, counter
    raise "Cannot find cell line for #{self.sample.name}" if s.nil?
    counter = counter + 1
    raise "Too many recursions for finding cell line" if counter > 10
    p = self._parent_sample s
    if p.nil?
      return s if _sample_is_a_cell_line(s)
    else
      return _cell_line_recursion p, counter
    end
  end

  def growth_rate
    gr = self.cell_line.properties[GROWTH_RATE].to_f
    orgr = sample.properties[OVERRIDE_GROWTH_RATE].to_f
    gr = orgr if orgr and orgr != 0.0
    gr
  end

  def find_cell_line_culture_time(nt)
    x = find_culture_time(nt, confluency, MAX_CONFLUENCY, growth_rate)
    if x == 1.0/0.0 or x == -1.0/0
      x = nil
    end
    x
  end

  def find_cell_line_starting_density(nt, t)
    x = find_starting_density(nt, t, MAX_CONFLUENCY, growth_rate)
    if x == 1.0/0.0 or x == -1.0/0
      x = nil
    end
    x
  end

  def est_cell_line_density(t)
    est_cell_density(confluency, t, MAX_CONFLUENCY, growth_rate)
  end

  def age_since_seed
    t = self.seed_date
    return nil if t.nil?
    (Time.zone.now - t)/3600.0
  end

  def age
    t = self.seed_date
    t ||= self.created_at
    (self.get_time_now() - t)/3600.0
  end

  def volume= v
    self.associate :volume, v
  end

  def volume
    self.get :volume
  end

  def _associate_item key, item
    self.associate key, item.id
  end

  def _get_item key
    id = self.get key
    Item.find_by_id(id)
  end

  def from= item
    self._associate_item :from, item
  end

  def from
    self._get_item :from
  end

  def cell_density= cd
    self.associate CELL_DENSITY, cd
  end

  def cell_density
    self.get CELL_DENSITY
  end

  # age in hours
  def time_since_last_check
    record = get_latest_record
    return nil if record.nil?
    return nil if confluency.nil?
    (self.get_time_now() - record[:time])/3600.0
  end

  def estimate_confluency
    delta_t = self.time_since_last_check
    est_cell_line_density(delta_t)
  end

end # CellCulture

module TissueCulture
  include TissueCultureConstants
  include ManagerHelper
  include CellGrowth
  include TissueCultureKrill
  include Conversion
  include CollectionDisplay
  include TemporaryExtensions
  include ActionView::Helpers::TagHelper
  include CentrifugeLib
  include SafetyLib
  
  # Prepend class types
  Item.prepend(CellCulture)
  Collection.prepend(CellCulture)

  # Displays ppe to put on to technician
  def required_ppe(ppe_list)
    show do
      title "Put on the following PPE"
      ppe_list.each do |ppe|
        check ppe
      end
    end
  end

  def get_sample_plates s
    items = s.items.select { |i| !i.deleted? }
    return [] if items.empty?
    plates = items.select { |i| PLATE_CONTAINERS.include?(i.object_type.name) }
    plates
  end

  def get_plates containers=nil
    get_plates_aux containers, as_virtual_operations=false
  end

  def get_plates_as_vop containers=nil
    get_plates_aux containers, as_virtual_operations=true
  end

  def get_plates_aux containers=nil, as_virtual_operations=true
    plates = []
    containers ||= PLATE_CONTAINERS
    containers.each do |c|
      cp = Item.where(object_type_id: ObjectType.find_by_name(c))
      cp = cp.select { |c| !c.deleted? }
      plates = plates + cp
    end

    # Make virtual operation for each plate
    return items_to_vops plates, key=:plate if as_virtual_operations
    return plates
  end

  def time_string t
    t.strftime("%a %y-%m-%d")
  end

  def today_string
    time_string get_time_now()
  end

  def parse_date time_str
    DateTime.parse(time_str)
  end

  # Date of next date string
  def date_of_next(day)
    date = DateTime.parse(day)
    delta = date > DateTime.parse(get_time_now().to_s) ? 0 : 7
    date = date + delta
    date.to_time
  end

  def put_in_hood(items)
    show do
      title "Place the following items in #{HOOD}"

      check "Spray each item with 70% ethanol, wipe down, and place in #{HOOD}."

      t = Table.new
      t.add_column("Item", items.map { |i| i.sample.name rescue i })
      t.add_column("Item Id", items.map { |i| i.id rescue '' })
      table t
    end
  end

  # Instruct the technician to clean and open the hood
  def open_hood
    extra = ShowBlock.new(self).run(&Proc.new) if block_given?
    show do
      title "Prepare #{HOOD}"
      raw extra if block_given?
      warning "Ensure you ware wearing proper PPE"
      check "If hood is closed, open sash of hood to indicated level. Ensure fan is on."
      check "Turn on projector"
      check "Turn on hood light (located on the left)."
      note "Brightness can be adjusted to maximize projector contrast."
      check "Ethanol your gloves. Wipe down the interior surfaces of the #{HOOD} with #{ENVIROCIDE} with a KimWipe"
    end
  end

  # Instruct the technician to clean and close the hood
  def close_hood
    extra = ShowBlock.new(self).run(&Proc.new) if block_given?
    show do
      title "Prepare #{HOOD}"
      raw extra if block_given?
      warning "Ensure you ware wearing proper PPE"
      check "Remove and properly dispose of waste in the #{HOOD}"
      check "Ethanol your gloves. Wipe down the interior surfaces of the #{HOOD} with #{ENVIROCIDE} with a KimWipe"
      check "Turn off hood light (located on the left)."
      check "Turn off projector"
      check "Close sash"
    end
  end

  def release_tc_plates(items)
    items.uniq!
    items.map! { |i|
      i.reload
      #   i.store
    }

    to_return = items.select { |i| !i.deleted? }
    to_discard = items.select { |i| i.deleted? }

    if to_return.any?
      show do
        title "Return flasks/items"

        to_return.each do |i|
          item i.features
        end
      end
    end

    if to_discard.any?
      show do
        title "Sterilize discarded plates"

        warning "Be sure you are wearing eye protection!"
        check "Bring plates to sink area."
        check "Add a small amount of bleach to each flask/plate. Media should turn purple and eventually, clear."
        check "Close plate/flask and leave in sink off to the side."
        note "Be sure to leave plates/flasks as you would in the incubator so that bleach contacts the cells."
        check "Leave plates in sink overnight to sterilize."


        t = Table.new
        t.add_column("Plates to discard", to_discard.map { |d|
          {content: "#{d.id} (#{d.object_type.name})",
           check: true}
        })
        t.add_column("Location", to_discard.map { |d| d.location })
        table t
      end
    end
  end


  # Displays image tag for Krill (as in tables or custom)
  def display_image(image_name, opts={height: "100%", width: "100%"})
    image_url = "#{Bioturk::Application.config.image_server_interface}#{image_name}"
    "<img src=\"#{image_url}\" height=\"#{opts[:height]}\" width=\"#{opts[:width]}\"></img>"
  end
  
  def eggtimer(minutes)
    return "<a href=http://e.ggtimer.com/#{minutes}%20minutes target='blank'>#{minutes} min timer</a>"
  end

  # Determines which serological pipette to use
  def which_sero(vol)
    sero = 10.0
    case
      when vol < 1.3
        sero = 1
      when vol <=13.0
        sero = 10
      when vol < 30.0
        sero = 25
      when vol < 60
        sero = 50
      else
        sero = "?"
    end
    sero
  end
end # MyModule