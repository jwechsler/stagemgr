class NotificationMailer < ActionMailer::Base

  helper ApplicationHelper

  layout "notification_mailer"

  def suspension_alert(order,recipient,action_by=nil)
    @order = order

    subject = "#{order.display_code.titlecase} payments suspended / #{order.address.full_name}"
    mail(:to => recipient,
         :from => $EMAIL_ADDRESS['software_address'],
         :subject => subject,
         :tag=>"Recurring Payment")
  end

end
