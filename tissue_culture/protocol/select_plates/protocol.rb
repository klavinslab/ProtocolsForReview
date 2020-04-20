needs "Tissue Culture Libs/TissueCulture"

# TODO: ignore plates that are contaminated or look weird

class Protocol
  include TissueCulture

  # io
  OUTPUT = "Requested Plate"
  KEEP_ONE_PLATE = true
  TEST_PROTOCOL_BRANCHING = true

  def update_status op, msg
    plan = op.plan
    op.associate :status, msg
    s = op.temporary[:successor]
    s.associate :status, msg if s
    plan.associate "#{op.id}_status".to_sym, msg if plan
  end

  def main

    #  if debug and TEST_PROTOCOL_BRANCHING and operations.running.size >= 2
    #         operations.running[1].output(OUTPUT).set sample: operations.first.output(OUTPUT)
    #     end

    operations.retrieve

    show do
      title "Protocol Overview"

      note "This protocol will automatically assign plates to various tissue culture requests."
      warning "Ensure the 'Check Cell Densities' protocol has already been run. This protocol will not \
      run properly if we do not know how many cell there are. Run this protocol now if you haven't."
    end

    operations.running.each do |op|
        successors = op.successors
        successors ||= []
        requestors = []
        successors.each do |s|
            rs = s.successors || []
            if requestors.empty?
                op.associate :no_requestors, "Operation #{s.id} #{s.operation_type.name} operation has no requestors"
            end
            requestors += rs
        end
        op.temporary[:requestors] = requestors
        op.temporary[:successors] = successors
        
        rc = requestors.map { |r| r.required_cells if r.is_a?(Operation) }.reduce(:+)
        rc =  rand(0.1..10) * 10**5 if rc.nil? or rc == 0
        op.temporary[:req_cells] = rc
        op.associate :requestors, requestors.map { |r| r.operation_type.name if r.is_a?(Operation) }.compact.join(';')
    end

    show do
      title "Requesting operations"

      x = operations.running.map { |op| op.temporary[:requestors].map { |r| [op, r] } }.flatten(1)
      t = Table.new
      t.add_column("Select Plates id", x.map { |op, r| op.id } )
      t.add_column("Requestor", x.map { |op, r| r.operation_type.name if r.is_a?(Operation) } )
      t.add_column("Status", x.map { |op, r| r.status if r.is_a?(Operation) } )
      t.add_column("Req Cells", x.map { |op, r| r.required_cells if r.is_a?(Operation) } )
      table t
    end

    # Assign plates
    plate_selector operations.running

    show do
      title "Selection Results"

      op_ids = operations.map {|op| op.id}
      op_status = operations.map {|op| op.status}
      succ_ids = operations.map {|op|
        r = op.temporary[:requestor]
        name = r.operation_type.name if r and r.is_a?(Operation)
        id = r.id if r and r.is_a?(Operation)
        s = "#{name} (#{id})" if name and id
        s ||= "None"
        s
      }
      t = Table.new
      t.add_column(self.operation_type.name + " op id", op_ids)
      t.add_column("Status", op_status)
      t.add_column("Requestor", succ_ids)
      t.add_column("Rescheduled?", operations.map { |op| op.output(OUTPUT).item ? "No" : "Yes" } )
      t.add_column("Selected Plate", operations.map { |op|
        i = op.output(OUTPUT).item
        i ? i.id : "None"
      } )
      t.add_column("Required Cells", operations.map { |op|
        x = op.temporary[:req_cells]
        to_scinote(x.round(0))
      } )
      t.add_column("Available Cells in Plate", operations.map { |op|
        i = op.output(OUTPUT).item
        i ? to_scinote(i.cell_number) : 0
      } )
      table t
      
      note "Click 'OK' to continue."
    end

    # Manually reschedule operations

    # Hold operations if there are not enough plates
    operations.running.each do |op|
      oitem = op.output(OUTPUT).item
      if oitem.nil?
        hold_request(op, with_status="primed")
        update_status op, "There were not enough cells to complete the operation (requires #{op.temporary[:req_cells].round(0)}). Operation has been rescheduled." + op.temporary[:reason]
      else
          age = oitem.age_since_seed
          if age.nil?
              age = "**unknown, likely created by user**"
          end
        update_status op, "Plate #{oitem.id} has been selected (confluency: #{oitem.confluency}, passage: #{oitem.passage}, age: #{age.round(0)} hrs)."
      end
    end

    # # Display rescheduling table (for manager only!)
    #     hold_table = Proc.new { |ops|
    #         ops.start_table
    #             .custom_column(heading: "Requestor") { |op|
    #                     r = op.temporary[:requestor].
    #                     name = r.operation_type.name
    #                     id = r.id
    #                     "#{name} #{id}"
    #             }
    #             .custom_column(heading: "Req Cells") { |op| to_scinote(op.temporary[:req_cells]) }
    #             .custom_boolean(:hold, heading: "Reschedule?") { |op| "n" }
    #             .validate(:hold) { |op, v| ["y", "n"].include? v.downcase[0] }
    #             .end_table.all
    #     }

    #     show_with_input_table(operations, hold_table) do
    #         title "Requestor Table"
    #         note "Please select any requestors that should be rescheduled."
    #     end

    #     operations.each do |op|
    #         hold_request(op, with_status="primed") if op.temporary[:hold]
    #     end

    # show do
    #     title "Selecting plates"

    #     operations.running.each do |op|
    #         all_items = op.output(OUTPUT).sample.items
    #         all_items.select! { |i| PLATE_CONTAINERS.include?(i.object_type.name) }
    #         all_items.reject! { |i| i.deleted? }

    #         if all_items.empty?
    #             op.error :no_plates_found, "There were no plates found."
    #             next
    #         end

    #         all_items.reject! { |i| i.confluency.nil? or i.confluency < 0.5 * MAX_CONFLUENCY }
    #         all_items.reject! { |i| i.age < 4 + i.growth_rate }
    #         if all_items.empty?
    #             op.error :plates_need_growth, "There are plates available but they are not ready yet."
    #             next
    #         end

    #         all_items.each do |item|
    #             note "#{item.created_at.class}"

    #         end

    #         all_items.each do |i|
    #             note "#{i}"
    #         end
    #         if all_items.empty?
    #             plan = op.plan
    #             op.error :no_plates_found, "There where no plates found"
    #             plan.associate "no_plates_found_for_#{op.output(OUTPUT).sample.name}".to_sym, "No plates found"
    #         else
    #             op.output(OUTPUT).set item: all_items.sample
    #         end
    #     end
    # end

    return {}

  end

  # main


  # Assign plates to ops
  def plate_assigner ops, available_plates
    if available_plates.nil?
      return nil
    end
    plate_assignments = available_plates.product(*[available_plates] * (ops.size - 1))

    show do
      title "Selecting plates for #{ops.first.output(OUTPUT).sample.name}"

      note "Click \'OK\' to proceed."
      warning "The next few steps may take long to compute. Please be patient. You may have to refresh."
      bullet "Number of requesting operations: #{ops.size}"
      bullet "Number of active plates: #{available_plates.size}"
      bullet "Number of possible plate assignments: #{plate_assignments.size}"
    end


    best_score = nil
    plate_assignments.each do |plates|
      cell_hash = plates.map {|p| [p, p.cell_number]}.to_h

      ops.zip(plates).each {|op, plate| op.temporary[:plate] = plate}
      ops.zip(plates).each do |op, plate|
        r = op.temporary[:req_cells]
        would_remain = cell_hash[plate] - r
        if would_remain >= 0
          cell_hash[plate] = would_remain
        else
          op.temporary[:plate] = nil
        end
      end

      # delete if no operations use plate
      op_plates = ops.map {|op| op.temporary[:plate]}.compact
      cell_hash.each {|p, r| cell_hash.delete(p) if !op_plates.include?(p)}

      num_passed = ops.count {|op| op.temporary[:plate]}
      waste = cell_hash.inject(0) {|sum, (k, v)| sum + v}
      max_waste = cell_hash.inject(0) {|sum, (k, v)| sum + k.cell_number}
      num_plates = cell_hash.size
      delta_conf = cell_hash.inject(0) {|sum, (k, v)| sum + (MAX_CONFLUENCY - k.confluency)}

      # ensure there is always a plate
      plates_remaining = 0 # how many plates would be remaining if requestors run
      sample_plates = get_sample_plates ops.first.output(OUTPUT).sample
      plates_remaining += [sample_plates - plates].size.size
      ops.each do |op|
        r = op.temporary[:requestor]
        if r
          plates_remaining += 1 if r.is_a?(Operation) and r.operation_type.name == "Plate Cells"
        end
      end

      pr = 0
      keep_plate = true
      keep_plate = false if debug
      if keep_plate and plates_remaining == 0
        ops.each { |op| op.temporay[:plate] = nil }
      end
      n = (num_plates - 1.0) / (ops.size - 1)
      n = 0.0 if ops.size == 1 and num_plates == 1
      w = waste * 1.0 / max_waste
      p = (ops.size - num_passed) * 1.0 / ops.size
      d = (delta_conf) * 1.0 / (MAX_CONFLUENCY * cell_hash.size)

      # ordered from most to least important
      score_arr = [pr, p, w, n, d]
      if op_plates.empty? or cell_hash.empty?
        score_arr = [1.0] * 4
      end
      op_hash = ops.map {|op| [op, op.temporary[:plate]]}.to_h
      score = [op_hash, score_arr]
      best_score ||= score
      if (score[1] <=> best_score[1]) == -1
          best_score = score
      end
      score
    end

    return best_score
  end

  def get_available_plates s, ops
    plates = get_sample_plates s

    if debug
      plates = get_plates if plates.empty?
      plates.each do |plate|
        plate.confluency = rand(0.5..1.0) * MAX_CONFLUENCY if plate.confluency.nil?
      end
    end

    # error if there are no plates
    if plates.empty?
      ops.each do |op|
        op.temporary[:reason] = "Rescheduled: There were no plates found for #{op.output(OUTPUT).sample.name}. Culture some cells before running."
        op.temporary[:ready] = false
      end
      return []
    end
    
    if debug
        show do
            title "Plates"
            
            note "#{plates}"
        end
    end

    # reject plates that have too low of a confluency (unless parameters are specified)
    # reject plates that are too new
    
    plates_that_pass_confluency = plates.reject {|i| i.confluency.nil? or i.confluency < 0.5 * MAX_CONFLUENCY}
    
    # plates_that_pass_age = plates.reject { |i|
    #     age = i.age_since_seed
    #     pass = false
    #     if age.nil?
    #         pass = true
    #     else
    #         pass = age < 4 + i.growth_rate
    #     end
    #     pass
    # } if not debug
    plates_that_pass_age ||= plates
    
    plates_that_pass = plates_that_pass_confluency & plates_that_pass_age

    if plates_that_pass_confluency.empty?
      ops.each do |op|
        plates_didnt_pass_confluency = plates - plates_that_pass_confluency
        plates_too_young = plates - plates_that_pass_age
        pdpc_info = plates_didnt_pass_confluency.map { |p| "#{p.id} (#{p.confluency}%)" }
        pty_info = plates_too_young.map { |p| "#{p.id} (#{p.age_since_seed}hrs)" }
        reason = "Found #{plates.size} plates but there are currently not enough actively growing cells to run operation."
        reason += " Plates at too low confluency: #{pdpc_info}" if pdpc_info.any?
        reason += " Plates that are too young: #{pty_info}" if pty_info.any?
        op.temporary[:reason] = "Rescheduled: #{reason}"
        op.temporary[:ready] = false
      end
      return []
    end
    ops.reject! {|op| op.temporary[:ready]}
    plates
  end

  def filter_ops ops, available_cells, max_num_cells
    # pre-filter operations that would not be able to run
    ops.select! do |op|

      # error if there will never be enough cells
      if max_num_cells < op.temporary[:req_cells]
        requestor = op.temporary[:requestor]
        name = requestor.operation_type.name if requestor.is_a?(Operation)
        id = requestor.id if requestor.is_a?(Operation)
        op.temporary[:reason] = "Rescheduled: There are not enough plates to run \
        #{name} #{id}. At maximum growth, there would be at most #{max_num_cells} \
                                but requesting operation needs #{op.temporary[:requestor]} to run. Please submit \
                                another split plate."
        op.temporary[:ready] = false
      end

      if available_cells < op.temporary[:req_cells]
        op.temporary[:ready] = false
        op.temporary[:reason] = "Rescheduled: There are currently not enough actively growing cells (currently #{available_cells.round(0)}) to run operation."
      else
        op.temporary[:ready] = true
        op.temporary[:reason] = ""

      end
      op.temporary[:ready]
    end

    # Select only operations that are ready
    ops.select! {|op| op.temporary[:ready]}
  end

  def plate_selector ops
    grouped_by_sample = ops.group_by {|op| op.output(OUTPUT).sample}
    grouped_by_sample.each do |s, g|
      # Get available plates
      plates = get_available_plates s, g
      next if plates.empty?

      # pre-filter operations that would not be able to run
      maximum_num_cells = plates.inject(0) {|sum, plate| plate.max_cell_number + sum}
      cell_hash = plates.map {|plate| [plate, plate.cell_number]}.to_h
      available_cells = cell_hash.inject(0) {|sum, (k, v)| sum + v}
      filter_ops g, available_cells, maximum_num_cells
      next if g.empty?

      # assign plates
      assignment_hash, score_arr = plate_assigner g, plates

      show do
        title "Assignment score for #{s.name}"

        pr, p, w, n, d = score_arr
        note "Plates remaining after requestors?: #{pr}"
        note "Number of operation passed: #{p}"
        note "Waste cells: #{w}"
        note "Num plates used: #{n}"
        note "Diff from 100% confluency: #{d}"
      end if debug

      assignment_hash.each do |op, plate|
        op.output(OUTPUT).set item: plate
      end

    end
  end


end # protocol
