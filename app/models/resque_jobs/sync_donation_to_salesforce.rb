class SyncDonationToSalesforce
  extend Resque::Plugins::Retry
  @queue = :sync
  @retry_limit = 24
  @retry_delay = 3600

  def self.perform(order_id)
    begin
      syncable = DonationOrder.find(order_id)
      syncable.sf_disable_sync_on_commit = true
      syncable.sync_to_salesforce!($DATABASEDOTCOM['user_id'], $DATABASEDOTCOM['donation_record_type_id'])
    rescue ActiveRecord::RecordNotFound
    end
  end

end
