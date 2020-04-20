module CheckForGrowth
    
 # Verify whether each input has growth and error it if it does not
  # IMPORTANT: this must go before operations.make because it changes the number of operations to make
  def check_for_growth(input)
    verify_growth = show do
        title "Check if the yeast culture has growth"
        note "Choose No for the yeast culture that does not have growth."
        operations.each do |op|
            item_id = op.input(input).item.id
            select ["Yes", "No"], var: "#{item_id}", label: "Does tube #{item_id} have growth?"
        end
    end
    
    deleted_ops = []
    operations.each do |op|
        item = op.input(input).item
        if verify_growth["#{item.id}".to_sym] == "No"
            op.change_status('pending')
            op.associate :sent_to_pending, 'The overnight has no growth, sent to pending'
            item.associate :no_growth, "This was marked as having no growth"
            deleted_ops.push(op)
        end
    end
    
    # if there are ops that have no growth
    if !deleted_ops.empty?
        show do
            title "No Growth"
            note "The following operations and it's item were marked as 'no growth' and the operation was sent to pending"
            deleted_ops.each do |op|
                note "Operation ID: #{op.id}, Item ID: #{op.input(input).item}"
            end
            warning "Please notify a lab manager"
            note "Return these items to the shaker"
            note "The protocol will now continue without the listed above"
        end
    end
    # continue on without pending ops
    operations.select! { |op| op.status == 'running' }
  end
end