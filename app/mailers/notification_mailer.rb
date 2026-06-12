class NotificationMailer < ActionMailer::Base
  helper ApplicationHelper

  layout 'notification_mailer'

  def wheelchair_conversion_alert(order, recipient)
    @order = order
    subject = "#{order.display_code} wheelchair requested / #{order.address.full_name}"
    mail(to: recipient,
         from: Rails.configuration.x.email_address['software_address'],
         subject: subject,
         tag: 'Wheelchair request')
  end

  def suspension_alert(order, recipient, _action_by = nil)
    @order = order

    subject = "#{order.display_code.titlecase} payments suspended / #{order.address.full_name}"
    mail(to: recipient,
         from: Rails.configuration.x.email_address['software_address'],
         subject: subject,
         tag: 'Recurring Payment')
  end

  def file_generated(filestore)
    return if filestore.datafile.nil?

    @filestore = filestore
    attachments[filestore.file_name] = {
      mime_type: filestore.datafile.content_type,
      content: filestore.datafile.download
    }
    mail(to: filestore.user.email,
         from: Rails.configuration.x.email_address['software_address'],
         subject: 'Your download is ready',
         tag: 'File Generation Complete')
  end

  def broadcast_log_generated(filestore, recipient_email)
    return unless filestore.datafile.attached?

    @filestore = filestore
    attachments[filestore.file_name] = {
      mime_type: filestore.datafile.content_type,
      content: filestore.datafile.download
    }
    mail(to: recipient_email,
         from: Rails.configuration.x.email_address['software_address'],
         subject: 'Broadcast Email Log Ready',
         tag: 'Broadcast Log')
  end
end
