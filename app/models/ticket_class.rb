class TicketClass < ApplicationRecord
  include ActionView::Helpers::NumberHelper
  include ApplicationHelper
  include TextSanitizable
  include TicketAdmission

  TICKET_TYPES = %w[Fixed Donation Timed]
  FIXED = 'Fixed'
  DONATION = 'Donation'
  TIMED = 'Timed'
  validates :ticket_type, inclusion: { in: TICKET_TYPES,
                                       message: "is not an allowed value (must be #{TICKET_TYPES.join(', ')})" }
  validates :class_code, uniqueness: { scope: :production_id }
  validates :class_code, length: { minimum: 1 }
  belongs_to :production, inverse_of: :ticket_classes
  # Set on "shadow" rows materialized by a ResourcedTicketClass: a globally
  # managed class backed by a limited pool of physical devices. Shadow rows are
  # ordinary ticket classes in every other respect, but their attributes are
  # owned by the resource and only the sync path may change them.
  belongs_to :resourced_ticket_class, optional: true, inverse_of: :ticket_classes
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
  before_destroy :prevent_manual_destroy_of_resourced_class
  before_destroy :check_for_processed_tickets
  before_destroy :check_for_shift_to_codes
  after_commit :sync_allocations_async, on: %i[create update]

  # Set by SyncResourcedTicketClassJob / ResourcedTicketClass /
  # Production#assign_resourced_ticket_classes to mark a write as coming from
  # the resource itself. Everything else may only read a shadow row.
  attr_accessor :synced_from_resource

  validate :prevent_manual_changes_to_resourced_class

  def resourced?
    resourced_ticket_class_id.present?
  end

  # Zoned pricing: "*" (default) sells into any seat; a specific 1-2 char
  # zone only sells into seats whose Seat#zone matches. Zone is a filter on
  # top of the allocation/availability rules, never a replacement for them.
  validates :zone_id, presence: true,
                      format: { with: ZoneMatchable::CLASS_ZONE_FORMAT,
                                message: 'must be "*" or 1-2 characters A-Z or 0-9' }
  scope :for_zone, lambda { |seat_zone|
    where('zone_id = :wildcard OR zone_id = :zone',
          wildcard: ZoneMatchable::WILDCARD, zone: seat_zone)
  }

  def sellable_for_zone?(seat_zone)
    ZoneMatchable.match?(zone_id, seat_zone)
  end

  # exclude_order was historically ignored here (the allocation maths uses
  # number_taken without it). It is now forwarded to the resourced branch, which
  # needs it so an order being exchanged is not blocked by its own devices.
  # The non-resourced path below is unchanged.
  def number_left(performance, exclude_order = nil)
    return resourced_number_left(performance, exclude_order) if resourced?

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

  # Availability for a shadow row of a ResourcedTicketClass. The pool is always
  # a cap; the per-performance allocation ticket_limit still applies on top of
  # it (effective = min of the two, smaller wins).
  def resourced_number_left(performance, exclude_order)
    limits = [resourced_ticket_class.remaining_for(performance, exclude_order: exclude_order)]

    allocation = performance.ticket_class_allocations.select { |tca| tca.ticket_class_id.eql? id }.first
    ticket_limit = allocation&.ticket_limit
    limits << (ticket_limit - number_taken(performance)) unless ticket_limit.nil? || ticket_limit.eql?(0)

    # Devices are not seats. A captioning tablet has holds_seats == false and
    # consumes no house capacity, so the remaining-seats term must not cap it --
    # a sold-out house can still hand out tablets to exchanged patrons. A
    # resourced class that DOES hold seats keeps the normal capacity term.
    limits << performance.number_of_tickets_left if holds_seats?

    limits.min
  end

  # The single question every sale surface asks: may this class still be
  # offered for this performance? Non-resourced classes are always available as
  # far as the pool is concerned (their own allocation rules still apply).
  def resource_available?(performance, exclude_order = nil)
    !resourced? ||
      resourced_ticket_class.remaining_for(performance, exclude_order: exclude_order) > 0
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

  # Shadow rows are owned by their ResourcedTicketClass: price, name,
  # web_visible, auto_attach and the rest are pushed down by
  # SyncResourcedTicketClassJob. A no-op save is still allowed so unrelated
  # code paths that re-save a loaded record do not blow up.
  def prevent_manual_changes_to_resourced_class
    return unless resourced? && persisted? && changed? && !synced_from_resource

    errors.add(:base,
               "'#{class_code}' is managed globally by its resourced ticket class " \
               'and cannot be edited from the production.')
  end

  # Resourced rows are never deleted per-production. Removing the venue from the
  # resource (or deleting the resource) decommissions them instead --
  # ResourcedTicketClass.decommission_shadow_classes keeps the history and just
  # withdraws the class from sale.
  def prevent_manual_destroy_of_resourced_class
    return true unless resourced? && !synced_from_resource

    errors.add(:deletion_status,
               'Cannot delete a globally resourced ticket class here; ' \
               'remove the venue from the resource instead.')
    throw :abort
  end

  def sync_allocations_async
    return unless saved_change_to_auto_attach? || previously_new_record?

    production&.mark_allocation_sync_enqueued!
    # production_id lets the job release the pending counter even if this
    # ticket class is deleted before the job runs.
    Resque.enqueue(SyncTicketClassAllocationsJob, id, production_id)
  end

  def clean_values
    scrub_string_attributes
    class_code.upcase! if class_code
    self.zone_id = zone_id.to_s.strip.upcase.presence || ZoneMatchable::WILDCARD
  end
end
