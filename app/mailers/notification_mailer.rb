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

  # Sent by ChargeAfterChecks#send_additional_donation_failed_alert. Each
  # failure is { amount:, theater:, reason: }; no card data is kept.
  def additional_donation_failed_alert(order, recipient, failures)
    @order = order
    @failures = failures
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

  # Sent by ExpireOneTimeMembershipsJob when memberships past expires_on could
  # not be expired. Each failure is { id:, member_code:, expires_on:, error: }.
  def membership_expiry_failed_alert(failures, recipient)
    @failures = failures
    mail(to: recipient,
         from: Rails.configuration.x.email_address['software_address'],
         subject: "#{failures.size} #{'membership'.pluralize(failures.size)} could not be expired",
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

  # Sent by LglDonorImport every time an import finishes. counts is the job's
  # outcome tally; result_file is the FileStore listing the rows with errors,
  # or nil when no row had one.
  def donor_levels_imported(filestore, counts, result_file = nil)
    @filestore = filestore
    @counts = Hash.new(0).merge(counts)
    @error_count = LglDonorImport.error_count(@counts)
    @result_file = result_file
    if result_file
      attachments[result_file.file_name] = {
        mime_type: result_file.datafile.content_type,
        content: result_file.datafile.download
      }
    end
    mail(to: filestore.user.email,
         from: Rails.configuration.x.email_address['software_address'],
         subject: 'Donor levels import complete',
         tag: 'Donor Levels Import')
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
