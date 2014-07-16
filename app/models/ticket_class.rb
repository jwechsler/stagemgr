class TicketClass < ActiveRecord::Base
  include ActionView::Helpers::NumberHelper
  include ApplicationHelper
  TICKET_TYPES = ['Fixed', 'Donation', 'Timed']
  FIXED, DONATION, TIMED = 'Fixed', 'Donation', 'Timed'
  validates_inclusion_of :ticket_type,        :in => TICKET_TYPES
  validates_uniqueness_of :class_code,        :scope => :production_id
  validates_length_of :class_code, :minimum => 1
  belongs_to :production
  has_many :ticket_line_items
  before_validation :clean_values
  validates_numericality_of :ticket_price
  validates_numericality_of :minutes_before_show, :allow_nil => true
  validates_presence_of :ticket_price
  validates_presence_of :ticketing_fee
  before_validation :prevent_price_changes_after_sales
  after_save :update_auto_attached_performances

  def number_left(performance, exclude_order=nil)
    ticket_class_capacity_left = production_capacity_left = performance.number_of_seats_left

    unless number_allocated(performance).nil?
      ticket_class_capacity_left = number_allocated(performance) - self.ticket_line_items.sum(:ticket_count)
    end
    return [ticket_class_capacity_left,production_capacity_left].min
  end

  def prevent_price_changes_after_sales
    unless self.ticket_type == DONATION
      if (self.ticket_price_was != self.ticket_price) ? && TicketLineItem.count(:conditions=>['ticket_class_id = ?',self.id]) > 0
        errors.add :base,"Cannot change ticket price from #{self.ticket_price_was} to #{self.ticket_price} if sales have already occurred"
        return false
      end
    end
    return true;
  end


  def number_taken(performance, exclude_order = nil)
    if exclude_order.nil?
      LineItem.sum(:ticket_count, :conditions=>{:ticket_class_id=>self.id,:performance_id=>performance.id})
    else
      LineItem.where('ticket_class_id = ? and performance_id = ? and order_id != ?',self.id, performance.id, order.id).sum(:ticket_count)
    end
  end

  def number_allocated(performance)
    sum = TicketClassAllocation.sum(:ticket_limit, :conditions=>{:ticket_class_id=>self.id,:performance_id=>performance.id})
    return nil if sum == 0
    sum
  end

  def to_s
    "#{self.class_name||self.class_code}"
  end

  def self.search_by_code_and_performance_id(code, performance_id )
    where("LOWER(class_code) LIKE ?",'%'+code.to_s.downcase + '%').
      where("id IN (SELECT ticket_class_id from ticket_class_allocations where performance_id = ? and available = 1)",  performance_id ).
      order("class_code ASC").
      limit(10)
  end

  private
  def update_auto_attached_performances
    self.production.performances.each {| perf|
      perf.populate_ticket_class_allocations
      perf.save! } if self.auto_attach?
  end

  private
  def clean_values
    self.class_code.upcase! if self.class_code
  end
end
