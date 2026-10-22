# app/models/house_count.rb
class HouseCount < Metric
  belongs_to :performance

  # Method to calculate and update the seat counts
  def calculate
    return if performance.production.nil?

    self.total_seats = performance.production.capacity
    self.sold_seats = calculate_sold_seats
    self.held_seats = calculate_held_seats
    self.comp_seats = calculate_comp_seats
    # available = capacity minus every seat currently occupied (sold + on hold +
    # in-progress + exchanging + releasing). performance.seats_occupied is the
    # preferred alias of the original #seats_held and returns the same figure.
    self.available_seats = performance.production.capacity - performance.seats_occupied
    self.max_ticket_price = calculate_max_ticket_price
    self.min_ticket_price = calculate_min_ticket_price
    self.sold_out = calculate_sold_out
    self.near_capacity = calculate_near_capacity
    apply_pace(AdvanceSalesPace.for_performance(performance), as_of: Date.current)
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

  # Sales pace snapshot. projected_seats, pace_share, pace_sold, pace_source
  # and pace_as_of come from AdvanceSalesPace and are written in two places:
  # by #calculate on every sales-driven recalculation (for_performance, so the
  # projection follows sales intraday), and by ProjectHouseCountsJob nightly
  # for every upcoming performance, so days_out keeps moving on performances
  # with no order activity. They describe the performance as of pace_as_of.
  def apply_pace(reading, as_of:)
    self.projected_seats = reading&.projected_final
    self.pace_share = reading&.typical_share
    self.pace_sold = reading&.sold
    self.pace_source = reading&.source&.to_s
    self.pace_as_of = as_of
  end

  # The typical share in hand was under the projectable minimum.
  def pace_too_early?
    pace_share.present? && projected_seats.nil?
  end

  # The seats that can still end up sold: the house less its holds. Holds
  # convert into processed orders, so the projection already counts them, and
  # Sold can never reach total_seats while seats are held. Nil when the house
  # size is unknown.
  def sellable_seats
    total_seats.nil? ? nil : total_seats - held_seats.to_i
  end

  # Expected on the house counts is about seats filled, not revenue. The
  # projection AdvanceSalesPace writes to projected_seats is paid-only (comps
  # are left out of the advance-sales curve on purpose), but Sold counts comps,
  # so Expected adds the comps already issued to share Sold's basis. This is
  # the raw demand, which can run past the house on a hot show. Nil without a
  # projection.
  def expected_demand
    return nil if projected_seats.nil?

    projected_seats + comp_seats.to_i
  end

  # Nobody can be expected beyond the sellable seats, so everything shown to
  # staff reads this capped figure rather than the raw demand.
  def capped_expected_seats
    return nil if expected_demand.nil?

    projection_capped? ? sellable_seats : expected_demand
  end

  def projection_capped?
    expected_demand.present? && sellable_seats.present? && expected_demand > sellable_seats
  end

  # Sold has gone past the expected demand (strictly greater), or a capped
  # projection has been reached: with every sellable seat sold there is
  # nothing left to anticipate, and sold cannot pass them.
  def expected_met?
    return false if expected_demand.nil?

    sold = sold_seats.to_i
    projection_capped? ? sold >= sellable_seats : sold > expected_demand
  end

  # The Sold column has already passed the expectation, nothing more to anticipate.
  def expected_seats
    expected_met? ? nil : capped_expected_seats
  end

  # Expected as a whole percentage of production capacity (total_seats, not
  # the sellable seats), e.g. 67 for 70 of 104 seats; a capped projection reads
  # under 100 while seats are held. Nil when nothing is expected or the house
  # size is unknown.
  def expected_pct
    return nil if expected_seats.nil? || total_seats.to_i.zero?

    (expected_seats * 100.0 / total_seats).round
  end

  def pace_days_out
    return nil if pace_as_of.nil?

    (performance.performance_date - pace_as_of).to_i
  end

  # Required by Metric abstract class
  def self.export_columns
    %w[performance_code total_seats sold_seats held_seats available_seats max_ticket_price]
  end

  # Required by Metric abstract class
  def self.export_records
    HouseCount.joins(:performance).merge(Performance.sellable)
              .where(performances: { performance_date: Date.current..(Date.current + 14.days) }).order('performance_date, performance_code')
  end

  # Public accessor for performance code
  delegate :performance_code, to: :performance

  private

  # Seats on sold orders (TicketOrder#sold?). Only classes that hold a seat
  # count, matching calculate_held_seats: an add-on such as a captioning tablet
  # is a line item but occupies no seat in the house.
  def calculate_sold_seats
    performance.orders.includes(:ticket_line_items).select(&:sold?).sum do |order|
      order.ticket_line_items.joins(:ticket_class).where(ticket_classes: { holds_seats: true }).sum(:ticket_count)
    end
  end

  # The comps among the sold seats: seat-holding complimentary classes on sold
  # orders, the same orders calculate_sold_seats counts. Sold already includes
  # them; this sub-count only feeds Expected (see #expected_demand).
  def calculate_comp_seats
    performance.orders.includes(:ticket_line_items).select(&:sold?).sum do |order|
      order.ticket_line_items.joins(:ticket_class)
           .where(ticket_classes: { holds_seats: true, complimentary: true }).sum(:ticket_count)
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

  # Mirrors Performance#sold_out?: zero available seats means sold out. See the
  # comment there for why non-seat-holding allocations no longer factor in.
  def calculate_sold_out
    available_seats <= 0
  end

  def calculate_near_capacity
    available_seats <= Rails.configuration.x.server_config['restrict_sales_due_to_capacity_at'].to_i
  end

  def visible_priced_allocations
    performance.ticket_class_allocations
               .select { |tca| tca.available? && tca.ticket_class.web_visible? && tca.ticket_class.show_in_pricing_range? }
  end
end
