class Pledge < ApplicationRecord
  include RecurringProfile

  belongs_to :donation_pledge_order, :foreign_key=>'order_id'

  def total
    self.aggregate_amount ||= 0.0
    self.outstanding_balance ||= 0.0
    (self.aggregate_amount + self.outstanding_balance)/100.0
  end

  def recurring_order
    return self.donation_pledge_order
  end

end
