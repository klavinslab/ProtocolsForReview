class Protocol

  def main

    operations.each do |op|
        subject = "Hello from Job #{jid}"
        msg = %(
            <p>
              This email is regarding operation
              <b>#{op.id}</b> and plan <b>#{op.plan.id}</b>.
            </p>
        )
        op.user.send_email subject, msg unless debug
    end
    
    show do 
        title "Emails sent"
    end
    
  end

end
