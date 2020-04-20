module PlanParams

  # Gets :options from the plan associations and uses it to override default_plan_params
  #
  # @return [Hash] plan_params
  def update_plan_params(plan_params:, opts:)
    if opts.present?
      opts = JSON.parse(opts, { symbolize_names: true })
      plan_params.update(opts)
    end
    plan_params
  end

  #gets the options on the first operaton of a plan
  def get_opts(operations)
    operations.first.plan.associations[:options]
  end

  #gets the options on a specific operation
  def get_op_opts(op)
    op.plan.associations[:options]
  end

  #sets plan params as a temporary association to the operation under the :plan_params key
  def set_temporary_op_params(op, default_plan_parameters)
      opts = get_op_opts(op)
      op.temporary[:plan_params] = update_plan_params(plan_params: default_plan_params, opts: opts)
  end
 
end