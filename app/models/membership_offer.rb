class MembershipOffer < ApplicationRecord

  validates_presence_of :name,:use_ticket_class_code,:tickets_per_performance
  validates_presence_of :price_id, :if=>:active?
  validates_numericality_of :tickets_per_performance
  before_save :take_inactive_off_sale, :unless=>:active?
  
  OFFER_STATUSES = (ACTIVE, INACTIVE = 'Active',  'Inactive')
  def has_trial?
    !self.trial_period.nil? && self.trial_period > 0
  end

  def trial_amount
    self.has_trial? ? self.trial_price : nil
  end

  def active?
    self.status == ACTIVE
  end

  def take_inactive_off_sale
    self.on_sale = false
    true
  end

  def on_sale_to_public?
    self.on_sale
  end

end
