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

  # The paid order's notes carry each failure's amount and reason (see
  # ChargeAfterChecks#flag_failed_additional_donation); no card data is kept.
  def additional_donation_failed_alert(order, recipient)
    @order = order
    @failures = order.notes.to_s.lines.map(&:strip)
                     .select { |line| line.start_with?(Order::DONATION_NOT_PROCESSED_NOTE) }
    mail(to: recipient,
         from: Rails.configuration.x.email_address['software_address'],
         subject: "Additional donation not processed / Order #{order.id} / #{order.address.full_name}",
         tag: 'Donation Not Processed')
  end

  # Queued by TicketOrder#create_notify_refund_task. NotificationTask calls
  # every alert as (order, recipient), so the refunding user is read back off
  # the order's audit trail rather than passed in.
  def refunded_fulfilled_item_alert(order, recipient)
    @order = order
    @refunded_by = refunded_by(order)
    mail(to: recipient,
         from: Rails.configuration.x.email_address['box_office'],
         subject: "Warning: Fulfilled order #{order.id} refunded",
         tag: 'Alert')
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

  private

  # Username on the audit that moved the order to REFUNDED; audits written
  # outside a signed-in request carry no user.
  def refunded_by(order)
    refund_audit = order.audits.reorder(version: :desc).detect do |audit|
      Array(audit.audited_changes['status']).last == Order::REFUNDED
    end
    refund_audit&.user&.username || 'an unrecorded user'
  end
end
