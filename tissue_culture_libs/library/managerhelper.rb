# Methods for creation, destruction, copying , rescheduling or operations
module ManagerHelper
  # Unbatches this operation from any job associations
  # Changes this operation to "pending"
  # Creates a new Request Plate opeation and wires it to this operation
  def reschedule op
    ja = JobAssociation.where(operation_id: op.id).to_a
    ja.each do |j|
      j.destroy
      j.save
    end
    op.redo
    # Make sure the successors don't move to "pending" if they aren't ready yet
    op.successors.each do |suc|
      if not suc.ready?
        suc.change_status "waiting"
      end
    end
    # op.associate :rescheduled, "There were not enough cells to complete this batched operation."
    # op.plan.associate "rescheduled_#{op.id}", "There were not enough cells to complete operation #{op.id}."
  end

  # This operation holds back an on-the-fly operation
  #   (1) Re-schedules successors, but destroying its job associations
  #   (2) Copies the on-the-fly operation
  #   (3) Associates replaces old operation with new operation in plan
  #   (4) Associates a message
  #   (5) Changes the status of the new operation (should be "primed" if on-the-fly)
  def hold_request operation, with_status=nil
    # Reschedule successors
    operation.successors.each do |op|
      reschedule op # Reschedule the trypsinize cells protocols
    end

    # Copy this operation
    new_op = copy_op operation

    # Create plan assotiation
    operation.plan.plan_associations.create operation_id: new_op.id

    # Remove original operation from plan
    pas = PlanAssociation.where(operation_id: operation.id).to_a
    pas.each do |pa|
      pa.destroy
      pa.save
    end

    # error out protocol so you dont make items
    operation.error :held_operation, "This operation was held back. Replaced by operation #{new_op.id}. Former plan: #{operation.plan.id}"

    # Change status
    new_op.change_status(with_status) if with_status
    new_op
  end

  def copy_op op, rewire=true
    ot = op.operation_type
    fts = ot.field_types
    routing = fts.map do |ft|
      {from: ft.name, to: ft.name}
    end
    copy_io_to_new_op(op, ot, routing, rewire)
  end

  # def set_fv_parameter fv, val
  #     op = Operation.find_by_id(fv.parent_id)
  #     op.set_property fv.name, val, fv.field_type.role, false, fv.allowable_field_type
  # end


  # routing = \
  # [
  # {from: INPUT, to: NEW_INPUT},
  # {from: OUTPUT, to: NEW_OUTPUT},
  # {from: MEDIA, to: NEW_MEDIA},
  # ]
  # Creates a new operation of operation ot
  # Copies fv from op to this new operation
  # Changes any wires that were from op
  def copy_io_to_new_op(op, ot, routing, rewire=true)
    new_op = ot.operations.create(status: "waiting", user_id: op.user_id)

    ot.field_types.each do |ft|
      aft = ft.allowable_field_types[0]
      routing.each do |r|
        if r[:to] == ft.name
          if r[:val] # set parameter value
            new_op.set_property ft.name, r[:val], ft.role, false, aft
          elsif r[:from] # copy fv from the r[:from] to the r[:to]
            # Get old field values
            ofvs = op.field_values.select { |ofv| ofv.name == r[:from] }

            # Add a new field value for each field value :from old operation
            ofvs.each do |ofv|
              new_op.set_property ft.name, ofv.val, ft.role, false, aft
            end

            # Get all newly created field values
            fvs = new_op.field_values.select { |fv| fv.name == ft.name }

            # Set item of newly create field values
            ofvs.zip(fvs).each do |ofv, fv|
              fv.set item: ofv.item
              if rewire
                if ofv.role == 'output'
                  ofv.wires_as_source.each do |wire|
                    wire.from_id = fv.id
                    wire.save
                  end
                elsif ofv.role == 'input'
                  ofv.wires_as_dest.each do |wire|
                    wire.to_id = fv.id
                    wire.save
                  end
                end
              end
            end
          end
        end
      end
    end
    new_op
  end

  # (1) Creates a virtual operation per item
  # (2) associates item to operation with "key"
  # (3) returns virtual operation
  def items_to_vops items, key=nil
    key ||= :item
    items.map do |item|
      vop = VirtualOperation.new
      insert_operation operations.size, vop
      vop.temporary[key] = item
      vop
    end.extend(OperationList)
  end

  def destory_virtual_operations ops=nil
    # Save temporary hash
    temp_hash = operations.map { |op| [op, op.temporary] }.to_h

    # Other virtual operation (not to be deleted)
    other_vops = operations.select { |op| op.virtual? and not ops.include?(op) } unless ops.nil?
    other_vops ||= []

    # Remove all virtual operations
    operations(force: true)

    # Re-add other virtual operations
    other_vops.each do |vop|
      insert_operation operations.size, vop
    end

    # Re-instantiate temporary hash
    operations.each do |op|
      tmp = temp_hash[op]
      op.temporary.merge!(tmp) if tmp
    end
  end

  def dlog message
    show do
      title "#{message}"
    end
  end

  # Add associate error to op and plan. Save to hash of all errors
  def add_error op, to_plan=false, err_hash = {}
    err_hash.each do |err_key, err_msg|
      op.error err_key.to_sym, err_msg
      op.temporary[:errors] ||= Hash.new
      op.temporary[:errors][err_key] = err_msg
      op.plan.associate "#op{op.id}_#{err_key.to_s}".to_sym, err_msg if to_plan
    end
  end

  def error_message_table(ops)
    ops.start_table
        .custom_column("Operation ids") { |op| op.id }
        .custom_column("Error Messages") { |op| op.temporary[:error].each { |k, msg| msg }.join("; ") }
        .end_table
  end
end