# app/models/house_count.rb
class HouseCount < Metric

  belongs_to :performance

  # Method to calculate and update the seat counts
  def calculate
    unless performance.production.nil?
      self.total_seats = performance.production&.capacity
      self.sold_seats = calculate_sold_seats
      self.held_seats = calculate_held_seats
      self.available_seats = performance.production&.capacity - performance.seats_held
      self.max_ticket_price = calculate_max_ticket_price
    end
  end

  def calculate!
    self.calculate
    self.save!
  end

  # Required by Metric abstract class
  def self.export_columns
    ['performance_code', 'total_seats', 'sold_seats', 'held_seats', 'available_seats', 'max_ticket_price']
  end

  # Required by Metric abstract class
  def self.export_records
    HouseCount.joins(:performance).merge(Performance.sellable)
                        .where(performances: { performance_date: Date.today..(Date.today + 14.days) }).order('performance_date, performance_code')
  
  end

  # Public accessor for performance code
  def performance_code
    self.performance.performance_code
  end

  private

  # Helper method to calculate sold seats based on the TicketOrder#sold? method
  def calculate_sold_seats
    sold_tickets = performance.orders.includes(:ticket_line_items).select(&:sold?).sum do |order|
      order.ticket_line_items.sum(:ticket_count)
    end
    sold_tickets
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
    performance.ticket_class_allocations
      .select { |tca| tca.available? && tca.ticket_class.web_visible? && tca.ticket_class.show_in_pricing_range? }
      .map { |tca| tca.ticket_class.ticket_price }
      .max
  end

end
