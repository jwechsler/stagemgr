class DonationOrder < Order

  has_many :donation_line_items, :foreign_key=>:order_id

  accepts_nested_attributes_for :donation_line_items,
                                :allow_destroy => true

  validates_associated :donation_line_items

  # after_save :update_address_aggregates

  def refundable?
    self.status == Order::PROCESSED || self.status == Order::FULFILLED
  end

  def display_code()
    "DONATION"
  end

  def to_s
    "Donation (#{self.campaign})"
  end

  def total
    self.donation_line_items.sum(:donation_amount)
  end


  def description
    self.to_s
  end

  def all_line_items(reload_line_items = false)
    super(reload_line_items) +
        self.donation_line_items(reload_line_items)
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types.select {|pt| pt.is_a? CurrencyPaymentType }
  end

  def reload_associated
    super
    self.donation_line_items(true)
  end

  protected

  def set_defaults
    super
    self.donation_line_items.each { |di| di.order=self }
  end

  def create_receipt_task
    super
    self.tasks << OutreachTask.new(:execute_at=>Time.now + 5.minutes, :method_symbol=>:donation_thank_you)
  end

  def update_address_aggregates
    self.address.update_donor_levels!
  end


end

class DonationOrder

  def self.syncable_statuses
    self.finalized_statuses
  end

  def queue_sf_sync(delay=nil)
    delay ||= 2.minutes
    Resque.enqueue_in(delay, SyncDonationToSalesforce, self.id)
    Resque.enqueue_in(delay + 2.day, SyncAddressToSalesforce, self.address_id)
    super(delay)
  end

  def sync_to_salesforce!(sf_user = nil, sf_donationtype = nil)
    if self.finalized?
      sf_user = $DATABASEDOTCOM['user_id'] if sf_user.nil?
      sf_donationtype = $DATABASEDOTCOM['donation_record_type_id'] if sf_donationtype.nil?
      c = self.address.sf

      donation = SalesforceData::Opportunity.find_by_stagemgr_id__c(self.id.to_s)
      if donation.nil?
        donation = SalesforceData::Opportunity.create("Probability"=>100.0, "StageName"=>"Posted",
                                                  "Name"=>"#{self.address.full_name} (Online)", "Amount"=>self.total,
                                                  "CloseDate"=>self.last_processed_on,
                                                  "AccountId"=>c.AccountId,
                                                  "npe01__Contact_Id_for_Role__c"=>c.Id,
                                                  "stagemgr_id__c"=>self.id.to_s,
                                                  "OwnerId"=>sf_user,
                                                  "RecordTypeId"=>sf_donationtype,
                                                  "IsPrivate"=>false)

      else
        donation.Amount = self.total
        donation.CloseDate = self.last_processed_on
        donation.AccountId = self.address.sf.AccountId
        donation.npe01__Contact_Id_for_Role__c = self.address.sf.Id
	      donation.save
      end
      self.sf_last_sync_at = DateTime.now
      self.save!
    end
  end

end

