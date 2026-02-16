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
  end
end
