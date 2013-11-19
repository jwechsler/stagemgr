module RecurringOrder

  extend ActiveSupport::Concern
  included do
    has_many :recurring_payments, :foreign_key=>:order_id
    accepts_nested_attributes_for :recurring_payments
  end

  def suspend!
    raise "Recurringorder.suspend not yet implemented!"
  end

  def cancel!
    raise "RecurringOrder.cancel not yet implemeneted"
  end

  def recurring_profile
    raise "recurring_profile not yet implmeneted"
  end

  def create_recurring_payment(note = nil, additional_info = {})
    payment = RecurringPayment.new
    payment.amount = additional_info[:amount] || self.membership.membership_offer.recurring_cost
    payment.note = note || "Automatically created"
    payment.transaction_id = additional_info[:transaction_id] || self.recurring_profile.profile_id
    payment.ipn_track_id = additional_info[:ipn_track_id]
    payment.processed_on = additional_info[:processed_on]
    payment.payment_fee = additional_info[:payment_fee]
    self.payments << payment
    payment
  end

end
