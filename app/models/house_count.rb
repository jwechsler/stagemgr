# app/models/house_count.rb
class HouseCount < Metric
  belongs_to :performance

  # Method to calculate and update the seat counts
  def calculate
    return if performance.production.nil?

    self.total_seats = performance.production.capacity
    self.sold_seats = calculate_sold_seats
    self.held_seats = calculate_held_seats
    # available = capacity minus every seat currently occupied (sold + on hold +
    # in-progress + exchanging + releasing). performance.seats_occupied is the
    # preferred alias of the original #seats_held and returns the same figure.
    self.available_seats = performance.production.capacity - performance.seats_occupied
    self.max_ticket_price = calculate_max_ticket_price
    self.min_ticket_price = calculate_min_ticket_price
    self.sold_out = calculate_sold_out
    self.near_capacity = calculate_near_capacity
  end

  def calculate!
    calculate
    save!
  end

  # Seat-inventory vocabulary facades (preferred reader names).
  #
  # HouseCount stores a CACHED snapshot of a performance's seat inventory. The
  # underlying columns (total_seats, sold_seats, held_seats, available_seats)
  # are written by #calculate and only refreshed when CalculateHouseCountsJob
  # runs (every 5 minutes), so these readers can lag the live figures on
  # Performance. The names below describe each column in the shared seat
  # vocabulary; they read the existing columns unchanged.
  #
  #   seats_on_hold   -> held_seats      (box-office HOLD orders only)
  #   seats_sold      -> sold_seats      (settled / paid orders)
  #   seats_available -> available_seats (capacity minus all occupied seats)
  #   seats_total     -> total_seats     (production capacity at snapshot time)
  def seats_on_hold
    held_seats
  end

  def seats_sold
    sold_seats
  end

  def seats_available
    available_seats
  end

  def seats_total
    total_seats
  end

  # Required by Metric abstract class
  def self.export_columns
    %w[performance_code total_seats sold_seats held_seats available_seats max_ticket_price]
  end

  # Required by Metric abstract class
  def self.export_records
    HouseCount.joins(:performance).merge(Performance.sellable)
              .where(performances: { performance_date: Date.today..(Date.today + 14.days) }).order('performance_date, performance_code')
  end

  # Public accessor for performance code
  delegate :performance_code, to: :performance

  private

  # Helper method to calculate sold seats based on the TicketOrder#sold? method
  def calculate_sold_seats
    performance.orders.includes(:ticket_line_items).select(&:sold?).sum do |order|
      order.ticket_line_items.sum(:ticket_count)
    end
  end

  # Count ticket_count from TicketLineItem joined to orders in Hold status
  # where ticket_class.holds_seats = true, for this performance
  def calculate_held_seats
    TicketLineItem.where(
      'ticket_classes.holds_seats = ? and orders.status in (?) and orders.performance_id = ?',
      true,
      Order::HELD_STATUSES,
      performance.id
    ).includes(:order, :ticket_class).sum(:ticket_count)
  end

  # Find the maximum ticket_price from ticket_classes for this performance where
  # the allocation is available, ticket_class is web_visible, and show_in_pricing_range
  def calculate_max_ticket_price
    visible_priced_allocations.map { |tca| tca.ticket_class.ticket_price }.max
  end

  def calculate_min_ticket_price
    visible_priced_allocations.map { |tca| tca.ticket_class.ticket_price }.min
  end

  # Mirrors Performance#sold_out? logic: no seats left AND no available
  # web-visible non-seat-holding ticket classes
  def calculate_sold_out
    available_seats <= 0 &&
      performance.ticket_class_allocations
                 .none? { |tca| tca.available? && tca.ticket_class.web_visible? && !tca.ticket_class.holds_seats? }
  end

  def calculate_near_capacity
    available_seats <= $SERVER_CONFIG['restrict_sales_due_to_capacity_at'].to_i
  end

  def visible_priced_allocations
    performance.ticket_class_allocations
               .select { |tca| tca.available? && tca.ticket_class.web_visible? && tca.ticket_class.show_in_pricing_range? }
  end
end
