require 'exceptions.rb'

class MembershipOffer < ActiveRecord::Base
  attr_accessible :name, :recurring_cost, :email_html, :html_description, :use_ticket_class_code,
                  :use_member_friend_code, :tickets_per_performance,
                  :billing_agreement, :myemma_group, :on_sale, :trial_period, :trial_price, :restricted_to_first_time
  validates_presence_of :name,:use_ticket_class_code,:recurring_cost,:tickets_per_performance
  validates_numericality_of :tickets_per_performance, :recurring_cost
  validates_numericality_of :trial_price, :if=>:has_trial?

  def has_trial?
    !self.trial_period.nil? && self.trial_period > 0
  end

  def trial_amount
    self.has_trial? ? self.trial_price : nil
  end

end
