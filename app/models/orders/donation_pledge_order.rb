class DonationPledgeOrder < DonationOrder

  include RecurringOrder

  validate

  has_one :pledge, :foreign_key=>'order_id', :dependent => :destroy

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types.select {|pt| pt.is_a? CreditCardPaymentType }
  end

  def display_code()
    "PLEDGE"
  end

  def to_s
    "Pledge (#{self.campaign})"
  end

  def description
    self.to_s
  end

  def create_proper_payment_in_amount_of!(amount, payment_options = {})
    amount = amount.round(2)
    if amount < 7.00
      raise "Your monthly pledge must be $7.00 or over."
    else
      response = RecurringProfile.create_recurring_profile(
                                self,Date.today,amount.round(2),
                                'Theater Wit Monthly Pledge',2,{:total_billing_cycles=>self.cycles.to_i}
                    )
      success = response.success?
      if success
        profile_id = response.params["profile_id"]
        self.pledge = Pledge.create(:profile_id => profile_id,
                                    :status =>response.params["profile_status"][0..-8],
                                    :address=>self.address)
        self.pledge.update_from_profile!
        self.donation_line_items.first.amount = amount*12.0
      else
        self.pledge=nil?
      end
    end
  end

  def is_balanced_transaction?
    if self.pledge.nil?
      errors.add :status, "cannot be set to #{PROCESSED} without a valid recurring payment profile."
    end
  end

  def recurring_profile
    self.pledge
  end

  def cycles
    12
  end

end
