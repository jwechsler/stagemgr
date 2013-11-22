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
      Rails.logger.debug("RESPONSE: #{response.to_yaml}")
      if success
        profile_id = response.params["profile_id"]
        self.pledge = Pledge.create(:profile_id => profile_id,
                                    :status =>response.params["profile_status"][0..-8],
                                    :address=>self.address)
        self.pledge.update_from_profile!
        self.donation_line_items.first.donation_amount = amount*12.0
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

# Salesforce module for extraction

class DonationPledgeOrder

  def self.syncable_statuses
    self.finalized_statuses
  end

  def queue_sf_sync(delay=nil)
    delay ||= 5.seconds
    Resque.enqueue_in(delay, SyncDonationToSalesforce, self.id)
    super(delay)
  end

  def sync_to_salesforce!(sf_user = nil, sf_donationtype = nil)
    if self.finalized?
      sf_user = $DATABASEDOTCOM['user_id'] if sf_user.nil?
      c = self.address.sf
      contact = SalesforceData::Contact.find(c.Id)

      donation = SalesforceData::Npe03__Recurring_Donation__c.find_by_stagemgr_id__c(self.id.to_s)
      if donation.nil?
        donation = SalesforceData::Npe03__Recurring_Donation__c.create(
                                                  "Name"=>"#{self.hold_under.blank? ? self.address.full_name : self.hold_under}",
                                                  "npe03__Amount__c"=>self.total,
                                                  'npe03__Date_Established__c'=>self.created_at.to_date,
                                                  "npe03__Installments__c"=>self.cycles,
                                                  "npe03__Contact__c"=>contact.Id,
                                                  'npe03__Installment_Period__c'=>'Monthly',
                                                  'npe03__Schedule_Type__c'=>'Divide By',
                                                  "stagemgr_id__c"=>self.id.to_s,
                                                  "OwnerId"=>sf_user)

      else
        donation.npe03__Amount__c = self.total
        donation.npe03__Contact__c = contact.Id
        donation.save
      end
      self.sf_last_sync_at = DateTime.now
      self.save!
    end
  end

end

