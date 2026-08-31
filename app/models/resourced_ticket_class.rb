# A ResourcedTicketClass is a globally managed ticket class backed by a limited
# pool of physical devices (assistive closed-captioning tablets,
# audio-description receivers) shared across venues. Unlike DefaultTicketClass
# it is NOT a template: it is a persistent global object that owns its shadow
# rows for as long as it exists.
#
# Materialization ("shadow rows"): the resource creates one real TicketClass per
# production in its venues, with `ticket_classes.resourced_ticket_class_id`
# pointing back here and the ticket-class attributes copied from this record
# (see #shadow_attributes). Every existing mechanism -- allocation creation via
# Performance#populate_ticket_class_allocations and
# TicketClass#sync_allocations_async, auto_attach, line items, order flow,
# reports -- then works unchanged.
#
# Pool accounting: 1 ticket == 1 device. A device is busy for the whole
# occupancy window of the performance it was sold into:
#
#   [curtain - changeover_minutes, curtain + running_time + changeover_minutes]
#
# so a device sold into a 2pm show in venue A is unavailable to an overlapping
# 3pm show in venue B. #remaining_for computes the pool left for a candidate
# performance by summing live-order tickets across every performance in the
# resource's venues whose window overlaps the candidate's.
class ResourcedTicketClass < ApplicationRecord
  # Upper bound on changeover_minutes. Keeps the +/- 1 day performance_date
  # prefilter in #remaining_for valid: with a changeover under 12 hours the
  # occupancy window can never reach a performance more than one calendar day
  # away from the candidate (running times are hours, not days).
  MAX_CHANGEOVER_MINUTES = 720

  # Used when productions.running_time is blank and no server.yml key is set.
  FALLBACK_RUNTIME_MINUTES = 180

  # Pairwise window-overlap predicate, evaluated per candidate performance.
  # Strict < / > so exactly-abutting windows are compatible: a device returned
  # at 4:30pm can be prepped for a performance whose window opens at 4:30pm.
  OVERLAP_SQL = <<~SQL.squish.freeze
    TIMESTAMP(performances.performance_date, performances.performance_time)
      - INTERVAL :changeover MINUTE < :window_end
    AND TIMESTAMP(performances.performance_date, performances.performance_time)
      + INTERVAL (COALESCE(productions.running_time, :runtime) + :changeover) MINUTE > :window_start
  SQL

  # A plain join with no attributes of its own, consistent with the other
  # venue/feature joins in this app (Production, Performance, Theater).
  # rubocop:disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :venues
  # rubocop:enable Rails/HasAndBelongsToMany
  # The materialized per-production TicketClass rows owned by this resource.
  has_many :ticket_classes, inverse_of: :resourced_ticket_class

  before_validation :clean_values
  before_validation :prevent_price_changes_after_sales

  validates :class_code, presence: true, uniqueness: true
  validates :class_name, presence: true
  validates :ticket_price, presence: true, numericality: true
  validates :ticketing_fee, presence: true, numericality: true
  validates :minutes_before_show, numericality: { allow_nil: true }
  validates :ticket_type, inclusion: { in: TicketClass::TICKET_TYPES,
                                       message: "is not an allowed value (must be #{TicketClass::TICKET_TYPES.join(', ')})" }
  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :changeover_minutes,
            numericality: { only_integer: true, greater_than_or_equal_to: 0,
                            less_than: MAX_CHANGEOVER_MINUTES }

  # Zoned pricing: same rule as TicketClass#zone_id -- "*" sells into any seat
  # zone, a 1-2 char zone only into matching seats. Copied verbatim onto every
  # shadow TicketClass.
  validates :zone_id, presence: true,
                      format: { with: ZoneMatchable::CLASS_ZONE_FORMAT,
                                message: 'must be "*" or 1-2 characters A-Z or 0-9' }

  validate :must_have_at_least_one_venue

  before_destroy :destroy_unsold_shadow_classes
  after_commit :sync_shadow_classes_async, on: %i[create update]

  def to_s
    (class_name || class_code).to_s
  end

  # Deleting a resource must never delete sold history. When any shadow row has
  # line items the resource is withdrawn from sale instead and the delete is
  # refused.
  #
  # The check lives here rather than in a before_destroy callback on purpose:
  # `throw :abort` from a callback rolls the whole destroy transaction back,
  # which would undo the decommission we just performed. Mirrors the existing
  # TicketClass#destroy override.
  # rubocop:disable Rails/ActiveRecordOverride
  def destroy
    sold = shadow_classes_with_sales
    if sold.any?
      decommission!
      errors.add(:base,
                 "Cannot delete '#{class_code}': #{sold.size} production#{'s' if sold.size > 1} " \
                 'already sold this equipment. The ticket class has been withdrawn from sale ' \
                 '(hidden and un-attached) instead, and historical orders are preserved.')
      return false
    end

    super
  end
  # rubocop:enable Rails/ActiveRecordOverride

  # Withdraw every shadow row of this resource from sale, keeping the history.
  # Used by the delete path and available to the admin UI as an explicit action.
  def decommission!
    self.class.decommission_shadow_classes(ticket_classes.reload)
  end

  def shadow_classes_with_sales
    ticket_classes.reload.select { |tc| TicketLineItem.where(ticket_class_id: tc.id).any? }
  end

  # Attributes copied onto every shadow TicketClass. Same shape as
  # DefaultTicketClass#to_hash: everything except the identity, the timestamps
  # and the two pool-only attributes, which have no TicketClass counterpart.
  def shadow_attributes
    h = attributes
    h.delete('id')
    h.delete('quantity')
    h.delete('changeover_minutes')
    h.delete('created_at')
    h.delete('updated_at')
    h
  end

  # Assumed running time when a production leaves running_time blank.
  def default_runtime_minutes
    configured = Rails.configuration.x.server_config['resourced_default_runtime_minutes']
    configured.nil? ? FALLBACK_RUNTIME_MINUTES : configured.to_i
  end

  # [start, end] of the span during which a device sold into this performance is
  # unavailable to any other performance in the resource's venues.
  def occupancy_window_for(performance)
    curtain = performance.to_time_with_zone
    runtime = performance.production.running_time || default_runtime_minutes
    [curtain - changeover_minutes.minutes,
     curtain + (runtime + changeover_minutes).minutes]
  end

  # Devices left in the pool for this performance: quantity minus every device
  # already committed to an overlapping performance in the resource's venues.
  #
  # exclude_order (one order or an array) lets an order being edited ignore its
  # own current tickets so it is not blocked by itself -- and, during an
  # exchange, lets the replacement order ignore the source order it is
  # releasing (see ResourcedStockValidatable#pool_exempt_orders).
  def remaining_for(performance, exclude_order: nil)
    quantity - devices_taken_in_window(performance, Array(exclude_order))
  end

  # Decommission the shadow rows this resource no longer covers -- or all of
  # them, on delete. Historical rows are kept (line items reference them); they
  # simply stop being offered: auto_attach and web_visible go false and future
  # allocations are marked unavailable.
  #
  # Public entry point so SyncResourcedTicketClassJob, the before_destroy guard
  # and the admin UI all share one implementation.
  def self.decommission_shadow_classes(ticket_class_scope)
    ticket_class_scope.each do |tc|
      tc.synced_from_resource = true
      tc.update(auto_attach: false, web_visible: false)
      TicketClassAllocation.joins(:performance)
                           .where(ticket_class_id: tc.id)
                           .where(performances: { performance_date: Date.current.. })
                           .each { |tca| tca.update(available: false) }
    end
  end

  private

  def devices_taken_in_window(performance, exclude_orders)
    shadow_ids = ticket_classes.pluck(:id)
    return 0 if shadow_ids.empty?

    candidate_ids = overlapping_performance_ids(performance)
    return 0 if candidate_ids.empty?

    scope = TicketLineItem.joins(:order)
                          .where(ticket_class_id: shadow_ids)
                          .where(orders: { performance_id: candidate_ids,
                                           status: Order::RESOURCE_OCCUPYING_STATUSES })
    excluded_ids = exclude_orders.map { |order| order&.id }.compact
    scope = scope.where.not(orders: { id: excluded_ids }) if excluded_ids.any?
    # Refunds are negative ticket_count rows, so the SUM nets them out.
    scope.sum(:ticket_count)
  end

  # Ids of every performance in the resource's venues whose occupancy window
  # overlaps this performance's. The candidate set deliberately INCLUDES the
  # target performance itself -- its own other orders consume the same pool.
  def overlapping_performance_ids(performance)
    window_start, window_end = occupancy_window_for(performance)

    # Performance.unscoped: the model's default_scope eager-loads
    # ticket_class_allocations, which would drag a second query per row into
    # what should be one id lookup.
    Performance.unscoped
               .joins(:production)
               .where(productions: { venue_id: venue_ids })
               .where(performance_date: (performance.performance_date - 1)..(performance.performance_date + 1))
               .where(OVERLAP_SQL,
                      changeover: changeover_minutes,
                      runtime: default_runtime_minutes,
                      window_start: wall_clock(window_start),
                      window_end: wall_clock(window_end))
               .pluck(:id)
  end

  # performance_date/performance_time are naive wall-clock columns, so the
  # window bounds have to be compared as wall clock in the application zone.
  # NOTE: do NOT use TimeWithZone#to_s(:db) here -- it converts to UTC.
  def wall_clock(time)
    time.strftime('%Y-%m-%d %H:%M:%S')
  end

  def clean_values
    class_code.upcase! if class_code
    self.zone_id = zone_id.to_s.strip.upcase.presence || ZoneMatchable::WILDCARD
  end

  # Mirrors TicketClass#prevent_price_changes_after_sales, but the sales to
  # check for are spread across every shadow row this resource owns.
  def prevent_price_changes_after_sales
    return unless persisted?
    return if ticket_type == TicketClass::DONATION
    return if ticket_price_was == ticket_price
    return if TicketLineItem.where(ticket_class_id: ticket_classes.pluck(:id)).empty?

    errors.add(:base,
               "Cannot change ticket price from #{ticket_price_was} to #{ticket_price} if sales have already occurred")
  end

  def must_have_at_least_one_venue
    return if venues.any?

    errors.add(:venues, 'must include at least one venue')
  end

  def sync_shadow_classes_async
    Resque.enqueue(SyncResourcedTicketClassJob, id)
  end

  # Runs inside the destroy transaction, so it is atomic with the resource row.
  # #destroy has already established that no shadow row has sales; the guard is
  # repeated here in case a future caller reaches the callback chain directly.
  def destroy_unsold_shadow_classes
    shadows = ticket_classes.reload.to_a
    if shadows.any? { |tc| TicketLineItem.where(ticket_class_id: tc.id).any? }
      errors.add(:base, "Cannot delete '#{class_code}': this equipment has already been sold.")
      throw :abort
    end

    # No sales anywhere, so nothing to preserve: drop the shadow rows.
    #
    # These rows are deleted rather than destroyed on purpose.
    # TicketClass#destroy runs check_for_processed_tickets OUTSIDE a callback
    # chain, and that guard is inverted -- it throws :abort for a class with NO
    # line items, which surfaces as UncaughtThrowError. Fixing that guard is a
    # separate change with app-wide reach. We have already proven there are no
    # line items here, so we destroy the dependent allocations ourselves (the
    # only `dependent: :destroy` association) and delete the rows.
    shadow_ids = shadows.map(&:id)
    TicketClassAllocation.where(ticket_class_id: shadow_ids).destroy_all
    TicketClass.where(id: shadow_ids).delete_all
  end
end
