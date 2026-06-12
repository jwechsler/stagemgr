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

  # Generates CSV log and sends to the broadcast requester
  def generate_and_send_log
    report = PerformanceBroadcastReport.new(self)
    file_store = report.create

    # Send log only to the user who requested the broadcast
    if user.email.present?
      begin
        NotificationMailer.broadcast_log_generated(file_store, user.email).deliver_now
        Rails.logger.info("Broadcast log sent to #{user.email}")
      rescue => e
        Rails.logger.error("Failed to send broadcast log to #{user.email}: #{e.message}")
      end
    end
  end
end
