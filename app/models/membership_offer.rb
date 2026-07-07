class MembershipOffer < ApplicationRecord
  include Taggable

  has_tags :membership_offer_tags

  validates_presence_of :name, :use_ticket_class_code, :tickets_per_performance
  validates_presence_of :price_id, :if => :active?
  validates_numericality_of :tickets_per_performance
  before_save :take_inactive_off_sale, :unless => :active?

  OFFER_STATUSES = (ACTIVE, INACTIVE = 'Active', 'Inactive')
  def has_trial?
    !trial_period.nil? && trial_period > 0
  end

  def trial_amount
    has_trial? ? trial_price : nil
  end

  def active?
    status == ACTIVE
  end

  def take_inactive_off_sale
    self.on_sale = false
    true
  end

  def on_sale_to_public?
    on_sale
  end

  # [earliest, latest] processed_on across this offer's membership order
  # payments, used to run the usage report over the offer's entire history.
  # Returns [nil, nil] when the offer has no payments yet.
  def usage_date_range
    MembershipOrder.joins(membership_line_item: :membership_offer)
                   .joins(:payments)
                   .where(membership_offers: { id: id })
                   .pick(Arel.sql('MIN(payments.processed_on)'), Arel.sql('MAX(payments.processed_on)')) || [nil, nil]
  end
end
