# Sends a TicketOrder's patron confirmation again, now: from the admin
# Resend Confirmation button and after Add to Order (TicketOrderAddition).
module TicketConfirmationResendable
  extend ActiveSupport::Concern

  # Reuses the order's existing confirmation task when there is one, so the
  # order keeps a single ticket_confirmation task row.
  def resend_confirmation!
    confirmation_task = tasks.find { |t| t.method_symbol == 'ticket_confirmation' }
    confirmation_task ||= OutreachTask.create!(execute_at: Time.current, method_symbol: :ticket_confirmation,
                                               order: self)
    confirmation_task.retry.run!
  end
end
