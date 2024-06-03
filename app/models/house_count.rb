# app/models/house_count.rb
class HouseCount < Metric

  belongs_to :performance

  # Method to calculate and update the seat counts
  def calculate
    unless performance.production.nil?
      self.total_seats = performance.production&.capacity
      self.sold_seats = calculate_sold_seats
      self.available_seats = performance.production&.capacity - performance.seats_held
    end
  end

  def calculate!
    self.calculate
    self.save!
  end

  # Required by Metric abstract class
  def self.export_columns
    ['performance_code', 'total_seats', 'sold_seats', 'available_seats']
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

end
