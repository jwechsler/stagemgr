# A general admission production's capacity may not drop below the seats
# already committed to any one of its performances. Reserved seating is out of
# scope: there capacity is the seat map's seat count, not an editable number.
#
# "Committed" means seats in held, processed or fulfilled orders
# (Order::CAPACITY_COMMITTED_STATUSES) in ticket classes that hold seats, so
# non-seat add-ons and streams never count. In-progress checkouts are left out
# on purpose: they either complete (and are checked against capacity then) or
# are abandoned.
module ProductionCapacityFloor
  extend ActiveSupport::Concern

  included do
    validate :capacity_covers_committed_seats, if: :general_admission_capacity_changing?
  end

  # The performance with the most committed seats and that count, or nil when
  # no performance has any.
  def peak_committed_seats
    counts = TicketLineItem.joins(:order, :ticket_class)
                           .where(ticket_classes: { holds_seats: true })
                           .where(orders: { status: Order::CAPACITY_COMMITTED_STATUSES,
                                            performance_id: performances.select(:id) })
                           .group('orders.performance_id')
                           .sum(:ticket_count)
    performance_id, seats = counts.max_by { |_id, count| count }
    performance_id && [Performance.find(performance_id), seats]
  end

  private

  # Checked when the manual capacity changes, or when removing the seat map
  # makes the manual capacity the one in force again.
  def general_admission_capacity_changing?
    persisted? && seat_map_id.nil? && (will_save_change_to_capacity? || will_save_change_to_seat_map_id?)
  end

  def capacity_covers_committed_seats
    requested = self[:capacity] # the manual number, not the seat map override
    return if requested.nil? # the numericality validation reports it

    performance, seats = peak_committed_seats
    return if performance.nil? || requested >= seats

    errors.add(:capacity, "can't be lower than #{seats}: #{performance.performance_code} already has " \
                          "#{seats} seats sold or held")
  end
end
