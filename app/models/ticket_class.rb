class TicketClass < ApplicationRecord
  include ActionView::Helpers::NumberHelper
  include ApplicationHelper
  TICKET_TYPES = ['Fixed', 'Donation', 'Timed']
  FIXED, DONATION, TIMED = 'Fixed', 'Donation', 'Timed'
  validates_inclusion_of :ticket_type,        :in => TICKET_TYPES, :message => "is not an allowed value (must be #{TICKET_TYPES.join(', ')})"
  validates_uniqueness_of :class_code,        :scope => :production_id
  validates_length_of :class_code,            :minimum => 1
  belongs_to :production, inverse_of: :ticket_classes
  has_many :ticket_line_items, inverse_of: :ticket_class
  has_many :ticket_class_allocations, inverse_of: :ticket_class, dependent: :destroy
  has_many :performances, through: :ticket_class_allocations, inverse_of: :ticket_classes
  
  before_validation :clean_values
  validates_numericality_of :ticket_price
  validates_numericality_of :minutes_before_show, :allow_nil => true
  validates_presence_of :ticket_price
  validates_presence_of :class_name
  validates_presence_of :ticketing_fee
  before_validation :prevent_price_changes_after_sales
  after_commit :sync_allocations_async, on: [:create, :update]
  before_destroy :check_for_processed_tickets
  before_destroy :check_for_shift_to_codes

  def number_left(performance, exclude_order=nil)
    ticket_class_capacity_left = production_capacity_left = performance.number_of_tickets_left

    ticket_allocation = performance.ticket_class_allocations.select{|tc| tc.ticket_class_id.eql? self.id}.first
    unless ticket_allocation.ticket_limit.nil? || ticket_allocation.ticket_limit.eql?(0)
      Rails.logger.debug("*** ticket limit = #{ticket_allocation.ticket_limit}\nnumber_take = #{number_taken(performance)}\nsum = #{self.ticket_line_items.sum(:ticket_count)}")
      ticket_class_capacity_left = ticket_allocation.ticket_limit - number_taken(performance)
    end
    return [ticket_class_capacity_left,production_capacity_left].min
  end

  def prevent_price_changes_after_sales
    unless self.ticket_type == DONATION
      if (self.ticket_price_was != self.ticket_price) && TicketLineItem.where(ticket_class_id:self.id).size > 0
        errors.add(:base,"Cannot change ticket price from #{self.ticket_price_was} to #{self.ticket_price} if sales have already occurred")
        return false
      end
    end
    return true;
  end

  def number_taken(performance, exclude_order = nil)
    if exclude_order.nil?
      TicketLineItem.where("ticket_class_id = :tc_id and exists (select * from orders where orders.id = order_id and performance_id = :performance_id)" , tc_id: self.id, performance_id: performance.id).sum(:ticket_count)
    else
      TicketLineItem.where('ticket_class_id = :tc_id and exists (select * from orders where orders.id = order_id and performance_id = :performance_id) and order_id != :order_id', tc_id: self.id, performance_id: performance.id, order_id: exclude_order.id).sum(:ticket_count)
    end
  end

  def royalty_price
    royalty_amount || (ticket_price - ticketing_fee)
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

  def destroy
    super if check_for_processed_tickets || check_for_shift_to_codes
  end

  def check_for_processed_tickets
    return true if self.ticket_line_items.count > 0
    self.errors.add(:deletion_status, 'Cannot delete a ticket class with processed orders')
    throw :abort
  end

  def check_for_shift_to_codes
    return true if TicketClassAllocation.joins(:performance).where("performances.production_id = :prod_id and shift_to_code = :shift_to", prod_id: self.production_id, shift_to: self.class_code).count > 0
    self.errors.add(:deletion_status, 'Cannot delete a ticket class that can be shifted to for dynamic pricing')
    throw :abort
  end

  private
  def sync_allocations_async
    return unless saved_change_to_auto_attach? || previously_new_record?
    production&.mark_allocation_sync_enqueued!
    Resque.enqueue(SyncTicketClassAllocationsJob, id)
  end

  private
  def clean_values
    self.class_code.upcase! if self.class_code
  end
end
