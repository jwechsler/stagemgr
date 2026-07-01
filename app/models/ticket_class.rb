class TicketClass < ApplicationRecord
  include ActionView::Helpers::NumberHelper
  include ApplicationHelper

  TICKET_TYPES = %w[Fixed Donation Timed]
  FIXED = 'Fixed'
  DONATION = 'Donation'
  TIMED = 'Timed'
  validates :ticket_type, inclusion: { in: TICKET_TYPES,
                                       message: "is not an allowed value (must be #{TICKET_TYPES.join(', ')})" }
  validates :class_code, uniqueness: { scope: :production_id }
  validates :class_code, length: { minimum: 1 }
  belongs_to :production, inverse_of: :ticket_classes
  has_many :ticket_line_items, inverse_of: :ticket_class
  has_many :ticket_class_allocations, inverse_of: :ticket_class, dependent: :destroy
  has_many :performances, through: :ticket_class_allocations, inverse_of: :ticket_classes

  before_validation :clean_values
  validates :ticket_price, numericality: true
  validates :minutes_before_show, numericality: { allow_nil: true }
  validates :ticket_price, presence: true
  validates :class_name, presence: true
  validates :ticketing_fee, presence: true
  before_validation :prevent_price_changes_after_sales
  before_destroy :check_for_processed_tickets
  before_destroy :check_for_shift_to_codes
  after_commit :sync_allocations_async, on: %i[create update]

  def number_left(performance, _exclude_order = nil)
    ticket_class_capacity_left = production_capacity_left = performance.number_of_tickets_left

    ticket_allocation = performance.ticket_class_allocations.select { |tc| tc.ticket_class_id.eql? id }.first
    unless ticket_allocation.ticket_limit.nil? || ticket_allocation.ticket_limit.eql?(0)
      Rails.logger.debug do
        "*** ticket limit = #{ticket_allocation.ticket_limit}\nnumber_take = #{number_taken(performance)}\nsum = #{ticket_line_items.sum(:ticket_count)}"
      end
      ticket_class_capacity_left = ticket_allocation.ticket_limit - number_taken(performance)
    end
    [ticket_class_capacity_left, production_capacity_left].min
  end

  def prevent_price_changes_after_sales
    if ticket_type != DONATION && (ticket_price_was != ticket_price) && !TicketLineItem.where(ticket_class_id: id).empty?
      errors.add(:base,
                 "Cannot change ticket price from #{ticket_price_was} to #{ticket_price} if sales have already occurred")
      return false
    end
    true
  end

  def number_taken(performance, exclude_order = nil)
    if exclude_order.nil?
      TicketLineItem.where(
        'ticket_class_id = :tc_id and exists (select * from orders where orders.id = order_id and performance_id = :performance_id)', tc_id: id, performance_id: performance.id
      ).sum(:ticket_count)
    else
      TicketLineItem.where(
        'ticket_class_id = :tc_id and exists (select * from orders where orders.id = order_id and performance_id = :performance_id) and order_id != :order_id', tc_id: id, performance_id: performance.id, order_id: exclude_order.id
      ).sum(:ticket_count)
    end
  end

  def royalty_price
    royalty_amount || (ticket_price - ticketing_fee)
  end

  def to_s
    (class_name || class_code).to_s
  end

  def self.search_by_code_and_performance_id(code, performance_id)
    where('LOWER(class_code) LIKE ?', '%' + code.to_s.downcase + '%')
      .where('id IN (SELECT ticket_class_id from ticket_class_allocations where performance_id = ? and available = 1)', performance_id)
      .order('class_code ASC')
      .limit(10)
  end

  def destroy
    super if check_for_processed_tickets || check_for_shift_to_codes
  end

  def check_for_processed_tickets
    return true if ticket_line_items.count > 0

    errors.add(:deletion_status, 'Cannot delete a ticket class with processed orders')
    throw :abort
  end

  def check_for_shift_to_codes
    return true if TicketClassAllocation.joins(:performance).where(
      'performances.production_id = :prod_id and shift_to_code = :shift_to', prod_id: production_id, shift_to: class_code
    ).count > 0

    errors.add(:deletion_status, 'Cannot delete a ticket class that can be shifted to for dynamic pricing')
    throw :abort
  end

  private

  def sync_allocations_async
    return unless saved_change_to_auto_attach? || previously_new_record?

    production&.mark_allocation_sync_enqueued!
    Resque.enqueue(SyncTicketClassAllocationsJob, id)
  end

  def clean_values
    class_code.upcase! if class_code
  end
end
