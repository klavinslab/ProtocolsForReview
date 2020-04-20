# ControlBlock module has library methods for use in preconditions and functional blocks
# that cover common use cases of implementing control structures and decision logic into aquarium plans
#
module ControlBlock

  # Convienence method for debugging preconditions and functional Blocks
  def log_out op, str
    op.associate str, "debugging log"
  end

  # DynamicBranching module has methods that are helpful for programming functional blocks which
  # control execution of a plan in full or part.
  # Theoretically these methods could be called from any operations, to affect any other operations, regardless
  # of if they are functional blocks. The intended use case is for them to be run from a functional block code,
  # to affect the outputs and wires of that same functional block.
  # NOTE: Correct use of routing ids while definiting functional blocks is crucial for
  # taking advantage of this module
  # module DynamicBranching

  # Triggers execution of a subset of the possible output branches from an operation by satisfying their item
  # No new output items are made by this call, branches are triggered when the routed input is passed through to outputs
  # Output branches are assumed to be proper forkings from the same input, they should all be routed from this input
  #
  # @param outputs  [Array<FieldValue>] affirmed outputs that will recieve items
  def affirm_branches outputs
    begin
      op = outputs.map { |output| output.operation }.uniq.first
      route = outputs.map { |output| FieldType.find(output.field_type_id).routing }.uniq.first
      input = op.inputs.select { |input| FieldType.find(input.field_type_id).routing == route }.uniq.first
    rescue IndexError
      raise "in a operation/block which affirms a subset of its outputs, the outputs must be proper forkings of a single input from that block (sharing route id)"
    end
    outputs.each do |output|
      # pass input item up to good outputs
      output.set item: input.item
      output.save
    end
  end

  # For each output in the given list of outputs, errors the full downstream branch
  # Can be used in conjunction with affirm_branches to make functional blocks which trigger
  # execution of some branches and error the rest
  #
  # @param outputs  [Array<FieldValue>] outputs that start a path towards a branch that will be cancelled
  def cancel_branches outputs, message=nil
    threads = []
    outputs.each do |bad_out|
      threads << Thread.new do
        bad_out.wires_as_source.each do |bad_wire|
          bad_op = FieldValue.find(bad_wire.to_id).operation
          recursively_error_downstream(bad_op, message)
          # bad_wire.delete
        end
      end
    end

    threads.each { |thr| thr.join }

    plan = outputs[0].operation.plan

    outputs.each do |bad_out|
      bad_out.wires_as_source.each do |bad_wire|
        to_op = bad_wire.to.operation

        # create new "Canceled" operation, with single input and output
        ot = OperationType.where({"deployed"=> true, "name"=>"Canceled", "Category"=>bad_out.operation.operation_type.category})[0]
        new_op = ot.operations.create(status: "error", user_id: plan.user_id)

        # create new input
        input_aft = ot.field_types.find {|ft| ft.name == "Input"}.allowable_field_types[0]
        new_op.set_property "Input", bad_out.sample, "input", false, nil
        new_op.input("Input").set item: nil

        # create new output
        output_aft = ot.field_types.find {|ft| ft.name == "Output"}.allowable_field_types[0]
        new_op.set_property "Output", bad_out.sample, "output", false, nil
        new_op.output("Output").set item: nil

        # adjust coordinates
        new_op.x = to_op.x
        new_op.y = to_op.y + 75
        new_op.save()

        new_wire = Wire.new from_id: new_op.outputs[0].id, to_id: bad_wire.to_id
        new_wire.save()

        plan.plan_associations.create operation_id: new_op.id
        bad_wire.to_id = new_op.inputs[0].id
        bad_wire.save()
      end
    end
    outputs[0].operation.plan.save()
  end

  # ot = OperationType.find_by_name("Clean Up Sequencing")
  # new_op = ot.operations.create(
  #     status: "waiting",
  #     user_id: op.user_id
  # )
  # op.plan.plan_associations.create operation_id: new_op.id
  #
  # aft = ot.field_types.find {|ft| ft.name == "Stock"}.allowable_field_types[0]
  # new_op.set_property "Stock", stock.sample, "input", false, aft
  # new_op.input("Stock").set item: stock
  #
  # aft = ot.field_types.find {|ft| ft.name == "Plate"}.allowable_field_types[0]
  # new_op.set_property "Plate", stock.sample, "input", false, aft
  # new_op.input("Plate").set item: plate
  #
  # op.plan.reload
  # new_op.reload
  #
  # Recursively error all operations in the downstream branch, starting from the given root op
  def recursively_error_downstream(op, message=nil)
    if op.status != "error"
      op.change_status("error")
      err_msg = message || "this operation was canceled by a control block"
      op.associate("canceled", err_msg)
      next_ops = collect_downstream_ops(op)
      next_ops.each do |nop|
        recursively_error_downstream(nop)
      end
    end
  end

  # Return an array of the direct downstream children of the given operation
  # TODO if speed becomes an issue for recuresively navigating branches, this algorithm could be improved
  def collect_downstream_ops(op)
    op.outputs.map { |out| out.wires_as_source.map { |wire| FieldValue.find(wire.to_id).operation } }.flatten
  end
  # end

  # UI module has methods for (in the plan view) requesting input from the user
  # and showing output to the user
  #
  # module UI
  # Creates an input box for accepting user response in the given operation
  # Returns nil and notifies user until user responds correctly in
  # the input box for the given operation and once a response is recieved, returns that response
  #
  # @param op  [Operation] the operation to which the user must respond to
  # @param opts  [Hash] required method arguments, specifying how to collect response
  # @option response_request_message  [String] the label of the input textbox shown to user
  # @option response_regex  [String]  Regex expression as a string to validate user response
  #                           by default no validation will be done
  # @return  [String] user response if given, nil if still waiting on response
  def get_user_response(op, opts = {})
    response_request = opts[:response_request_message]
    response_regex = opts[:response_regex]

    # TODO parameterize notifications with operation type name so they can be found on plan easier

    # Notifications for user while waiting on response, or for when response fails to meet required format
    plan_waiting_notification = "Waiting for your input on operation #{op.id}"
    plan_rejection_notification = "Response rejected on operation #{op.id}. Expects pattern \"#{response_regex}\""
    op_rejection_notification = "Given response did not meet the required format"
    generic_disclaimer = "Plan will not move forward until a response is received"

    # Generate input textbox for user if it does not yet exist
    # Alert user on plan that there is an operation awaiting their input
    op_response = op.get(response_request)
    if op_response.nil? || op_response == ""
      op.associate(response_request, "")
      op.plan.associate(plan_waiting_notification, generic_disclaimer) if op.plan
      return nil
    end

    # Response recieved - validate response with regex, if regex given
    # If response fails format, notify user
    if response_regex && response_regex != "" && !(Regexp.new(response_regex).match(op_response))
      op.associate(op_rejection_notification, generic_disclaimer)
      op.plan.associate(plan_rejection_notification, generic_disclaimer)
      return nil
    end

    # Response is valid - Remove notifications that remind user to answer response
    op.plan.get_association(plan_waiting_notification).delete if op.plan.get_association(plan_waiting_notification)
    op.plan.get_association(plan_rejection_notification).delete if op.plan.get_association(plan_rejection_notification)
    op.get_association(op_rejection_notification).delete if op.get_association(op_rejection_notification)

    # return response
    return op_response
  end
  # end
end