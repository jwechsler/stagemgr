class PerformanceBroadcast < ApplicationRecord
  belongs_to :performance
  belongs_to :user

  validates :subject, :from_address, :body, presence: true

  # Returns the orders that are eligible to receive this broadcast
  # Eligible orders:
  # - Status: Hold, Processed, Processing, or Fulfilled
  # - Have a non-placeholder address with a valid email
  def recipient_orders
    performance.orders
      .joins(:address)
      .where(status: ['Hold', 'Processed', 'Processing', 'Fulfilled'])
      .where.not(addresses: { placeholder: true })
      .where.not(addresses: { email: [nil, ''] })
      .where("addresses.email LIKE '%@%'")
      .distinct
  end

  # Queues individual OutreachTask jobs for each recipient order
  def queue_broadcast!
    orders = recipient_orders.to_a
    update!(
      recipient_count: orders.size,
      sent_at: Time.current
    )

    orders.each do |order|
      OutreachTask.create!(
        execute_at: Time.now,
        order: order,
        method_symbol: 'custom_performance_broadcast'
      )
    end

    # Generate and send log to box office users and administrators
    generate_and_send_log
  end

  # Generates CSV log and sends to all box office users and administrators
  def generate_and_send_log
    report = PerformanceBroadcastReport.new(self)
    file_store = report.create

    # Get all active box office users and administrators
    recipients = User.where(status: User::ACTIVE)
                     .where("is_box_office_user = ? OR is_administrator = ?", true, true)

    recipients.each do |user|
      next if user.email.blank?

      begin
        NotificationMailer.broadcast_log_generated(file_store, user.email).deliver_now
      rescue => e
        Rails.logger.error("Failed to send broadcast log to #{user.email}: #{e.message}")
      end
    end

    Rails.logger.info("Broadcast log sent to #{recipients.count} recipients (box office users and administrators)")
  end
end
