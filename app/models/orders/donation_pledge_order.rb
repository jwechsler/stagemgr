class DonationPledgeOrder < DonationOrder

  include RecurringOrder

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
    Rails.logger.debug("AMT: #{amount}")
    response = RecurringProfile.create_recurring_profile(
                              self,Date.today,(amount/12.0).round(2),
                              'Theater Wit Monthly Pledge',2,{:cycles=>12}
                  )
    success = response.success?
    Rails.logger.debug("RESPONSE: #{response.to_yaml}")
    if success
      profile_id = response.params["profile_id"]
      self.pledge = Pledge.create(:profile_id => profile_id,
                                  :status =>response.params["profile_status"][0..-8],
                                  :address=>self.address)
      self.pledge.update_from_profile!
      self.donation_line_items.first.donation_amount = pledge.total # handle rounding problems
    else
      self.pledge=nil?
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

end

class DonationPledgeOrder

  def sync_to_salesforce!(sf_user = nil, sf_donationtype = nil)
    if self.finalized?
      sf_user = $DATABASEDOTCOM['user_id'] if sf_user.nil?
      sf_donationtype = $DATABASEDOTCOM['donation_record_type_id'] if sf_donationtype.nil?
      c = self.address.sf
      account = SalesforceData::Account.find_by_npe01__One2OneContact__c(c.Id)

      donation = SalesforceData::Opportunity.find_by_stagemgr_id__c(self.id.to_s)
      if donation.nil?
        donation = SalesforceData::Opportunity.create("Probability"=>100.0, "StageName"=>"Posted",
                                                  "Name"=>"#{self.address.full_name} (Online)", "Amount"=>self.total,
                                                  "CloseDate"=>self.last_processed_on,
                                                  "AccountId"=>account.Id,
                                                  "npe01__Contact_Id_for_Role__c"=>account.Id,
                                                  "stagemgr_id__c"=>self.id.to_s,
                                                  "OwnerId"=>sf_user,
                                                  "RecordTypeId"=>sf_donationtype,
                                                  "IsPrivate"=>false)

      else
        donation.Amount = self.total
        donation.CloseDate = self.last_processed_on
        donation.AccountId = account.Id
        donation.npe01__Contact_Id_for_Role__c = account.Id
        donation.save
      end
      self.sf_last_sync_at = DateTime.now
      self.save!
    end
  end

end
