# Delete performances whose production no longer exists, together with the
# ticket orders placed against them.
#
# A production deleted before Production had dependent destroys left its
# performances (and their ticket class allocations) behind. Two of those
# performances carry 2020 membership orders that were refunded to a zero
# balance; their payment rows go with them.
#
# The script refuses to delete an order that still carries money, is the source
# of an exchange or split, has a payment another payment points at, or holds a
# line item other than tickets and service fees (a MembershipLineItem destroy
# would cancel the member's membership). Everything runs in one transaction.
#
# Usage: bundle exec rails runner script/cleanup_orphaned_performances.rb
#        Add DRY_RUN=1 to preview changes without modifying data.

DELETABLE_LINE_ITEM_TYPES = %w[TicketLineItem ServiceLineItem AdjustmentLineItem].freeze

dry_run = ENV['DRY_RUN'] == '1'
puts dry_run ? '=== DRY RUN MODE ===' : '=== LIVE RUN ==='

performance_ids = Performance.unscoped.where.missing(:production).order(:id).pluck(:id)
if performance_ids.empty?
  puts "\nNo performances without a production. Nothing to do."
  exit
end

production_ids = Performance.unscoped.where(id: performance_ids).distinct.pluck(:production_id)
puts "\n#{performance_ids.size} performances belong to missing productions #{production_ids.sort.join(', ')}"
puts "  ticket class allocations: #{TicketClassAllocation.where(performance_id: performance_ids).count}"

orders = Order.where(performance_id: performance_ids).order(:id).to_a
puts "\n#{orders.size} orders on those performances:"

problems = []
orders.each do |order|
  payments = Payment.unscoped.where(order_id: order.id).order(:id).to_a
  line_items = LineItem.where(order_id: order.id).to_a
  balance = payments.sum(&:amount)
  puts "  Order #{order.id} #{order.type} #{order.status}, performance #{order.performance_id}, " \
       "updated #{order.updated_at.to_date.iso8601}, balance #{balance.to_s('F')}"
  payments.each do |payment|
    puts "    payment #{payment.id} #{payment.type} #{payment.amount.to_s('F')} on #{payment.processed_on&.to_date&.iso8601}"
  end

  problems << "Order #{order.id} has a non-zero balance (#{balance.to_s('F')})" unless balance.zero?
  if Order.where(exchange_source_id: order.id).or(Order.where(split_source_id: order.id)).exists?
    problems << "Order #{order.id} is the source of an exchange or split"
  end
  if Payment.unscoped.exists?(payment_id: payments.map(&:id))
    problems << "Order #{order.id} has a payment referenced by another payment"
  end
  problems << "Order #{order.id} has a pledge" if Pledge.exists?(order_id: order.id)
  other_types = line_items.map(&:type).uniq - DELETABLE_LINE_ITEM_TYPES
  problems << "Order #{order.id} has #{other_types.join(', ')} line items" if other_types.any?
end

if problems.any?
  puts "\nRefusing to delete anything:"
  problems.each { |problem| puts "  #{problem}" }
  exit 1
end

if dry_run
  puts "\nDry run: nothing deleted."
  exit
end

ActiveRecord::Base.transaction do
  # delete_all rather than destroy: Order#destroy leaves payments and line items
  # behind (no dependent option), and TicketOrder's SeatRelease callback would
  # walk a performance whose production is gone.
  orders.each do |order|
    payments = Payment.unscoped.where(order_id: order.id).delete_all
    line_items = LineItem.where(order_id: order.id).delete_all
    tasks = OrderTask.where(order_id: order.id).delete_all
    seats = SeatAssignment.where(order_uuid: order.uuid).update_all(order_uuid: nil, order_id: nil)
    Order.where(id: order.id).delete_all
    puts "Deleted order #{order.id} (#{payments} payments, #{line_items} line items, " \
         "#{tasks} tasks; released #{seats} seats)"
  end

  Performance.where(id: performance_ids).find_each do |performance|
    performance.destroy || raise("Performance #{performance.id}: #{performance.errors.full_messages.to_sentence}")
  end
  puts "Deleted #{performance_ids.size} performances and their ticket class allocations"
end

remaining = Performance.unscoped.where.missing(:production).count
puts "\nPerformances without a production remaining: #{remaining}"
