# Delete inventory rows whose performance or production no longer exists.
#
# Follow-up to script/cleanup_orphaned_performances.rb. Performances and
# productions deleted before they had dependent destroys left behind:
#   - ticket class allocations, seat assignments and special-feature links on
#     performances that are gone;
#   - ticket orders on performances that are gone (only payment-free ones are
#     deleted);
#   - ticket classes of productions that are gone, with any allocations or
#     order-less line items still pointing at them.
#
# Line items with no order are otherwise left alone: they are still being
# created and need a code fix before a cleanup is worth running.
#
# The script refuses (and deletes nothing) if a seat assignment is sold or
# held, an order has payments or other records hanging off it, or a ticket
# class is on a line item that belongs to an order. Everything runs in one
# transaction.
#
# Usage: bundle exec rails runner script/cleanup_orphaned_inventory.rb
#        Add DRY_RUN=1 to preview changes without modifying data.

dry_run = ENV['DRY_RUN'] == '1'
puts dry_run ? '=== DRY RUN MODE ===' : '=== LIVE RUN ==='

performance_ids = Performance.unscoped.select(:id)
missing_performance = ->(scope) { scope.where.not(performance_id: performance_ids) }

allocations = missing_performance.call(TicketClassAllocation.unscoped)
seat_assignments = missing_performance.call(SeatAssignment.unscoped)
orders = missing_performance.call(Order.unscoped.where.not(performance_id: nil)).order(:id).to_a
feature_links = Arel::Table.new(:performances_special_features)
feature_link_scope = feature_links[:performance_id].not_in(performance_ids.arel)
ticket_class_ids = TicketClass.unscoped.where.not(production_id: Production.unscoped.select(:id)).pluck(:id)
ticket_class_allocations = TicketClassAllocation.unscoped.where(ticket_class_id: ticket_class_ids)
orderless_line_items = LineItem.unscoped.where(order_id: nil, ticket_class_id: ticket_class_ids)
feature_link_count = ActiveRecord::Base.connection.select_value(
  feature_links.project(Arel.star.count).where(feature_link_scope).to_sql
).to_i

puts "\nOn performances that no longer exist:"
puts "  ticket class allocations: #{allocations.count}"
puts "  seat assignments: #{seat_assignments.count}"
puts "  special-feature links: #{feature_link_count}"
puts "  orders: #{orders.size}"
orders.each do |order|
  puts "    Order #{order.id} #{order.type} #{order.status}, performance #{order.performance_id}, " \
       "created #{order.created_at.to_date.iso8601}, #{LineItem.where(order_id: order.id).count} line items"
end
puts "\nTicket classes of productions that no longer exist: #{ticket_class_ids.size}"
puts "  their allocations (any performance): #{ticket_class_allocations.count}"
puts "  order-less line items on them: #{orderless_line_items.count}"

problems = []
sold_seats = seat_assignments.where.not(order_id: nil).or(seat_assignments.where.not(order_uuid: nil)).count
problems << "#{sold_seats} seat assignments belong to an order" if sold_seats.positive?
orders.each do |order|
  problems << "Order #{order.id} has payments" if Payment.unscoped.exists?(order_id: order.id)
  problems << "Order #{order.id} has a pledge" if Pledge.exists?(order_id: order.id)
  if Order.where(exchange_source_id: order.id).or(Order.where(split_source_id: order.id)).exists?
    problems << "Order #{order.id} is the source of an exchange or split"
  end
  other_types = LineItem.where(order_id: order.id).distinct.pluck(:type) - %w[TicketLineItem]
  problems << "Order #{order.id} has #{other_types.join(', ')} line items" if other_types.any?
end
if LineItem.where(ticket_class_id: ticket_class_ids).where.not(order_id: nil).exists?
  problems << 'A ticket class of a missing production is on a line item that belongs to an order'
end
if SeatAssignment.exists?(ticket_class_id: ticket_class_ids)
  problems << 'A ticket class of a missing production is on a seat assignment'
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

# delete_all throughout: the parent rows are already gone, so the model
# callbacks have nothing valid to walk.
ActiveRecord::Base.transaction do
  orders.each do |order|
    line_items = LineItem.where(order_id: order.id).delete_all
    tasks = OrderTask.where(order_id: order.id).delete_all
    Order.unscoped.where(id: order.id).delete_all
    puts "Deleted order #{order.id} (#{line_items} line items, #{tasks} tasks)"
  end
  puts "Deleted #{allocations.delete_all} allocations on missing performances"
  puts "Deleted #{seat_assignments.delete_all} seat assignments on missing performances"
  deleted_links = ActiveRecord::Base.connection.delete(
    Arel::DeleteManager.new.from(feature_links).where(feature_link_scope)
  )
  puts "Deleted #{deleted_links} special-feature links on missing performances"
  puts "Deleted #{ticket_class_allocations.delete_all} allocations on ticket classes of missing productions"
  puts "Deleted #{orderless_line_items.delete_all} order-less line items on those ticket classes"
  puts "Deleted #{TicketClass.unscoped.where(id: ticket_class_ids).delete_all} ticket classes of missing productions"
end
