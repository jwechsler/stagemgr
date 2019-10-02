class NotificationMailer < ActionMailer::Base

  helper ApplicationHelper

  layout "notification_mailer"

  def wheelchair_conversion_alert(order, recipient)
    @order = order
    subject = "#{order.display_code} wheelchair requested / #{order.address.full_name}"
    mail(:to => recipient,
         :from => $EMAIL_ADDRESS['software_address'],
         :subject => subject,
         :tag=>"Wheelchair request")
  end

  def suspension_alert(order,recipient,action_by=nil)
    @order = order

    subject = "#{order.display_code.titlecase} payments suspended / #{order.address.full_name}"
    mail(:to => recipient,
         :from => $EMAIL_ADDRESS['software_address'],
         :subject => subject,
         :tag=>"Recurring Payment")
  end

  def file_generated(filestore)
    if File.file?(filestore.data.path)
      @filestore = filestore
      attachments[filestore.data_file_name] = File.read(filestore.data.path)
      mail(:to => filestore.user.email,
           :from => $EMAIL_ADDRESS['software_address'],
           :subject => "Your download is ready",
           :tag=>"File Generation Complete")
    end
  end

end
