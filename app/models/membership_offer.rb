class MembershipOffer < ApplicationRecord
  include Taggable
  include MembershipCardArtwork

  has_tags :membership_offer_tags

  OFFER_STATUSES = (ACTIVE, INACTIVE = 'Active', 'Inactive')

  scope :status_active,   -> { where(status: ACTIVE) }
  scope :status_inactive, -> { where(status: INACTIVE) }

  # Offers a member of the public may actually buy right now: the query form of
  # #on_sale_to_public?, condition for condition. Used by the public index and
  # by the calendar's membership call-to-action, where listing anything else
  # would print a buy button that lands on "not available" --
  # MembershipOfferOrdersController#new renders general/unavailable for an offer
  # that is off sale or timed.
  scope :on_sale_to_public, -> { status_active.where(on_sale: true, membership_type: PRODUCTION) }

  # 'production' memberships are the classic single-member subscription, good
  # for tickets_per_performance seats per production. 'timed' offers are
  # library passes: shared between patrons, staff-issued with no Stripe
  # billing, never on public sale, and good for one performance per calendar
  # week (Monday-Sunday).
  MEMBERSHIP_TYPES = (PRODUCTION, TIMED = 'production', 'timed').freeze

  # Billing period of the offer's Stripe Price, cached by
  # SyncMembershipOfferBillingPeriodJob. NULL billing_interval: not synced.
  BILLING_INTERVALS = (DAY, WEEK, MONTH, YEAR, ONE_TIME = 'day', 'week', 'month', 'year', 'one_time').freeze
  # A one-time price runs for the offer's gift length (max_cycles_if_gift)
  # or, failing that, a year.
  DEFAULT_ONE_TIME_MONTHS = 12
  BILLING_PERIOD_FIELDS = %i[billing_interval billing_interval_count billing_period_synced_at].freeze

  validates_presence_of :name, :use_ticket_class_code, :tickets_per_performance
  validates_presence_of :price_id, :if => :requires_price_id?
  validates_numericality_of :tickets_per_performance
  validates :membership_type, inclusion: { in: MEMBERSHIP_TYPES }
  before_save :take_inactive_off_sale, :unless => :active?
  before_save :take_timed_off_sale, :if => :timed?
  # A cached billing period never outlives the price it was read from.
  before_save :clear_billing_period, if: :will_save_change_to_price_id?
  # after_commit so the worker process reads the committed price_id.
  after_commit :enqueue_billing_period_sync,
               on: %i[create update],
               if: -> { saved_change_to_price_id? && price_id.present? }
  # Re-sync active members into the new MyEmma group when staff change it.
  # after_commit so the worker process reads the committed value.
  after_commit :enqueue_myemma_group_resync,
               on: :update,
               if: -> { saved_change_to_myemma_group? && myemma_group.present? && !MyEmma.disabled? }
  def has_trial?
    !trial_period.nil? && trial_period > 0
  end

  def trial_amount
    has_trial? ? trial_price : nil
  end

  def active?
    status == ACTIVE
  end

  def timed?
    membership_type == TIMED
  end

  def requires_price_id?
    active? && !timed?
  end

  def take_inactive_off_sale
    self.on_sale = false
    true
  end

  def take_timed_off_sale
    self.on_sale = false
    true
  end

  def clear_billing_period
    BILLING_PERIOD_FIELDS.each { |field| self[field] = nil }
  end

  # Kept condition-for-condition with the on_sale_to_public scope. `active?` is
  # implied today -- before_save takes an inactive offer off sale -- but saying
  # it here keeps the record form and the query form answering alike for a row
  # whose status was changed by anything that skips callbacks.
  def on_sale_to_public?
    active? && on_sale && !timed?
  end

  def enqueue_myemma_group_resync
    Resque.enqueue(SyncMembershipOfferMyEmmaGroupJob, id)
  end

  def enqueue_billing_period_sync
    Resque.enqueue(SyncMembershipOfferBillingPeriodJob, id)
  end

  def billing_period_synced?
    billing_interval.present?
  end

  def one_time_payment?
    billing_interval == ONE_TIME
  end

  # Months one payment pays for, which turns a payment into a monthly rate:
  # 1 when not synced (assumed monthly), nil for a one-time price (the
  # caller measures the membership). Weeks and days use the average month.
  def billing_months
    return 1 unless billing_period_synced?
    return nil if one_time_payment?

    count = billing_interval_count || 1
    case billing_interval
    when YEAR then count * 12
    when WEEK then count * 7 / MembershipMetrics::AVERAGE_DAYS_PER_MONTH
    when DAY then count / MembershipMetrics::AVERAGE_DAYS_PER_MONTH
    else count
    end
  end

  # The billing period a payment made on +paid_on+ pays for, as [start, end)
  # dates, or nil for a one-time price (the caller spreads it across the
  # membership). Not synced means assumed monthly.
  #
  # Months and years follow Stripe's calendar billing: the period runs from
  # the subscription's billing day (+anchor_day+, clamped to the month's last
  # day, so the 30th bills on February 28 and returns to the 30th) on or
  # before the payment, to the same day one period later. A late payment (a
  # retried charge) still pays for its anchored period. Weeks and days are
  # fixed lengths from the payment date.
  def billing_period_for(paid_on, anchor_day:)
    return nil if billing_period_synced? && one_time_payment?

    count = billing_interval_count || 1
    case billing_period_synced? ? billing_interval : MONTH
    when DAY then [paid_on, paid_on + count]
    when WEEK then [paid_on, paid_on + (7 * count)]
    when YEAR then calendar_billing_period(paid_on, 12 * count, anchor_day)
    else calendar_billing_period(paid_on, count, anchor_day)
    end
  end

  # "Every 1 month (from Stripe)", "One-time payment (from Stripe)", or the
  # monthly assumption when the period has not been synced.
  def billing_period_label
    return 'Monthly (assumed; not synced from Stripe)' unless billing_period_synced?
    return 'One-time payment (from Stripe)' if one_time_payment?

    count = billing_interval_count || 1
    "Every #{count} #{billing_interval.pluralize(count)} (from Stripe)"
  end

  # [earliest, latest] activity dates for this offer, used to run the usage
  # report over the offer's entire history: payment processed_on bounds
  # widened by membership active windows, so offers whose memberships have
  # never billed (staff-issued library passes) still produce a usable range.
  # Returns [nil, nil] when the offer has neither payments nor memberships.
  def usage_date_range
    first_payment, last_payment = MembershipOrder.joins(membership_line_item: :membership_offer)
                                                 .joins(:payments)
                                                 .where(membership_offers: { id: id })
                                                 .pick(Arel.sql('MIN(payments.processed_on)'),
                                                       Arel.sql('MAX(payments.processed_on)')) || [nil, nil]
    window_start = Membership.where(membership_offer_id: id)
                             .where.not(status: Membership::PENDING)
                             .minimum(Arel.sql('COALESCE(memberships.start_date, memberships.member_since)'))
    return [first_payment, last_payment] if window_start.nil?

    [[first_payment&.to_date, window_start.to_date].compact.min,
     [last_payment&.to_date, Date.current].compact.max]
  end

  private

  def calendar_billing_period(paid_on, months, anchor_day)
    start = billing_day_in(paid_on, anchor_day)
    start = billing_day_in(paid_on << 1, anchor_day) if start > paid_on
    finish = billing_day_in(start >> months, anchor_day)
    [start, finish]
  end

  def billing_day_in(date, anchor_day)
    Date.new(date.year, date.month, [anchor_day, date.end_of_month.day].min)
  end
end
