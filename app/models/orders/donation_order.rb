class DonationOrder < Order
  has_many :donation_line_items, :foreign_key=>:order_id

  accepts_nested_attributes_for :donation_line_items,
                                :allow_destroy => true

  validates_associated :donation_line_items

  def refundable?
    self.status == Order::PROCESSED || self.status == Order::FULFILLED
  end

  def display_code()
    "DONATION"
  end

  def to_s
    "Donation"
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
    valid_payment_types.delete FLEX_PASS
    valid_payment_types.delete MEMBERSHIP
    valid_payment_types
  end

  def sync_to_salesforce!(sf_user = nil, sf_donationtype = nil)
    if self.finalized?
      c = self.address.sf
      account = Salesforce::Account.find_by_npe01__One2OneContact__c(c.Id)

      donation = Salesforce::Opportunity.find_by_stagemgr_id__c(self.id)
      if donation.nil?
        donation = Salesforce::Opportunity.create("Probability"=>100.0, "StageName"=>"Posted",
                                                  "Name"=>"#{self.address.full_name} (Online)", "Amount"=>self.total,
                                                  "CloseDate"=>self.last_processed_on,
                                                  "AccountId"=>account.Id,
                                                  "npe01__Contact_Id_for_Role__c"=>account.Id,
                                                  "stagemgr_id__c"=>self.id,
                                                  "OwnerId"=>sf_user,
                                                  "RecordTypeId"=>sf_donationtype,
                                                  "IsPrivate"=>false)

      else
        donation.Amount = self.total
        donation.CloseDate = self.last_processed_on
        donation.AccountId = account.Id
        donation.npe01__Contact_Id_for_Role__c = account.Id
      end
      donation.save
      self.sf_last_sync_at = DateTime.now
      self.save!
    end
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

end
