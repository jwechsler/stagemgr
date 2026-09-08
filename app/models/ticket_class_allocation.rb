# The meaning of "available" here: this model has an `available` boolean DB column
# that acts as a dynamic-pricing on/off switch -- when true, this ticket class is
# offered for sale at this performance; the shift logic (see #trigger_satisfied?)
# flips it as price tiers promote/demote. It is NOT a seat count and is unrelated
# to Performance#seats_available / HouseCount#available_seats (aggregate seat
# availability) or to SeatAssignment#available? (per-seat status).
class TicketClassAllocation < ApplicationRecord
  belongs_to :performance, inverse_of: :ticket_class_allocations
  belongs_to :ticket_class, inverse_of: :ticket_class_allocations
  default_scope { includes(:ticket_class) }

  # Form-only flag from the performance edit page's allocation grid: when set,
  # saving the performance also applies this row (available or not, plus its
  # limit and trigger settings) to the same ticket class on every later
  # performance of the run, resetting any dynamic pricing shift already made
  # there and re-running the triggers -- see
  # Performance#propagate_requested_allocation_availability. Never persisted.
  attr_accessor :propagate_available

  def propagate_available?
    ActiveModel::Type::Boolean.new.cast(propagate_available) || false
  end
  validates :ticket_limit, numericality: { allow_nil: true }
  validates :shift_days_before_performance, numericality: { allow_nil: true }
  validates :shift_when_capacity_over, numericality: { allow_nil: true }
  validates :shift_to_code, presence: { if: :shiftable? }
  validates :shift_days_before_performance, presence: { if: proc { |tca|
    tca.shiftable? && tca.shift_when_capacity_over.nil?
  } }
  validates :shift_when_capacity_over, presence: { if: proc { |tca|
    tca.shiftable? && tca.shift_days_before_performance.nil?
  } }

  def trigger_satisfied?(seats_currently_held = nil)
    shiftable? && (trigger_satisfied_by_capacity?(seats_currently_held) || trigger_satisifed_by_current_date?) && !shift_to_code.eql?(ticket_class.class_code)
  end

  # Date.current (the Rails zone), not Date.today (the host's zone): this now
  # runs on every admin save, and a UTC host would otherwise judge "N days
  # before" a day early each evening.
  def trigger_satisifed_by_current_date?
    return false if shift_days_before_performance.nil?

    Date.current + shift_days_before_performance.days >= performance.performance_date
  end

  # Percent of capacity, inclusive, in integer arithmetic: 29 of 100 seats at
  # a 29% threshold must fire, and 29.0 / 100 * 100.0 is 28.999... in floats.
  # A missing or zero capacity (a seat map with no seats yet) never fires
  # rather than dividing by zero.
  def trigger_satisfied_by_capacity?(seats_currently_held)
    return false if shift_when_capacity_over.nil?

    capacity = performance.production.capacity
    return false if capacity.nil? || capacity <= 0

    seats_currently_held = performance.seats_held if seats_currently_held.nil?
    seats_currently_held.to_i * 100 >= shift_when_capacity_over * capacity
  end
end
