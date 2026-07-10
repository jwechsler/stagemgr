class MembershipOffer < ApplicationRecord
  include Taggable

  has_tags :membership_offer_tags

  OFFER_STATUSES = (ACTIVE, INACTIVE = 'Active', 'Inactive')

  # 'production' memberships are the classic single-member subscription, good
  # for tickets_per_performance seats per production. 'timed' offers are
  # library passes: shared between patrons, staff-issued with no Stripe
  # billing, never on public sale, and good for one performance per calendar
  # week (Monday-Sunday).
  MEMBERSHIP_TYPES = (PRODUCTION, TIMED = 'production', 'timed').freeze

  validates_presence_of :name, :use_ticket_class_code, :tickets_per_performance
  validates_presence_of :price_id, :if => :requires_price_id?
  validates_numericality_of :tickets_per_performance
  validates :membership_type, inclusion: { in: MEMBERSHIP_TYPES }
  before_save :take_inactive_off_sale, :unless => :active?
  before_save :take_timed_off_sale, :if => :timed?
  # Re-sync active members into the new MyEmma group when staff change it.
  # after_commit so the worker process reads the committed value.
  after_commit :enqueue_myemma_group_resync, on: :update,
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

  def on_sale_to_public?
    on_sale && !timed?
  end

  def enqueue_myemma_group_resync
    Resque.enqueue(SyncMembershipOfferMyEmmaGroupJob, id)
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
end
