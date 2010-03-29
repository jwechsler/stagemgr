class TicketClass < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper
  include ApplicationHelper
  TICKET_TYPES = ['Fixed', 'Donation', 'Timed']
  validates_inclusion_of :ticket_type,        :in => TICKET_TYPES
  validates_uniqueness_of :class_code
  validates_length_of :class_code, :in=>1..4
  belongs_to :production
  has_many :line_items
  before_validation :clean_values
  validates_numericality_of :ticket_price
  validates_numericality_of :minutes_before_show, :allow_nil => true
  validates_each :minutes_before_show do |record, attr, value|
    record.errors.add attr, 'must be less than production capacity' if !value.nil? && value >= self.production.capacity
  end
  
  def number_left(performance)
    ticket_class_capacity_left = production_capacity_left = performance.number_of_tickets_left
    
    unless number_allocated(performance).nil?
      ticket_class_capacity_left = number_allocated(performance) - self.line_items.sum(:ticket_count)
    end
    return [ticket_class_capacity_left,production_capacity_left].min
  end
  
  def number_taken(performance)
    LineItem.sum(:ticket_count, :conditions=>{:ticket_class_id=>self.id,:performance_id=>performance.id})
  end
  
  def number_allocated(performance)
    sum = TicketClassAllocation.sum(:ticket_limit, :conditions=>{:ticket_class_id=>self.id,:performance_id=>performance.id})
    return nil if sum == 0
    sum
  end
  
  def to_s
    "#{self.class_name||self.class_code}-#{self.ticket_type} #{to_currency  self.ticket_price}"
  end
  
  private 
  def clean_values
    self.class_code.upcase! if self.class_code
  end
end
